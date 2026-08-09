import 'package:dio/dio.dart';

import '../../state/token_store.dart';

/// Paths that must never carry a bearer token: a stale token on `/auth/login`
/// would be sent (and logged) for no reason, and `/auth/register` must never
/// be poisoned by a half-valid session.
const unauthenticatedPaths = ['/auth/login', '/auth/register'];

/// Attaches the current token from [TokenStore] to every request except
/// [unauthenticatedPaths] (design §3.2).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore);

  final TokenStore _tokenStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (unauthenticatedPaths.contains(options.path)) {
      handler.next(options);
      return;
    }
    final token = _tokenStore.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
