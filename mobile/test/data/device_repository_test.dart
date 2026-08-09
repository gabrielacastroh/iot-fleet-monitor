import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/api/devices_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/data/local/cache_entry.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/state/token_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

const _deviceJson = {
  'id': 'd1',
  'vehicle_name': 'Camión 12',
  'device_code': 'ABC-1234',
  'plate': 'AB123CD',
  'is_active': true,
  'last_seen_at': null,
  'created_at': '2026-08-01T10:00:00.000000',
};

void main() {
  late Directory tempDir;
  late Dio dio;
  late DioAdapter dioAdapter;
  late FleetCache fleetCache;
  late DeviceRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('device_repository_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);

    fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );
    repository = DeviceRepository(DevicesApi(dio), fleetCache);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test(
    'cache miss: peekCache is null, fetchAndCache fetches and writes the cache',
    () async {
      expect(repository.peekCache(), isNull);

      dioAdapter.onGet(
        '/devices',
        (server) => server.reply(200, [_deviceJson]),
      );

      final devices = await repository.fetchAndCache();

      expect(devices, hasLength(1));
      final cached = repository.peekCache();
      expect(cached, isNotNull);
      expect(cached!.value.single.id, 'd1');
    },
  );

  test(
    'cache hit: peekCache returns instantly without a network call',
    () async {
      dioAdapter.onGet(
        '/devices',
        (server) => server.reply(200, [_deviceJson]),
      );
      await repository.fetchAndCache();

      final cached = repository.peekCache();

      expect(cached, isNotNull);
      expect(dioAdapter.history, hasLength(1));
    },
  );

  test('a network failure leaves the previously cached value intact', () async {
    dioAdapter.onGet('/devices', (server) => server.reply(200, [_deviceJson]));
    await repository.fetchAndCache();

    dioAdapter.onGet(
      '/devices',
      (server) => server.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/devices'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await expectLater(
      repository.fetchAndCache(),
      throwsA(isA<NetworkFailure>()),
    );
    expect(repository.peekCache()?.value.single.id, 'd1');
  });

  test('an entry older than 24h is treated as absent by peekCache', () async {
    await fleetCache.write(
      FleetCache.devicesKey,
      CacheEntry(
        cachedAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        payload: [_deviceJson],
      ),
    );

    expect(repository.peekCache(), isNull);
  });
}
