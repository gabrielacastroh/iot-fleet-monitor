import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/redact.dart';

void main() {
  group('redactSensitive', () {
    test('redacts a bearer token from an Authorization header line', () {
      const input = 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig';

      final output = redactSensitive(input);

      expect(output, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(output, contains('[REDACTED]'));
    });

    test('redacts a password field value', () {
      const input = '{"username":"a@b.com","password":"supersecret"}';

      final output = redactSensitive(input);

      expect(output, isNot(contains('supersecret')));
    });

    test('redacts the token query param from a WebSocket URL', () {
      const input =
          'ws://localhost:8000/ws/telemetry?token=eyJhbGciOiJIUzI1NiJ9.abc.def';

      final output = redactSensitive(input);

      expect(output, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(output, contains('token=[REDACTED]'));
    });
  });
}
