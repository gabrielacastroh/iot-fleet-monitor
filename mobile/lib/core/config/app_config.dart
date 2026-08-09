import 'package:flutter/foundation.dart';

/// Resolved network configuration for the app: the REST API base URL and
/// the derived WebSocket base URL.
///
/// Values come from `--dart-define=API_BASE_URL` / `--dart-define=WS_BASE_URL`
/// when present, falling back to platform-aware defaults for local dev.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.wsBaseUrl});

  final String apiBaseUrl;
  final String wsBaseUrl;

  /// Resolves config from dart-define overrides and the running platform.
  ///
  /// [platform] defaults to [defaultTargetPlatform] but is injectable so this
  /// stays a pure function under test (no `debugDefaultTargetPlatformOverride`
  /// needed).
  factory AppConfig.resolve({
    String apiBaseUrlOverride = '',
    String wsBaseUrlOverride = '',
    TargetPlatform? platform,
  }) {
    final apiBaseUrl = apiBaseUrlOverride.isNotEmpty
        ? apiBaseUrlOverride
        : _defaultApiBaseUrl(platform ?? defaultTargetPlatform);
    final wsBaseUrl = wsBaseUrlOverride.isNotEmpty
        ? wsBaseUrlOverride
        : _deriveWsBaseUrl(apiBaseUrl);
    return AppConfig(apiBaseUrl: apiBaseUrl, wsBaseUrl: wsBaseUrl);
  }

  static String _defaultApiBaseUrl(TargetPlatform platform) {
    // The Android emulator's loopback interface is not the host's; 10.0.2.2
    // is the documented alias back to the host machine. A physical device on
    // the LAN needs an explicit API_BASE_URL override (see mobile/README.md).
    return platform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
  }

  static String _deriveWsBaseUrl(String apiBaseUrl) {
    if (apiBaseUrl.startsWith('https://')) {
      return 'wss://${apiBaseUrl.substring('https://'.length)}';
    }
    if (apiBaseUrl.startsWith('http://')) {
      return 'ws://${apiBaseUrl.substring('http://'.length)}';
    }
    return apiBaseUrl;
  }
}
