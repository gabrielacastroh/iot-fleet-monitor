import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';

void main() {
  group('AppConfig.resolve platform defaults', () {
    test('defaults to the Android emulator loopback alias on Android', () {
      final config = AppConfig.resolve(platform: TargetPlatform.android);

      expect(config.apiBaseUrl, 'http://10.0.2.2:8000');
    });

    test('defaults to localhost on non-Android platforms', () {
      final config = AppConfig.resolve(platform: TargetPlatform.iOS);

      expect(config.apiBaseUrl, 'http://localhost:8000');
    });

    test('derives wsBaseUrl from apiBaseUrl by swapping the scheme', () {
      final config = AppConfig.resolve(platform: TargetPlatform.android);

      expect(config.wsBaseUrl, 'ws://10.0.2.2:8000');
    });

    test('derives wss from an https apiBaseUrl override', () {
      final config = AppConfig.resolve(
        platform: TargetPlatform.iOS,
        apiBaseUrlOverride: 'https://api.example.com',
      );

      expect(config.wsBaseUrl, 'wss://api.example.com');
    });
  });

  group('AppConfig.resolve dart-define overrides', () {
    test('a non-empty apiBaseUrlOverride wins over the platform default', () {
      final config = AppConfig.resolve(
        platform: TargetPlatform.android,
        apiBaseUrlOverride: 'https://staging.example.com',
      );

      expect(config.apiBaseUrl, 'https://staging.example.com');
    });

    test('a non-empty wsBaseUrlOverride wins over the derived value', () {
      final config = AppConfig.resolve(
        platform: TargetPlatform.android,
        wsBaseUrlOverride: 'wss://staging.example.com',
      );

      expect(config.wsBaseUrl, 'wss://staging.example.com');
    });

    test(
      'an empty-string override is treated as absent (dart-define default)',
      () {
        final config = AppConfig.resolve(
          platform: TargetPlatform.android,
          apiBaseUrlOverride: '',
        );

        expect(config.apiBaseUrl, 'http://10.0.2.2:8000');
      },
    );
  });
}
