import '../../domain/models/fleet_alert.dart';
import '../../state/cached.dart';
import '../api/alerts_api.dart';
import '../local/cache_entry.dart';
import '../local/fleet_cache.dart';

/// `GET /alerts` (open only) — cached under [FleetCache.alertsOpenKey]
/// (design §5.3). Only the `is_resolved=false` feed is cached: resolved/all
/// triage filters (slice 6) are online-only, uncached passthroughs, same
/// reasoning as telemetry history. Constructed only for admin sessions —
/// see `alerts_provider.dart` / ROLE-2.
class AlertRepository implements CachedSource<List<FleetAlert>> {
  AlertRepository(this._api, this._cache);

  final AlertsApi _api;
  final FleetCache _cache;

  static const _maxAge = Duration(hours: 24);
  static const _openAlertsLimit = 200;

  @override
  Cached<List<FleetAlert>>? peekCache() {
    final entry = _cache.read(FleetCache.alertsOpenKey);
    if (entry == null) return null;
    if (DateTime.now().toUtc().difference(entry.cachedAt) > _maxAge) {
      return null;
    }
    final alerts = (entry.payload as List<dynamic>)
        .map((json) => FleetAlert.fromJson(json as Map<String, dynamic>))
        .toList();
    return Cached(alerts, cachedAt: entry.cachedAt);
  }

  @override
  Future<List<FleetAlert>> fetchAndCache() async {
    final alerts = await _api.getAll(
      isResolved: false,
      limit: _openAlertsLimit,
    );
    await _cache.write(
      FleetCache.alertsOpenKey,
      CacheEntry(
        cachedAt: DateTime.now().toUtc(),
        payload: alerts.map((a) => a.toJson()).toList(),
      ),
    );
    return alerts;
  }

  /// ALT-3/ALT-4: the only write action in the app. No cache write here —
  /// the optimistic update against the open-alerts list lives in
  /// `AlertsNotifier` (design §9's write-failure rollback); the next
  /// background `fetchAndCache()` reconciles the persisted cache.
  Future<FleetAlert> resolve(String alertId) => _api.resolve(alertId);
}
