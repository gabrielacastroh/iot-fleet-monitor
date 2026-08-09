import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/fleet_alert.dart';
import 'api_providers.dart';
import 'cached.dart';
import 'repository_providers.dart';
import 'session_provider.dart';

/// Peek-then-refetch over `GET /alerts?is_resolved=false` (design §6),
/// mirroring [DevicesNotifier]. **Never watch this provider for a
/// non-admin session** — that is the entire ROLE-2 enforcement mechanism:
/// `alertRepositoryProvider` requires an admin-only endpoint, so a
/// non-admin caller must gate on `isAdminProvider` *before* touching this
/// provider, not rely on it to self-gate. [resolve] extends this notifier
/// with an optimistic-update-with-rollback method (ALT-3/ALT-4).
class AlertsNotifier extends AsyncNotifier<Cached<List<FleetAlert>>>
    with CacheBackedNotifier<List<FleetAlert>> {
  CachedSource<List<FleetAlert>>? _repository;

  @override
  CachedSource<List<FleetAlert>> get source => _repository!;

  @override
  Future<Cached<List<FleetAlert>>> build() async {
    _repository = await ref.watch(alertRepositoryProvider.future);
    return super.build();
  }

  /// ALT-3: removes [alertId] from the open-alerts list immediately, then
  /// fires the PATCH. ALT-4: on failure, the removal is reverted and the
  /// error rethrown so the caller (the alerts screen) can surface the
  /// retry copy. The PATCH always fires regardless of whether [alertId] is
  /// currently present in this list — a caller resolving from a
  /// "Resueltas"/"Todas" tab (an uncached, separate provider) still needs
  /// the write to happen; only the optimistic UI update is conditional on
  /// the alert being part of *this* cached open feed.
  Future<void> resolve(String alertId) async {
    final current = state.valueOrNull;
    final previousAlerts = current?.value;
    final isInOpenList = previousAlerts?.any((a) => a.id == alertId) ?? false;
    if (isInOpenList) {
      state = AsyncData(
        Cached(
          previousAlerts!.where((a) => a.id != alertId).toList(),
          cachedAt: current!.cachedAt,
        ),
      );
    }

    final repository = await ref.read(alertRepositoryProvider.future);
    try {
      await repository.resolve(alertId);
    } catch (_) {
      if (isInOpenList) {
        state = AsyncData(Cached(previousAlerts!, cachedAt: current!.cachedAt));
      }
      rethrow;
    }
  }
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, Cached<List<FleetAlert>>>(
      AlertsNotifier.new,
    );

/// VDET-4: `GET /alerts/{device_id}` — an uncached, online-only passthrough
/// (same reasoning as [telemetryHistoryProvider]: a device-scoped triage
/// view, not a data source anything else composes). Only ever watched
/// from the `isAdmin` branch of `AlertsTab` — never construct/watch this
/// for a non-admin session (ROLE-2, same discipline as [alertsProvider]).
final deviceAlertsProvider = FutureProvider.autoDispose
    .family<List<FleetAlert>, String>((ref, deviceId) {
      final api = ref.watch(alertsApiProvider);
      return api.getForDevice(deviceId);
    });

/// The bounded `limit` every `/alerts` request sends (ALT-1), matching
/// [AlertRepository]'s open-alerts feed.
const alertsListLimit = 200;

/// ALT-1's "Resueltas"/"Todas" tabs: an uncached, online-only passthrough
/// keyed by the `is_resolved` value the tab maps to (`null` = "Todas") —
/// same reasoning as [deviceAlertsProvider]. Only the `is_resolved=false`
/// feed is cached (design §5.3); every other filter is a screen nobody
/// needs offline.
final alertsByFilterProvider = FutureProvider.autoDispose
    .family<List<FleetAlert>, bool?>((ref, isResolved) {
      final api = ref.watch(alertsApiProvider);
      return api.getAll(isResolved: isResolved, limit: alertsListLimit);
    });

/// ALT-2's cold-deep-link fallback chain (design §7) for the alert detail
/// screen, keyed by a value-equal record (native Dart 3 equality — no
/// hand-rolled `==`/`hashCode` class needed, unlike [HistoryQuery], which
/// predates records in this codebase). Resolution order: (1) the alert is
/// already in [alertsProvider]'s cached open feed; (2) [deviceId] is
/// present -> the device-scoped route; (3) neither/not found -> the
/// bounded full list; `null` if still not found after all three.
final alertByIdProvider = FutureProvider.autoDispose
    .family<FleetAlert?, ({String alertId, String? deviceId})>((
      ref,
      lookup,
    ) async {
      final cached = (await ref.watch(alertsProvider.future)).value;
      for (final candidate in cached) {
        if (candidate.id == lookup.alertId) return candidate;
      }

      if (lookup.deviceId != null) {
        final deviceAlerts = await ref.watch(
          deviceAlertsProvider(lookup.deviceId!).future,
        );
        for (final candidate in deviceAlerts) {
          if (candidate.id == lookup.alertId) return candidate;
        }
      }

      final api = ref.watch(alertsApiProvider);
      // Design §7's last-resort step: the API's own max `limit` (backend
      // caps at 1000) — this is a genuine cold-link recovery path, not the
      // regular list request, so it doesn't share `alertsListLimit`.
      final all = await api.getAll(limit: 1000);
      for (final candidate in all) {
        if (candidate.id == lookup.alertId) return candidate;
      }
      return null;
    });

/// How many open alerts the shell's Alertas tab should badge, and the ONE
/// place allowed to read [alertsProvider] without an `isAdmin` branch around
/// the call site — the branch is inside, so the badge is safe to watch from
/// anywhere.
///
/// `0` for a non-admin session, and `alertsProvider` is never constructed in
/// that case, so `GET /alerts` still never fires for them (ROLE-2). It is
/// also `0` while the first fetch is in flight: a badge that appears a beat
/// later is better than one that flashes a stale count from cache and then
/// corrects itself.
final openAlertsBadgeCountProvider = Provider<int>((ref) {
  if (!ref.watch(isAdminProvider)) return 0;
  return ref.watch(alertsProvider).valueOrNull?.value.length ?? 0;
});
