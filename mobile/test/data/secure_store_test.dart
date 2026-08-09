import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/local/secure_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

void main() {
  late SecureStore secureStore;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    secureStore = SecureStore();
  });

  test('round trips the auth token', () async {
    await secureStore.writeToken('abc.def.ghi');
    expect(await secureStore.readToken(), 'abc.def.ghi');

    await secureStore.deleteToken();
    expect(await secureStore.readToken(), isNull);
  });

  test('round trips the hive encryption key', () async {
    await secureStore.writeHiveKey('base64key');
    expect(await secureStore.readHiveKey(), 'base64key');
  });

  test('deleteAll clears both the token and the hive key', () async {
    await secureStore.writeToken('token');
    await secureStore.writeHiveKey('key');

    await secureStore.deleteAll();

    expect(await secureStore.readToken(), isNull);
    expect(await secureStore.readHiveKey(), isNull);
  });
}
