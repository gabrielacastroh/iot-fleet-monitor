import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../core/time/app_time.dart';
import '../../domain/models/telemetry_reading.dart';

/// `GET /telemetry/latest`, `GET /telemetry/{id}/history`, `GET /telemetry`
/// — every method returns a model or throws a [Failure], never a
/// [DioException] (design §3.3).
class TelemetryApi {
  TelemetryApi(this._dio);

  final Dio _dio;

  /// One reading per device, newest first. No `limit` parameter — the
  /// backend intentionally bounds this by the number of registered devices.
  Future<List<TelemetryReading>> getLatest() async {
    try {
      final response = await _dio.get<List<dynamic>>('/telemetry/latest');
      return _parseList(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  /// VDET-3: `GET /telemetry/{device_id}/history?start_date&end_date&limit`.
  Future<List<TelemetryReading>> getHistory({
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/telemetry/$deviceId/history',
        queryParameters: <String, dynamic>{
          'start_date': serializeUtc(startDate),
          'end_date': serializeUtc(endDate),
          'limit': limit,
        },
      );
      return _parseList(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  /// `GET /telemetry` — the alert-detail fallback chain's last resort
  /// (design §7).
  Future<List<TelemetryReading>> getAll({
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 1000,
  }) async {
    try {
      final startDateIso = startDate == null ? null : serializeUtc(startDate);
      final endDateIso = endDate == null ? null : serializeUtc(endDate);
      final response = await _dio.get<List<dynamic>>(
        '/telemetry',
        queryParameters: <String, dynamic>{
          'device_id': ?deviceId,
          'start_date': ?startDateIso,
          'end_date': ?endDateIso,
          'limit': limit,
        },
      );
      return _parseList(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  List<TelemetryReading> _parseList(List<dynamic> data) => data
      .map((json) => TelemetryReading.fromJson(json as Map<String, dynamic>))
      .toList();
}

Failure _asFailure(DioException exception) => exception.error is Failure
    ? exception.error as Failure
    : UnknownFailure(cause: exception);
