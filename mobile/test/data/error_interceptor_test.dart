import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/state/token_store.dart';

void main() {
  late Dio dio;
  late TokenStore tokenStore;
  late DioAdapter dioAdapter;

  setUp(() {
    tokenStore = TokenStore();
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(tokenStore));
    dioAdapter = DioAdapter(dio: dio);
  });

  test(
    'a 401 on any endpoint other than /auth/login reports unauthorized',
    () async {
      dioAdapter.onGet('/devices', (server) => server.reply(401, {}));
      final events = <void>[];
      final subscription = tokenStore.unauthorized.listen(events.add);

      await expectLater(
        dio.get<void>('/devices'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      await subscription.cancel();
    },
  );

  test(
    'a 401 on /auth/login itself does not report unauthorized (AUTH-9 scope)',
    () async {
      dioAdapter.onPost('/auth/login', (server) => server.reply(401, {}));
      final events = <void>[];
      final subscription = tokenStore.unauthorized.listen(events.add);

      await expectLater(
        dio.post<void>('/auth/login'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await subscription.cancel();
    },
  );

  test('exposes the mapped Failure via DioException.error', () async {
    dioAdapter.onGet(
      '/devices',
      (server) => server.reply(401, {'detail': 'no'}),
    );

    try {
      await dio.get<void>('/devices');
      fail('expected a DioException');
    } on DioException catch (e) {
      expect(e.error, isA<UnauthorizedFailure>());
    }
  });
}
