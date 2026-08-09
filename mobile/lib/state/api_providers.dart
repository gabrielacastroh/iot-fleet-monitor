import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/redact.dart';
import '../data/api/alerts_api.dart';
import '../data/api/api_client.dart';
import '../data/api/auth_api.dart';
import '../data/api/auth_interceptor.dart';
import '../data/api/devices_api.dart';
import '../data/api/error_interceptor.dart';
import '../data/api/telemetry_api.dart';
import '../data/local/secure_store.dart';
import 'config_providers.dart';
import 'connectivity_provider.dart';
import 'token_store.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final tokenStoreProvider = Provider<TokenStore>((ref) {
  final store = TokenStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Reads [tokenStoreProvider] only — never `sessionProvider` — this is the
/// cycle breaker described in design §3.4.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStore = ref.watch(tokenStoreProvider);

  final dio = createApiClient(config);
  dio.interceptors.add(AuthInterceptor(tokenStore));
  dio.interceptors.add(
    ErrorInterceptor(
      tokenStore,
      // OFF-1: the reachability half of connectivity detection (design §8).
      onReachabilityChanged: (online) =>
          ref.read(connectivityProvider.notifier).reportReachability(online),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        logPrint: (object) => developer.log(redactSensitive(object.toString())),
      ),
    );
  }
  return dio;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => DevicesApi(ref.watch(dioProvider)),
);

final telemetryApiProvider = Provider<TelemetryApi>(
  (ref) => TelemetryApi(ref.watch(dioProvider)),
);

final alertsApiProvider = Provider<AlertsApi>(
  (ref) => AlertsApi(ref.watch(dioProvider)),
);
