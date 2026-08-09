import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/local/cache_entry.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/cache_providers.dart';
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

Map<String, dynamic> _userJson(String id) => {
  'id': id,
  'name': 'User $id',
  'email': '$id@example.com',
  'role': 'admin',
  'is_active': true,
  'created_at': '2026-08-07T15:44:54.044240',
};

bool _boxFileExists(Directory dir, String userId) =>
    dir.listSync().any((entity) => entity.path.contains('fleet_$userId'));

int get _futureExp =>
    DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch ~/
    1000;

/// Records the moment [TelemetrySocket.close] is invoked so the test can
/// assert what has (not) happened yet at that exact point in the scrub
/// sequence — proving order, not just the final state.
class _OrderTrackingSocket extends TelemetrySocket {
  _OrderTrackingSocket({
    required super.wsBaseUrl,
    required this.onClosing,
    super.channelFactory,
  });

  final void Function() onClosing;

  @override
  void close() {
    onClosing();
    super.close();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('logout_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('the socket is closed strictly before the Hive box is purged', () async {
    final token = _makeJwt(sub: 'u1', role: 'admin', exp: _futureExp);
    await SecureStore().writeToken(token);

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/auth/me', (server) => server.reply(200, _userJson('u1')));

    bool? boxExistedWhenSocketClosed;
    final factory = FakeChannelFactory();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        telemetrySocketProvider.overrideWith((ref) {
          final socket = _OrderTrackingSocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
            // `close()` fires again on provider disposal at container
            // teardown (post-purge) — only the *first* call, the one
            // `forceLogout` itself triggers, is the one under test.
            onClosing: () {
              boxExistedWhenSocketClosed ??= _boxFileExists(tempDir, 'u1');
            },
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
    // Force the box to actually exist on disk before logout.
    final cache = await container.read(fleetCacheProvider.future);
    await cache!.write(
      FleetCache.devicesKey,
      CacheEntry(cachedAt: DateTime.utc(2026), payload: []),
    );

    await container.read(sessionProvider.notifier).forceLogout();

    expect(boxExistedWhenSocketClosed, isTrue);
    expect(
      _boxFileExists(tempDir, 'u1'),
      isFalse,
      reason: 'the box must be gone once forceLogout has returned',
    );
    expect(factory.channels.single.appCloseCode, 1000);
  });

  test(
    'AUTH-9: two concurrent forceLogout calls (double 401) tear down idempotently',
    () async {
      final token = _makeJwt(sub: 'u1', role: 'admin', exp: _futureExp);
      await SecureStore().writeToken(token);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/auth/me', (server) => server.reply(200, _userJson('u1')));

      var socketCloseCount = 0;
      final factory = FakeChannelFactory();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          telemetrySocketProvider.overrideWith((ref) {
            final socket = _OrderTrackingSocket(
              wsBaseUrl: 'ws://localhost:8000',
              channelFactory: factory.call,
              onClosing: () => socketCloseCount++,
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
      final cache = await container.read(fleetCacheProvider.future);
      await cache!.write(
        FleetCache.devicesKey,
        CacheEntry(cachedAt: DateTime.utc(2026), payload: []),
      );

      final notifier = container.read(sessionProvider.notifier);
      // Mirrors `TokenStore.unauthorized`'s broadcast stream calling
      // `forceLogout()` twice for two in-flight 401s racing each other —
      // must not throw (e.g. from a double `Box.deleteFromDisk()`) and
      // must only perform the teardown once.
      await Future.wait([notifier.forceLogout(), notifier.forceLogout()]);

      expect(container.read(sessionProvider).valueOrNull, isNull);
      expect(_boxFileExists(tempDir, 'u1'), isFalse);
      // >=1, not strictly 1: `ref.invalidate(telemetrySocketProvider)` at
      // the end of the (single) teardown also disposes the old instance,
      // which calls `close()` again — pre-existing, harmless behavior
      // (`TelemetrySocket.close()` is idempotent), orthogonal to the
      // double-401 race this test targets.
      expect(socketCloseCount, greaterThanOrEqualTo(1));
      expect(await SecureStore().readToken(), isNull);
    },
  );

  test(
    'AUTH-10: a cold start after logout shows no cached vehicles and requires login',
    () async {
      final token = _makeJwt(sub: 'u1', role: 'admin', exp: _futureExp);
      await SecureStore().writeToken(token);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/auth/me', (server) => server.reply(200, _userJson('u1')));

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      final cache = await container.read(fleetCacheProvider.future);
      await cache!.write(
        FleetCache.devicesKey,
        CacheEntry(cachedAt: DateTime.utc(2026), payload: [_userJson('u1')]),
      );

      await container.read(sessionProvider.notifier).forceLogout();

      // Cold start: a fresh container, same secure storage/Hive directory.
      final coldContainer = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(coldContainer.dispose);

      final coldSession = await coldContainer.read(sessionProvider.future);
      expect(coldSession, isNull);

      final coldCache = await FleetCache.open(
        userId: 'u1',
        secureStore: SecureStore(),
      );
      expect(coldCache.read(FleetCache.devicesKey), isNull);
    },
  );

  test(
    'OFF-7: a second account on the same device never reads the first account\'s cache',
    () async {
      final secureStore = SecureStore();
      final cacheU1 = await FleetCache.open(
        userId: 'u1',
        secureStore: secureStore,
      );
      await cacheU1.write(
        FleetCache.devicesKey,
        CacheEntry(cachedAt: DateTime.utc(2026), payload: ['u1-device']),
      );
      await cacheU1.close();

      final cacheU2 = await FleetCache.open(
        userId: 'u2',
        secureStore: secureStore,
      );
      expect(cacheU2.read(FleetCache.devicesKey), isNull);
    },
  );
}
