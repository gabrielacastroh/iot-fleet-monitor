import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/api/auth_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/state/token_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late AuthApi authApi;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    // ErrorInterceptor is what turns a DioException into a Failure
    // (design §3.3) — every real Dio instance carries one via dioProvider.
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);
    authApi = AuthApi(dio);
  });

  test('login sends form-urlencoded username/password, not JSON', () async {
    dioAdapter.onPost(
      '/auth/login',
      (server) =>
          server.reply(200, {'access_token': 'a.b.c', 'token_type': 'bearer'}),
      data: {'username': 'ada@example.com', 'password': 'secret'},
      headers: {Headers.contentTypeHeader: Headers.formUrlEncodedContentType},
    );

    final token = await authApi.login(
      email: 'ada@example.com',
      password: 'secret',
    );

    expect(token, 'a.b.c');
  });

  test('a 401 on login maps to UnauthorizedFailure (AUTH-2)', () async {
    dioAdapter.onPost(
      '/auth/login',
      (server) => server.reply(401, {'detail': 'Credenciales inválidas'}),
      data: Matchers.any,
    );

    await expectLater(
      authApi.login(email: 'ada@example.com', password: 'wrong'),
      throwsA(isA<UnauthorizedFailure>()),
    );
  });

  test(
    'a connection failure on login maps to NetworkFailure (AUTH-3)',
    () async {
      dioAdapter.onPost(
        '/auth/login',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await expectLater(
        authApi.login(email: 'ada@example.com', password: 'secret'),
        throwsA(isA<NetworkFailure>()),
      );
    },
  );

  test('register sends JSON body', () async {
    dioAdapter.onPost(
      '/auth/register',
      (server) => server.reply(200, {
        'id': 'u1',
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'role': 'user',
        'is_active': true,
        'created_at': '2026-08-07T15:44:54.044240',
      }),
      data: {
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'password': 'secret',
      },
    );

    final user = await authApi.register(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret',
    );

    expect(user.email, 'ada@example.com');
  });

  test('me() returns the current user', () async {
    dioAdapter.onGet(
      '/auth/me',
      (server) => server.reply(200, {
        'id': 'u1',
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'role': 'admin',
        'is_active': true,
        'created_at': '2026-08-07T15:44:54.044240',
      }),
    );

    final user = await authApi.me();

    expect(user.id, 'u1');
  });
}
