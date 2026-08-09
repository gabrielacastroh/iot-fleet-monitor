import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/data/local/cache_entry.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/state/token_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

const _alertJson = {
  'id': 'a1',
  'device_id': 'd1',
  'alert_type': 'low_fuel',
  'message': 'Fuel is low',
  'is_resolved': false,
  'created_at': '2026-08-08T10:00:00.000000',
};

void main() {
  late Directory tempDir;
  late Dio dio;
  late DioAdapter dioAdapter;
  late FleetCache fleetCache;
  late AlertRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('alert_repository_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);

    fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );
    repository = AlertRepository(AlertsApi(dio), fleetCache);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test(
    'cache miss: peekCache is null, fetchAndCache fetches only open alerts',
    () async {
      expect(repository.peekCache(), isNull);

      dioAdapter.onGet(
        '/alerts',
        (server) => server.reply(200, [_alertJson]),
        queryParameters: {'is_resolved': false, 'limit': 200},
      );

      final alerts = await repository.fetchAndCache();

      expect(alerts, hasLength(1));
      expect(repository.peekCache()?.value.single.id, 'a1');
    },
  );

  test(
    'cache hit: peekCache returns instantly without a network call',
    () async {
      dioAdapter.onGet(
        '/alerts',
        (server) => server.reply(200, [_alertJson]),
        queryParameters: {'is_resolved': false, 'limit': 200},
      );
      await repository.fetchAndCache();

      expect(repository.peekCache(), isNotNull);
      expect(dioAdapter.history, hasLength(1));
    },
  );

  test(
    'a network failure leaves the previously cached open alerts intact',
    () async {
      dioAdapter.onGet(
        '/alerts',
        (server) => server.reply(200, [_alertJson]),
        queryParameters: {'is_resolved': false, 'limit': 200},
      );
      await repository.fetchAndCache();

      dioAdapter.onGet(
        '/alerts',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/alerts'),
            type: DioExceptionType.connectionError,
          ),
        ),
        queryParameters: {'is_resolved': false, 'limit': 200},
      );

      await expectLater(
        repository.fetchAndCache(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(repository.peekCache()?.value.single.id, 'a1');
    },
  );

  test('an entry older than 24h is treated as absent by peekCache', () async {
    await fleetCache.write(
      FleetCache.alertsOpenKey,
      CacheEntry(
        cachedAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        payload: [_alertJson],
      ),
    );

    expect(repository.peekCache(), isNull);
  });
}
