import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/state/token_store.dart';

void main() {
  test('set/read the current token', () {
    final tokenStore = TokenStore();

    expect(tokenStore.token, isNull);

    tokenStore.setToken('abc.def.ghi');
    expect(tokenStore.token, 'abc.def.ghi');

    tokenStore.setToken(null);
    expect(tokenStore.token, isNull);
  });

  test('unauthorized stream emits on reportUnauthorized()', () async {
    final tokenStore = TokenStore();

    final emitted = <void>[];
    final subscription = tokenStore.unauthorized.listen(emitted.add);

    tokenStore.reportUnauthorized();
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(1));

    await subscription.cancel();
    tokenStore.dispose();
  });
}
