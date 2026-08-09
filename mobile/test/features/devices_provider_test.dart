import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/data/api/devices_api.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/cache_providers.dart';
import 'package:mobile/state/devices_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_secure_storage_platform.dart';

class _MockDevicesApi extends Mock implements DevicesApi {}

Device _device(String id) => Device(
  id: id,
  vehicleName: 'Camión $id',
  deviceCode: 'ABC-$id',
  plate: 'AB$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

void main() {
  late Directory tempDir;
  late FleetCache fleetCache;
  late _MockDevicesApi api;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('devices_provider_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );
    api = _MockDevicesApi();

    container = ProviderContainer(
      overrides: [
        devicesApiProvider.overrideWithValue(api),
        fleetCacheProvider.overrideWith((ref) async => fleetCache),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('cache miss: awaits the network fetch and paints fresh data', () async {
    when(() => api.getAll()).thenAnswer((_) async => [_device('d1')]);

    final result = await container.read(devicesProvider.future);

    expect(result.value.single.id, 'd1');
    expect(result.isStale, isFalse);
  });

  test(
    'cache hit: paints instantly from cache, then a background refresh replaces it',
    () async {
      when(() => api.getAll()).thenAnswer((_) async => [_device('d1')]);
      await container.read(devicesProvider.future);
      container.invalidate(devicesProvider);

      when(
        () => api.getAll(),
      ).thenAnswer((_) async => [_device('d1'), _device('d2')]);

      final initial = await container.read(devicesProvider.future);
      expect(initial.value, hasLength(1));
      expect(initial.isStale, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final refreshed = container.read(devicesProvider);
      expect(refreshed.value?.value, hasLength(2));
      expect(refreshed.value?.isStale, isFalse);
    },
  );
}
