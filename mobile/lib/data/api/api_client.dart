import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

/// Dio factory + `BaseOptions` (design §3.1). Interceptors are added by the
/// caller (`dioProvider`) in the required order: `AuthInterceptor` ->
/// `ErrorInterceptor` -> debug-only redacting `LogInterceptor`.
Dio createApiClient(AppConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      // /telemetry history can return up to 1000 rows.
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
      // The error interceptor owns status->Failure translation; never throw
      // on a status this app maps itself.
      validateStatus: (status) => status != null && status < 400,
    ),
  );
}
