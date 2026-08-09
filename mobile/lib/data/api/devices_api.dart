import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../domain/models/device.dart';

/// `GET /devices`, `GET /devices/{id}` — every method returns a model or
/// throws a [Failure], never a [DioException] (design §3.3).
class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  Future<List<Device>> getAll() async {
    try {
      final response = await _dio.get<List<dynamic>>('/devices');
      return response.data!
          .map((json) => Device.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  Future<Device> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/devices/$id');
      return Device.fromJson(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }
}

Failure _asFailure(DioException exception) => exception.error is Failure
    ? exception.error as Failure
    : UnknownFailure(cause: exception);
