import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/data/api/telemetry_api.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/cache_providers.dart';
import 'package:mobile/state/telemetry_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_secure_storage_platform.dart';

class _MockTelemetryApi extends Mock implements TelemetryApi {}

TelemetryReading _reading(String deviceId) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 0,
  longitude: 0,
  speed: 10,
  fuelLevel: 90,
  temperature: 20,
  recordedAt: DateTime.utc(2026),
);

void main() {
  late Directory tempDir;
  late FleetCache fleetCache;
  late _MockTelemetryApi api;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'latest_telemetry_provider_test',
    );
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );
    api = _MockTelemetryApi();

    container = ProviderContainer(
      overrides: [
        telemetryApiProvider.overrideWithValue(api),
        fleetCacheProvider.overrideWith((ref) async => fleetCache),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('the fetched list is keyed by device_id', () async {
    when(() => api.getLatest()).thenAnswer((_) async => [_reading('d1')]);

    final result = await container.read(latestTelemetryProvider.future);

    expect(result.value['d1']?.deviceId, 'd1');
  });

  test('upsert patches a single reading by device_id in place', () async {
    when(() => api.getLatest()).thenAnswer((_) async => [_reading('d1')]);
    await container.read(latestTelemetryProvider.future);

    final notifier = container.read(latestTelemetryProvider.notifier);
    notifier.upsert(_reading('d2'));

    final state = container.read(latestTelemetryProvider).value!;
    expect(state.value.keys, containsAll(['d1', 'd2']));
  });

  test(
    'cache hit paints instantly, then a background refresh replaces it',
    () async {
      when(() => api.getLatest()).thenAnswer((_) async => [_reading('d1')]);
      await container.read(latestTelemetryProvider.future);
      container.invalidate(latestTelemetryProvider);

      when(
        () => api.getLatest(),
      ).thenAnswer((_) async => [_reading('d1'), _reading('d2')]);

      final initial = await container.read(latestTelemetryProvider.future);
      expect(initial.value, hasLength(1));
      expect(initial.isStale, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final refreshed = container.read(latestTelemetryProvider);
      expect(refreshed.value?.value, hasLength(2));
      expect(refreshed.value?.isStale, isFalse);
    },
  );
}
