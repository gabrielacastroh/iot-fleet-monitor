import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/telemetry_repository.dart';
import '../domain/models/telemetry_reading.dart';
import 'cached.dart';
import 'repository_providers.dart';

/// Peek-then-refetch over `GET /telemetry/latest`, re-keyed by `device_id`
/// (design §6) — the wire/cache shape is a `List`, but every consumer wants
/// O(1) lookup by device, so the notifier (not the repository) owns the
/// List->Map transform. [upsert] is the WS layer's patch point (slice 3,
/// WS-6).
class LatestTelemetryNotifier
    extends AsyncNotifier<Cached<Map<String, TelemetryReading>>> {
  TelemetryRepository? _repository;

  @override
  Future<Cached<Map<String, TelemetryReading>>> build() async {
    _repository = await ref.watch(telemetryRepositoryProvider.future);
    final cached = _repository!.peekCache();
    if (cached == null) {
      final readings = await _repository!.fetchAndCache();
      return Cached(_byDeviceId(readings));
    }
    // A real event-loop turn, not a microtask — see CacheBackedNotifier's
    // identical reasoning in state/cached.dart.
    unawaited(Future(refresh));
    return Cached(_byDeviceId(cached.value), cachedAt: cached.cachedAt);
  }

  Future<void> refresh() async {
    final previousState = state;
    state = AsyncValue<Cached<Map<String, TelemetryReading>>>.loading()
        .copyWithPrevious(previousState);
    final result = await AsyncValue.guard(() async {
      final readings = await _repository!.fetchAndCache();
      return Cached(_byDeviceId(readings));
    });
    state = result.hasError ? result.copyWithPrevious(previousState) : result;
  }

  /// WS-6: patches a single reading by `device_id` without a full refetch.
  void upsert(TelemetryReading reading) {
    final current = state.valueOrNull;
    final map = Map<String, TelemetryReading>.from(current?.value ?? {});
    map[reading.deviceId] = reading;
    state = AsyncData(Cached(map, cachedAt: current?.cachedAt));
  }

  Map<String, TelemetryReading> _byDeviceId(List<TelemetryReading> readings) {
    return {for (final reading in readings) reading.deviceId: reading};
  }
}

final latestTelemetryProvider =
    AsyncNotifierProvider<
      LatestTelemetryNotifier,
      Cached<Map<String, TelemetryReading>>
    >(LatestTelemetryNotifier.new);

/// VDET-3's Telemetría tab query key. Value equality (not identity) so
/// the `.family` provider dedupes/rebuilds correctly on a range change.
class HistoryQuery {
  const HistoryQuery({
    required this.deviceId,
    required this.startDate,
    required this.endDate,
    this.limit = 1000,
  });

  final String deviceId;
  final DateTime startDate;
  final DateTime endDate;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.deviceId == deviceId &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(deviceId, startDate, endDate, limit);
}

/// VDET-3: `GET /telemetry/{device_id}/history` — never cached (design
/// §5.3, unbounded key space), so this is a plain fetch-per-query, not a
/// [CacheBackedNotifier]. `.autoDispose` because a history fetch is only
/// relevant while its tab is mounted.
class TelemetryHistoryNotifier
    extends
        AutoDisposeFamilyAsyncNotifier<List<TelemetryReading>, HistoryQuery> {
  @override
  Future<List<TelemetryReading>> build(HistoryQuery query) async {
    final repository = await ref.watch(telemetryRepositoryProvider.future);
    return repository.fetchHistory(
      deviceId: query.deviceId,
      startDate: query.startDate,
      endDate: query.endDate,
      limit: query.limit,
    );
  }
}

final telemetryHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<TelemetryHistoryNotifier, List<TelemetryReading>, HistoryQuery>(
      TelemetryHistoryNotifier.new,
    );
