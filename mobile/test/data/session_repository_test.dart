import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/auth_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/repositories/session_repository.dart';
import 'package:mobile/state/token_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

const _userJson = {
  'id': 'u1',
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'role': 'admin',
  'is_active': true,
  'created_at': '2026-08-07T15:44:54.044240',
};

void main() {
  late Directory tempDir;
  late FleetCache fleetCache;
  late SessionRepository repository;
  late DioAdapter dioAdapter;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_repo_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();

    fleetCache = await FleetCache.open(
      userId: 'u1',
      secureStore: SecureStore(),
    );

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);
    repository = SessionRepository(AuthApi(dio));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('fetchAndCacheCurrentUser caches the user on success', () async {
    dioAdapter.onGet('/auth/me', (server) => server.reply(200, _userJson));

    final user = await repository.fetchAndCacheCurrentUser(fleetCache);

    expect(user.email, 'ada@example.com');
    expect(repository.cachedUser(fleetCache)?.email, 'ada@example.com');
  });

  test('the cached user is readable offline (no network call)', () async {
    dioAdapter.onGet('/auth/me', (server) => server.reply(200, _userJson));
    await repository.fetchAndCacheCurrentUser(fleetCache);

    expect(repository.cachedUser(fleetCache)?.id, 'u1');
  });

  test('cachedUser returns null when nothing was ever cached', () {
    expect(repository.cachedUser(fleetCache), isNull);
  });
}
