/// Every API call in this app resolves to a model or throws a [Failure].
/// A `DioException` never crosses the `data/api` boundary — see
/// `failure_mapper.dart` for the translation.
sealed class Failure {
  const Failure({this.detail});

  /// Server-provided text, already Spanish where present. May be null.
  final String? detail;
}

/// No route to the server: timeout, DNS failure, connection refused, or any
/// other transport-level error.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.detail});
}

/// 401 — missing, invalid, or expired credentials.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.detail});
}

/// 403 — authenticated but not permitted.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.detail});
}

/// 404 — resource does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.detail});
}

/// 409 — a conflicting resource already exists (e.g. duplicate email).
final class ConflictFailure extends Failure {
  const ConflictFailure({required this.field, super.detail});

  final String? field;
}

/// 422 — request validation failed. Keyed by field name.
final class ValidationFailure extends Failure {
  const ValidationFailure({required this.fieldErrors, super.detail});

  final Map<String, String> fieldErrors;
}

/// 5xx — the server is up but failed to handle the request.
final class ServerFailure extends Failure {
  const ServerFailure({super.detail});
}

/// Anything that doesn't fit the shapes above.
final class UnknownFailure extends Failure {
  const UnknownFailure({required this.cause, super.detail});

  final Object cause;
}
