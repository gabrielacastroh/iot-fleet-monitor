import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../core/error/failure_mapper.dart';
import '../../state/token_store.dart';

/// Maps every [DioException] to a [Failure] (via T0.3.2) so it never crosses
/// the `data/api` boundary, reports 401s to [TokenStore] (never touches
/// `sessionProvider` directly — design §3.4), and reports request
/// reachability for `ConnectivityNotifier` (T3.11, wired in slice 3).
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor(this._tokenStore, {this.onReachabilityChanged});

  final TokenStore _tokenStore;
  final void Function(bool online)? onReachabilityChanged;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    onReachabilityChanged?.call(true);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Failure failure;
    try {
      failure = mapDioExceptionToFailure(err);
    } on DioException {
      // `mapDioExceptionToFailure` rethrows `cancel` as-is; let it pass
      // through unmapped, a cancelled request is never user-facing.
      handler.next(err);
      return;
    }

    onReachabilityChanged?.call(failure is! NetworkFailure);

    // AUTH-9 scope: any 401 except on /auth/login itself (a wrong password
    // is AUTH-2, not a session teardown).
    if (failure is UnauthorizedFailure &&
        err.requestOptions.path != '/auth/login') {
      _tokenStore.reportUnauthorized();
    }

    handler.next(err.copyWith(error: failure));
  }
}
