import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/auth_interceptor.dart';
import 'package:mobile/state/token_store.dart';

void main() {
  late Dio dio;
  late TokenStore tokenStore;
  late DioAdapter dioAdapter;
  RequestOptions? captured;

  setUp(() {
    tokenStore = TokenStore();
    captured = null;
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(AuthInterceptor(tokenStore));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.next(options);
        },
      ),
    );
    dioAdapter = DioAdapter(dio: dio);
  });

  test('attaches the bearer token on an authenticated call', () async {
    tokenStore.setToken('test-token');
    dioAdapter.onGet('/devices', (server) => server.reply(200, []));

    await dio.get<void>('/devices');

    expect(captured!.headers['Authorization'], 'Bearer test-token');
  });

  test('never attaches a token on /auth/login', () async {
    tokenStore.setToken('test-token');
    dioAdapter.onPost('/auth/login', (server) => server.reply(200, {}));

    await dio.post<void>('/auth/login');

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });

  test('never attaches a token on /auth/register', () async {
    tokenStore.setToken('test-token');
    dioAdapter.onPost('/auth/register', (server) => server.reply(200, {}));

    await dio.post<void>('/auth/register');

    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });
}
