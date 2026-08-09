import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/realtime/telemetry_socket.dart';
import '../data/realtime/ws_event.dart';
import '../domain/models/telemetry_reading.dart';
import 'alerts_provider.dart';
import 'config_providers.dart';
import 'devices_provider.dart';
import 'push_provider.dart';
import 'repository_providers.dart';
import 'session_provider.dart';
import 'telemetry_provider.dart';

/// [TelemetrySocket]'s real connection lifecycle (WS liveness) — a second,
/// distinct signal from `connectivityProvider` (device network
/// reachability); see `diagnostics_card.dart`'s two rows.
///
/// Seeded to `closed` (the socket's own pre-connect default) rather than
/// read from [telemetrySocketProvider]: `onConnectionStateChanged` fires
/// synchronously from inside [telemetrySocketProvider]'s own `build` (via
/// its `socket.connect()` call below), so reading that provider here to
/// seed would be a circular build. The callback converges this to the real
/// state immediately after anyway.
class WsConnectionStateNotifier extends Notifier<WsConnectionState> {
  @override
  WsConnectionState build() => WsConnectionState.closed;

  void update(WsConnectionState next) => state = next;
}

final wsConnectionStateProvider =
    NotifierProvider<WsConnectionStateNotifier, WsConnectionState>(
      WsConnectionStateNotifier.new,
    );

/// WS-1's mechanism: a single, non-`autoDispose` `TelemetrySocket` connects
/// synchronously at creation with whatever session token exists right now
/// (design §6.1 — safe because `AppShell` only ever mounts once
/// `sessionProvider` is authenticated, per the router guard). Every screen
/// that watches [wsEventsProvider] shares this same instance because
/// Riverpod only ever constructs a `Provider` once — that is the entire
/// single-connection guarantee (WS-1), not a convention.
final telemetrySocketProvider = Provider<TelemetrySocket>((ref) {
  final config = ref.watch(appConfigProvider);
  final socket = TelemetrySocket(
    wsBaseUrl: config.wsBaseUrl,
    // WS-9: the server rejected the credential (close code 1008) — same
    // teardown as a reactive 401 (AUTH-9).
    onSessionInvalid: () => ref.read(sessionProvider.notifier).forceLogout(),
    // WS-5: the server has no replay buffer, so a reconnect (not the first
    // connect) must fill the gap by refetching. Alerts only for an admin
    // session — `alertsProvider` must never be constructed otherwise
    // (ROLE-2, see `alerts_provider.dart`).
    onReconnected: () {
      ref.invalidate(devicesProvider);
      ref.invalidate(latestTelemetryProvider);
      ref.invalidate(liveFeedProvider);
      if (ref.read(isAdminProvider)) {
        ref.invalidate(alertsProvider);
      }
    },
    onConnectionStateChanged: (s) =>
        ref.read(wsConnectionStateProvider.notifier).update(s),
  );
  ref.onDispose(socket.close);

  final token = ref.read(sessionProvider).valueOrNull?.token;
  if (token != null) socket.connect(token);
  return socket;
});

/// The single fan-out every provider/screen listens to (WS-1). Not
/// `.autoDispose` — an autoDispose stream would tear the socket down on
/// every last-listener-unmounts tab switch and reopen on return, which is
/// the duplicate-connection bug wearing a different hat (design §6.1
/// reinforcement #1).
final wsEventsProvider = StreamProvider<WsEvent>((ref) {
  return ref.watch(telemetrySocketProvider).events;
});

/// WS-6's rolling live feed: seeded once from `GET /telemetry` (the same
/// fleet-wide, cross-device window the web dashboard's charts read), then
/// patched in place by every `telemetry_updated` event — mirrors
/// [LatestTelemetryNotifier]'s seed-then-patch shape. Newest first, capped
/// at 200.
class LiveFeedNotifier extends AsyncNotifier<List<TelemetryReading>> {
  static const _cap = 200;

  @override
  Future<List<TelemetryReading>> build() async {
    final repository = await ref.watch(telemetryRepositoryProvider.future);
    return repository.fetchRecent(limit: _cap);
  }

  void push(TelemetryReading reading) {
    final current = state.valueOrNull ?? const <TelemetryReading>[];
    state = AsyncData(
      [reading, ...current].take(_cap).toList(growable: false),
    );
  }
}

final liveFeedProvider =
    AsyncNotifierProvider<LiveFeedNotifier, List<TelemetryReading>>(
      LiveFeedNotifier.new,
    );

/// A trailing debounce so a burst of `alert_created`/`alert_resolved`
/// events (e.g. a simulator run) produces one `alertsProvider` refetch, not
/// twenty (design §6.1 risk #4 — 500ms is a tuned guess, easy to retune —
/// it's the one constant below). Held behind its own keepAlive provider so
/// the pending timer survives across dispatched events and is cancelled
/// when the container (i.e. the authenticated session) tears down.
class _Debouncer {
  Timer? _timer;

  void run(Duration delay, void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

final _alertsDebouncerProvider = Provider<_Debouncer>((ref) {
  final debouncer = _Debouncer();
  ref.onDispose(debouncer.dispose);
  return debouncer;
});

const _alertsInvalidationDebounce = Duration(milliseconds: 500);

/// design §6.1's event policy — the one place a [WsEvent] becomes a state
/// change. `telemetry_updated` patches in place; `alert_created`/
/// `alert_resolved` only ever invalidate (never patch — WS-8's payload is
/// genuinely too partial to reconstruct a record from).
void _handleWsEvent(Ref ref, WsEvent event) {
  switch (event) {
    case TelemetryUpdatedWsEvent(:final reading):
      ref.read(latestTelemetryProvider.notifier).upsert(reading);
      ref.read(liveFeedProvider.notifier).push(reading);
    case AlertCreatedWsEvent(:final id, :final message):
      if (!ref.read(isAdminProvider)) return;
      // A raised alert is the one event worth interrupting for, so it also
      // posts a system notification. Fire-and-forget: the notification is a
      // side effect of the event, never a precondition for the state update
      // below, and `AlertNotifier` swallows its own failures.
      unawaited(
        ref.read(alertNotifierProvider).showAlert(alertId: id, message: message),
      );
      _invalidateAlerts(ref);
    case AlertResolvedWsEvent():
      if (!ref.read(isAdminProvider)) return;
      _invalidateAlerts(ref);
  }
}

/// Coalesces a burst of alert events into one refetch (design §6.1).
void _invalidateAlerts(Ref ref) {
  ref
      .read(_alertsDebouncerProvider)
      .run(_alertsInvalidationDebounce, () => ref.invalidate(alertsProvider));
}

/// Subscribes once to [wsEventsProvider] and routes every event through
/// [_handleWsEvent]. `AppShell.build()` watches this provider — that watch
/// is what creates `wsEventsProvider` (and therefore the socket) in the
/// first place, matching design §6.1's "that listen is what creates the
/// provider" narrative.
final wsEventRouterProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<WsEvent>>(wsEventsProvider, (previous, next) {
    next.whenData((event) => _handleWsEvent(ref, event));
  });
});
