import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/data/api/telemetry_api.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/state/token_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

const _readingJson = {
  'id': 't1',
  'device_id': 'd1',
  'latitude': -34.6,
  'longitude': -58.4,
  'speed': 80,
  'fuel_level': 55,
  'temperature': 72,
  'recorded_at': '2026-08-07T15:44:54.044240',
};

void main() {
  late Directory tempDir;
  late Dio dio;
  late DioAdapter dioAdapter;
  late TelemetryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'telemetry_repository_test',
    );
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);

    final fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );
    repository = TelemetryRepository(TelemetryApi(dio), fleetCache);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test(
    'fetchAndCache caches telemetry_latest; peekCache reads it back',
    () async {
      expect(repository.peekCache(), isNull);

      dioAdapter.onGet(
        '/telemetry/latest',
        (server) => server.reply(200, [_readingJson]),
      );

      final readings = await repository.fetchAndCache();

      expect(readings, hasLength(1));
      expect(repository.peekCache()?.value.single.deviceId, 'd1');
    },
  );

  test('fetchHistory never touches the Hive cache', () async {
    dioAdapter.onGet(
      '/telemetry/d1/history',
      (server) => server.reply(200, [_readingJson]),
    );

    await repository.fetchHistory(
      deviceId: 'd1',
      startDate: DateTime.utc(2026, 8),
      endDate: DateTime.utc(2026, 8, 8),
    );

    // No telemetry_latest key was ever written by fetchHistory.
    expect(repository.peekCache(), isNull);
  });
}
