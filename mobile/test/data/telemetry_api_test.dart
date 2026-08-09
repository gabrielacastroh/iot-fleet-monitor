import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/data/api/telemetry_api.dart';
import 'package:mobile/state/token_store.dart';

const _readingJson = {
  'id': 't1',
  'device_id': 'd1',
  'latitude': -34.6,
  'longitude': -58.4,
  'speed': 80,
  'fuel_level': 55,
  'temperature': 72,
  'recorded_at': '2026-08-07T15:44:54.044240',
};

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TelemetryApi telemetryApi;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(ErrorInterceptor(TokenStore()));
    dioAdapter = DioAdapter(dio: dio);
    telemetryApi = TelemetryApi(dio);
  });

  test('getLatest() returns one reading per device', () async {
    dioAdapter.onGet(
      '/telemetry/latest',
      (server) => server.reply(200, [_readingJson]),
    );

    final readings = await telemetryApi.getLatest();

    expect(readings, hasLength(1));
    expect(readings.single.deviceId, 'd1');
  });

  test(
    'getHistory() sends start_date/end_date/limit as ISO query params',
    () async {
      final start = DateTime.utc(2026, 8, 1);
      final end = DateTime.utc(2026, 8, 8);
      dioAdapter.onGet(
        '/telemetry/d1/history',
        (server) => server.reply(200, [_readingJson]),
        queryParameters: {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
          'limit': 200,
        },
      );

      final readings = await telemetryApi.getHistory(
        deviceId: 'd1',
        startDate: start,
        endDate: end,
        limit: 200,
      );

      expect(readings, hasLength(1));
    },
  );

  test('getAll() lists readings with optional filters', () async {
    dioAdapter.onGet(
      '/telemetry',
      (server) => server.reply(200, [_readingJson]),
      queryParameters: {'device_id': 'd1', 'limit': 50},
    );

    final readings = await telemetryApi.getAll(deviceId: 'd1', limit: 50);

    expect(readings, hasLength(1));
  });
}
