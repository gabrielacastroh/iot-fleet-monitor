import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The only place a token or the Hive encryption key touches disk (design
/// §10). Android uses `encryptedSharedPreferences`; iOS uses
/// `first_unlock_this_device` (not synced to iCloud, unreadable before
/// first unlock).
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _hiveKeyKey = 'hive_key';

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<void> writeHiveKey(String key) =>
      _storage.write(key: _hiveKeyKey, value: key);

  Future<String?> readHiveKey() => _storage.read(key: _hiveKeyKey);

  /// Clears the token and the Hive key. Part of the logout scrub (design
  /// §10) — never falls back to an unencrypted cache when this fails.
  Future<void> deleteAll() => _storage.deleteAll();
}
