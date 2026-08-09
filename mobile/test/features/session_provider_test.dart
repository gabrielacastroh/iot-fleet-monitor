import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/session_provider.dart';

import '../helpers/fake_secure_storage_platform.dart';
import '../helpers/fake_websocket_channel.dart';

String _makeJwt({required String sub, required String role, required int exp}) {
  String segment(Map<String, dynamic> payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  final header = segment({'alg': 'none'});
  final payload = segment({'sub': sub, 'role': role, 'exp': exp});
  return '$header.$payload.signature';
}

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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_provider_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('AUTH-7: no stored token resolves to a null session', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    DioAdapter(dio: dio);
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final session = await container.read(sessionProvider.future);

    expect(session, isNull);
  });

  test(
    'AUTH-7: a valid unexpired token restores the session from GET /auth/me',
    () async {
      final futureExp =
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt(sub: 'u1', role: 'admin', exp: futureExp);
      await SecureStore().writeToken(token);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/auth/me', (server) => server.reply(200, _userJson));

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final session = await container.read(sessionProvider.future);

      expect(session, isNotNull);
      expect(session!.user.id, 'u1');
      expect(session.token, token);
    },
  );

  test(
    'AUTH-8: an expired token is dropped locally, GET /auth/me is never called',
    () async {
      final pastExp =
          DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt(sub: 'u1', role: 'admin', exp: pastExp);
      await SecureStore().writeToken(token);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      // No route registered: any request would throw a missing-mock
      // assertion, which we assert never happens.

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final session = await container.read(sessionProvider.future);

      expect(session, isNull);
      expect(adapter.history, isEmpty);
      expect(await SecureStore().readToken(), isNull);
    },
  );

  test('ROLE-1: role == "user" resolves isAdminProvider to false', () async {
    final futureExp =
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000;
    final token = _makeJwt(sub: 'u1', role: 'user', exp: futureExp);
    await SecureStore().writeToken(token);

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/auth/me',
      (server) => server.reply(200, {..._userJson, 'role': 'user'}),
    );

    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.future);

    expect(container.read(isAdminProvider), isFalse);
  });

  test(
    'WS-3: forceLogout closes the socket first and never reconnects with the stale token',
    () async {
      final futureExp =
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt(sub: 'u1', role: 'admin', exp: futureExp);
      await SecureStore().writeToken(token);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/auth/me', (server) => server.reply(200, _userJson));

      final factory = FakeChannelFactory();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          telemetrySocketProvider.overrideWith((ref) {
            final socket = TelemetrySocket(
              wsBaseUrl: 'ws://localhost:8000',
              channelFactory: factory.call,
            );
            ref.onDispose(socket.close);
            final token = ref.read(sessionProvider).valueOrNull?.token;
            if (token != null) socket.connect(token);
            return socket;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      final socket = container.read(telemetrySocketProvider);
      expect(factory.callCount, 1); // connected once, on session restore
      // Synchronous read, right after the socket is first built/connected —
      // `.open` needs a microtask turn for `channel.ready` to resolve
      // (see `TelemetrySocket._connectNow`), which hasn't happened yet here.
      expect(socket.connectionState, WsConnectionState.connecting);
      expect(factory.channels.single.appCloseCode, isNull);

      await container.read(sessionProvider.notifier).forceLogout();

      // Closed (not reconnected): the ORIGINAL channel got an app-side
      // close, and no second `connect()` happened even though invalidating
      // telemetrySocketProvider rebuilds it — the new instance sees a
      // `null` session token by the time it's constructed.
      expect(factory.channels.single.appCloseCode, 1000);
      expect(factory.callCount, 1);
      expect(container.read(sessionProvider).valueOrNull, isNull);
    },
  );
}
