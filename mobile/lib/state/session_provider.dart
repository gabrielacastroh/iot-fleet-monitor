import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/failure.dart';
import '../core/security/jwt_claims.dart';
import '../domain/models/app_user.dart';
import '../domain/models/session.dart';
import 'api_providers.dart';
import 'cache_providers.dart';
import 'push_provider.dart';
import 'realtime_provider.dart';
import 'repository_providers.dart';

/// Bootstraps from secure storage on cold start (AUTH-7), enforces the
/// proactive expiry check before any authenticated request fires (AUTH-8),
/// and tears down on a reactive 401 reported by [TokenStore] (AUTH-9).
class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final tokenStore = ref.watch(tokenStoreProvider);
    final subscription = tokenStore.unauthorized.listen((_) => forceLogout());
    ref.onDispose(subscription.cancel);

    final secureStore = ref.watch(secureStoreProvider);
    final token = await secureStore.readToken();
    if (token == null) return null;

    final claims = JwtClaims.parse(token);
    if (claims == null || claims.isExpired) {
      await secureStore.deleteToken();
      return null;
    }

    tokenStore.setToken(token);
    final fleetCache = await ref.read(fleetCacheProvider.future);
    if (fleetCache == null) return null;

    final repository = ref.read(sessionRepositoryProvider);
    Session session;
    try {
      final user = await repository.fetchAndCacheCurrentUser(fleetCache);
      session = Session(token: token, user: user, claims: claims);
    } on Failure {
      final cachedUser = repository.cachedUser(fleetCache);
      if (cachedUser == null) {
        await secureStore.deleteToken();
        return null;
      }
      session = Session(token: token, user: cachedUser, claims: claims);
    }

    // AUTH-7's cold-start restore reaches an authenticated session just as
    // much as an interactive login does — without this, reopening the app
    // with an already-stored token (the common case, not the rare one)
    // never re-initializes AlertNotifier, and every alert notification
    // silently no-ops on `_initialized == false`. Deferred a real event-loop
    // turn (not just `unawaited`) for the same reason `LatestTelemetryNotifier`
    // defers its own refresh this way (see `telemetry_provider.dart`): this
    // still runs inside `build()`, and starting async provider work
    // synchronously here can reenter another provider still under
    // construction (Riverpod's build-reentrancy guard).
    //
    // Scoped to this build via `disposed` (mirroring `_Debouncer`'s
    // `ref.onDispose` pattern in realtime_provider.dart): the deferred
    // closure is a bare `Timer`, not a Riverpod operation, so nothing
    // cancels it on its own — without this guard it fires after the
    // container is gone (a fast logout, or the next test's teardown) and
    // reads from a disposed `ref`.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    unawaited(
      Future(() {
        if (disposed) return null;
        return enableAlertNotifications(ref);
      }),
    );
    return session;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue<Session?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repository = ref.read(sessionRepositoryProvider);
      final token = await repository.login(email: email, password: password);

      final secureStore = ref.read(secureStoreProvider);
      await secureStore.writeToken(token);
      ref.read(tokenStoreProvider).setToken(token);
      ref.invalidate(fleetCacheProvider);

      final fleetCache = await ref.read(fleetCacheProvider.future);
      final user = await repository.fetchAndCacheCurrentUser(fleetCache!);
      final claims = JwtClaims.parse(token)!;
      return Session(token: token, user: user, claims: claims);
    });

    // After the session exists, so the permission prompt has context — and
    // unawaited, because a user deliberating over the system dialog must not
    // hold up the redirect to the dashboard.
    if (state.hasValue && state.value != null) {
      unawaited(enableAlertNotifications(ref));
    }
  }

  /// AUTH-9 / AUTH-10 / AUTH-8 all end here: close the socket, purge the
  /// user's cache box, clear secure storage, clear the in-memory token, and
  /// drop the session — the router's `refreshListenable` reacts to the
  /// resulting state change and redirects to `/login`. The order below is
  /// load-bearing (design §10) and MUST NOT be reordered:
  ///
  /// 1. Socket close — WS-3: synchronous, first, before any other teardown
  ///    step. It's `keepAlive`, so nothing else would ever close it, and an
  ///    in-flight event must not be able to rehydrate a provider after the
  ///    purge below.
  /// 2. Hive box purge — while the box is still open (it was opened with
  ///    the key currently in secure storage).
  /// 3. `secureStore.deleteAll()` — clears the token AND the Hive
  ///    encryption key (not just the token), so a subsequent login always
  ///    generates a fresh AES key rather than silently reusing the
  ///    previous account's.
  /// 4. In-memory token store cleared.
  /// 5. Providers invalidated, session set to `null`.
  ///
  /// `telemetrySocketProvider` is only invalidated at the very end, once
  /// the session is already `null` — invalidating it earlier (while a
  /// listener like `AppShell` may still be watching) would rebuild a fresh
  /// `TelemetrySocket` immediately, and it would read this same
  /// (still-valid) token and reconnect right after being told to close.
  ///
  /// AUTH-9: `TokenStore.unauthorized` is a broadcast stream, so two
  /// in-flight 401s can call this concurrently. Without the guard below, a
  /// second call would race the first through this same scrub sequence —
  /// concretely, two concurrent `Box.deleteFromDisk()` calls on the same
  /// Hive box throw `FileSystemException: File closed` (verified by a
  /// failing test before this guard existed). `_teardown` makes every
  /// concurrent caller await the *same* single execution instead, and
  /// resets once it completes so a later, genuine logout still runs.
  Future<void>? _teardown;

  Future<void> forceLogout() {
    return _teardown ??= _forceLogoutOnce().whenComplete(() {
      _teardown = null;
    });
  }

  Future<void> _forceLogoutOnce() async {
    ref.read(telemetrySocketProvider).close();

    final fleetCache = await ref.read(fleetCacheProvider.future);
    await fleetCache?.deleteFromDisk();

    final secureStore = ref.read(secureStoreProvider);
    await secureStore.deleteAll();

    ref.read(tokenStoreProvider).setToken(null);
    ref.invalidate(fleetCacheProvider);
    state = const AsyncData<Session?>(null);

    // Drops the now-closed instance so a subsequent login gets a genuinely
    // fresh `TelemetrySocket` (design §6.1: "Disposal is explicit... on
    // logout and on token change") instead of a permanently-dead one.
    ref.invalidate(telemetrySocketProvider);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
);

/// ROLE-1: derived exclusively from `role == "admin"` on the session's
/// user, refreshed only on login/restore — never polled.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(
    sessionProvider.select((s) => s.valueOrNull?.user.role == UserRole.admin),
  );
});
