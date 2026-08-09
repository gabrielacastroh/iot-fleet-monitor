import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../domain/models/fleet_alert.dart';

/// `GET /alerts`, `GET /alerts/{device_id}`, `PATCH /alerts/{id}/resolve`
/// (resolve lands in slice 6) — every method returns a model or throws a
/// [Failure], never a [DioException] (design §3.3). Every method is
/// admin-only server-side (ROLE-2/ROLE-3): a non-admin caller must never
/// reach this class in the first place — see `alerts_provider.dart`.
class AlertsApi {
  AlertsApi(this._dio);

  final Dio _dio;

  /// ALT-1: only the filters the API actually supports — `alert_type`,
  /// `is_resolved`, `limit`. No other query parameter is ever sent.
  Future<List<FleetAlert>> getAll({bool? isResolved, int limit = 200}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/alerts',
        queryParameters: <String, dynamic>{
          'is_resolved': ?isResolved,
          'limit': limit,
        },
      );
      return _parseList(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  /// The device-scoped route ALT-2's fallback chain and VDET-4 rely on.
  Future<List<FleetAlert>> getForDevice(
    String deviceId, {
    bool? isResolved,
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/alerts/$deviceId',
        queryParameters: <String, dynamic>{
          'is_resolved': ?isResolved,
          'limit': limit,
        },
      );
      return _parseList(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  /// The only write in the app (design §5.3). Returns the updated
  /// [FleetAlert] — there is no `GET /alerts/{alert_id}` to re-fetch it.
  Future<FleetAlert> resolve(String alertId) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/alerts/$alertId/resolve',
      );
      return FleetAlert.fromJson(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  List<FleetAlert> _parseList(List<dynamic> data) => data
      .map((json) => FleetAlert.fromJson(json as Map<String, dynamic>))
      .toList();
}

Failure _asFailure(DioException exception) => exception.error is Failure
    ? exception.error as Failure
    : UnknownFailure(cause: exception);
