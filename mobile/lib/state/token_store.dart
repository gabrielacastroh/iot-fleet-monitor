import 'dart:async';

/// The cycle breaker (design §3.4): `dioProvider` cannot read `sessionProvider`
/// (which needs `authApi`, which needs `dioProvider`). `TokenStore` holds the
/// current token for the [AuthInterceptor] to read, and a broadcast
/// `unauthorized` signal the [ErrorInterceptor] pushes to on any 401 — with
/// no provider depending on the other in a cycle.
class TokenStore {
  String? _token;
  final _unauthorizedController = StreamController<void>.broadcast();

  String? get token => _token;

  /// Fires whenever any authenticated request receives a 401. `SessionNotifier`
  /// listens to this and runs `forceLogout` — this class never touches
  /// session state itself.
  Stream<void> get unauthorized => _unauthorizedController.stream;

  void setToken(String? token) => _token = token;

  void reportUnauthorized() => _unauthorizedController.add(null);

  void dispose() => _unauthorizedController.close();
}
