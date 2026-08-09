import 'package:dio/dio.dart';

import 'failure.dart';

/// Translates a [DioException] into the app's [Failure] hierarchy.
///
/// FastAPI emits three `detail` shapes on `badResponse`: a plain string, a
/// `{field, message}` dict (device 409 only — no current mobile call site,
/// but handled so a future one doesn't crash), or a 422 validation array.
/// `cancel` is rethrown as-is: a cancelled request was never meant to
/// surface as a user-facing failure.
Failure mapDioExceptionToFailure(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      throw exception;
    case DioExceptionType.badResponse:
      return _mapBadResponse(exception);
    case DioExceptionType.unknown:
      // dio wraps a bare SocketException as `unknown`; anything else here is
      // genuinely unclassified.
      if (exception.error is Exception &&
          exception.error.toString().contains('SocketException')) {
        return const NetworkFailure();
      }
      return UnknownFailure(cause: exception.error ?? exception);
    case DioExceptionType.transformTimeout:
      return const NetworkFailure();
  }
}

Failure _mapBadResponse(DioException exception) {
  final statusCode = exception.response?.statusCode ?? 0;
  final data = exception.response?.data;
  final detail = data is Map ? data['detail'] : null;

  switch (statusCode) {
    case 401:
      return UnauthorizedFailure(detail: _stringDetail(detail));
    case 403:
      return ForbiddenFailure(detail: _stringDetail(detail));
    case 404:
      return NotFoundFailure(detail: _stringDetail(detail));
    case 409:
      return _mapConflict(detail);
    case 422:
      return _mapValidation(detail);
  }
  if (statusCode >= 500) {
    return ServerFailure(detail: _stringDetail(detail));
  }
  return UnknownFailure(cause: exception, detail: _stringDetail(detail));
}

Failure _mapConflict(Object? detail) {
  if (detail is Map) {
    return ConflictFailure(
      field: detail['field'] as String?,
      detail: detail['message'] as String?,
    );
  }
  return ConflictFailure(field: null, detail: _stringDetail(detail));
}

Failure _mapValidation(Object? detail) {
  final fieldErrors = <String, String>{};
  if (detail is List) {
    for (final entry in detail) {
      if (entry is! Map) continue;
      final rawLoc = entry['loc'];
      final msg = entry['msg'] as String?;
      if (rawLoc is! List || msg == null) continue;
      final loc = rawLoc.cast<Object?>();
      final field = loc.lastWhere(
        (segment) => segment != 'body',
        orElse: () => loc.last,
      );
      fieldErrors['$field'] = msg;
    }
  }
  return ValidationFailure(fieldErrors: fieldErrors);
}

String? _stringDetail(Object? detail) => detail is String ? detail : null;
