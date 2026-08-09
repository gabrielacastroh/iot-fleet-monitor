import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/api/devices_api.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/state/token_store.dart';

const _deviceJson = {
  'id': 'd1',
  'vehicle_name': 'Camión 12',
  'device_code': 'ABC-1234',
  'plate': 'AB123CD',
  'is_active': true,
  'last_seen_at': null,
  'created_at': '2026-08-01T10:00:00.000000',
};

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late DevicesApi devicesApi;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);
    devicesApi = DevicesApi(dio);
  });

  test('getAll() returns the full fleet', () async {
    dioAdapter.onGet('/devices', (server) => server.reply(200, [_deviceJson]));

    final devices = await devicesApi.getAll();

    expect(devices, hasLength(1));
    expect(devices.single.vehicleName, 'Camión 12');
  });

  test('getById() returns a single device', () async {
    dioAdapter.onGet('/devices/d1', (server) => server.reply(200, _deviceJson));

    final device = await devicesApi.getById('d1');

    expect(device.id, 'd1');
  });

  test('a 404 on getById() maps to NotFoundFailure', () async {
    dioAdapter.onGet(
      '/devices/missing',
      (server) => server.reply(404, {'detail': 'Device not found'}),
    );

    await expectLater(
      devicesApi.getById('missing'),
      throwsA(isA<NotFoundFailure>()),
    );
  });
}
