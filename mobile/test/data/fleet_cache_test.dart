import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/data/local/cache_entry.dart';
import 'package:mobile/data/local/fleet_cache.dart';
import 'package:mobile/data/local/secure_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

void main() {
  late Directory tempDir;
  late SecureStore secureStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleet_cache_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    secureStore = SecureStore();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('writes and reads a cache entry', () async {
    final cache = await FleetCache.open(userId: 'u1', secureStore: secureStore);

    final entry = CacheEntry(
      cachedAt: DateTime.utc(2026, 8, 8, 12),
      payload: {'id': 'd1'},
    );
    await cache.write(FleetCache.devicesKey, entry);

    final read = cache.read(FleetCache.devicesKey);
    expect(read, isNotNull);
    expect(read!.cachedAt, entry.cachedAt);
    expect(read.payload, {'id': 'd1'});
  });

  test('reading a missing key returns null', () async {
    final cache = await FleetCache.open(userId: 'u1', secureStore: secureStore);

    expect(cache.read(FleetCache.sessionUserKey), isNull);
  });

  test('the AES key persists across box re-opens for the same user', () async {
    final first = await FleetCache.open(userId: 'u1', secureStore: secureStore);
    await first.write(
      FleetCache.sessionUserKey,
      CacheEntry(cachedAt: DateTime.utc(2026), payload: {'id': 'u1'}),
    );
    await first.close();

    final reopened = await FleetCache.open(
      userId: 'u1',
      secureStore: secureStore,
    );
    expect(reopened.read(FleetCache.sessionUserKey)?.payload, {'id': 'u1'});
  });

  test('deleteFromDisk purges the box', () async {
    final cache = await FleetCache.open(userId: 'u1', secureStore: secureStore);
    await cache.write(
      FleetCache.devicesKey,
      CacheEntry(cachedAt: DateTime.utc(2026), payload: []),
    );

    await cache.deleteFromDisk();

    final reopened = await FleetCache.open(
      userId: 'u1',
      secureStore: secureStore,
    );
    expect(reopened.read(FleetCache.devicesKey), isNull);
  });
}
