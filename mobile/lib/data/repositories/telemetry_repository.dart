import '../../domain/models/telemetry_reading.dart';
import '../../state/cached.dart';
import '../api/telemetry_api.dart';
import '../local/cache_entry.dart';
import '../local/fleet_cache.dart';

/// `GET /telemetry/latest` (cached under [FleetCache.telemetryLatestKey]),
/// `GET /telemetry/{id}/history` and `GET /telemetry` (both uncached
/// passthroughs — design §5.3: history ranges have an unbounded key space
/// and a near-zero cache hit rate).
class TelemetryRepository implements CachedSource<List<TelemetryReading>> {
  TelemetryRepository(this._api, this._cache);

  final TelemetryApi _api;
  final FleetCache _cache;

  static const _maxAge = Duration(hours: 24);

  @override
  Cached<List<TelemetryReading>>? peekCache() {
    final entry = _cache.read(FleetCache.telemetryLatestKey);
    if (entry == null) return null;
    if (DateTime.now().toUtc().difference(entry.cachedAt) > _maxAge) {
      return null;
    }
    final readings = (entry.payload as List<dynamic>)
        .map((json) => TelemetryReading.fromJson(json as Map<String, dynamic>))
        .toList();
    return Cached(readings, cachedAt: entry.cachedAt);
  }

  @override
  Future<List<TelemetryReading>> fetchAndCache() async {
    final readings = await _api.getLatest();
    await _cache.write(
      FleetCache.telemetryLatestKey,
      CacheEntry(
        cachedAt: DateTime.now().toUtc(),
        payload: readings.map((r) => r.toJson()).toList(),
      ),
    );
    return readings;
  }

  /// VDET-3 — never cached (design §5.3).
  Future<List<TelemetryReading>> fetchHistory({
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) => _api.getHistory(
    deviceId: deviceId,
    startDate: startDate,
    endDate: endDate,
    limit: limit,
  );

  /// The live feed's initial seed — uncached passthrough (design §5.3), same
  /// reasoning as [fetchHistory]: this window is about to be superseded by
  /// live WS pushes, so persisting it would only add a stale copy.
  Future<List<TelemetryReading>> fetchRecent({int limit = 200}) =>
      _api.getAll(limit: limit);
}
