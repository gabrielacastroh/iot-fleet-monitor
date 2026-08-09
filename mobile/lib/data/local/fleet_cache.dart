import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'cache_entry.dart';
import 'secure_store.dart';

/// One encrypted Hive box per user (`fleet_<userId>`) — a single encryption
/// key, a single `deleteFromDisk()` on logout, four well-known keys instead
/// of four boxes (design §5.1). Values are `jsonEncode(CacheEntry(...)
/// .toJson())` strings — no `TypeAdapter`s, reusing what freezed's `toJson`
/// already produces.
class FleetCache {
  FleetCache(this._box);

  final Box<String> _box;

  static const sessionUserKey = 'session_user';
  static const devicesKey = 'devices';
  static const telemetryLatestKey = 'telemetry_latest';
  static const alertsOpenKey = 'alerts_open';

  /// Opens (or creates) the box for [userId], generating and persisting a
  /// new AES key on first launch (design §10).
  static Future<FleetCache> open({
    required String userId,
    required SecureStore secureStore,
  }) async {
    var keyBase64 = await secureStore.readHiveKey();
    if (keyBase64 == null) {
      keyBase64 = base64Encode(Hive.generateSecureKey());
      await secureStore.writeHiveKey(keyBase64);
    }
    final box = await Hive.openBox<String>(
      'fleet_$userId',
      encryptionCipher: HiveAesCipher(base64Decode(keyBase64)),
    );
    return FleetCache(box);
  }

  Future<void> write(String key, CacheEntry entry) =>
      _box.put(key, jsonEncode(entry.toJson()));

  CacheEntry? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> close() => _box.close();

  /// Part of the logout scrub (design §10): the whole user box, not a key
  /// sweep.
  Future<void> deleteFromDisk() => _box.deleteFromDisk();
}
