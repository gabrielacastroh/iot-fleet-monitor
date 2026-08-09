import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/state/token_store.dart';

const _alertJson = {
  'id': 'a1',
  'device_id': 'd1',
  'alert_type': 'low_fuel',
  'message': 'Fuel is low',
  'is_resolved': false,
  'created_at': '2026-08-08T10:00:00.000000',
};

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late AlertsApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);
    api = AlertsApi(dio);
  });

  test(
    'getAll sends only is_resolved and limit, never an unsupported param',
    () async {
      dioAdapter.onGet(
        '/alerts',
        (server) => server.reply(200, [_alertJson]),
        queryParameters: {'is_resolved': false, 'limit': 200},
      );

      final alerts = await api.getAll(isResolved: false);

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'a1');
    },
  );

  test('getForDevice hits the device-scoped route', () async {
    dioAdapter.onGet(
      '/alerts/d1',
      (server) => server.reply(200, [_alertJson]),
      queryParameters: {'limit': 200},
    );

    final alerts = await api.getForDevice('d1');

    expect(alerts.single.deviceId, 'd1');
  });

  test(
    'resolve PATCHes the resolve route and returns the updated alert',
    () async {
      dioAdapter.onPatch(
        '/alerts/a1/resolve',
        (server) => server.reply(200, {..._alertJson, 'is_resolved': true}),
      );

      final resolved = await api.resolve('a1');

      expect(resolved.id, 'a1');
      expect(resolved.isResolved, isTrue);
    },
  );
}
