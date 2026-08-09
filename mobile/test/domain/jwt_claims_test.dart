import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/jwt_claims.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(payload);
  return '$header.$body.fake-signature';
}

void main() {
  group('JwtClaims.parse', () {
    test('decodes sub/exp/role from a valid payload', () {
      final exp = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final token = _fakeJwt({'sub': 'user-1', 'exp': exp, 'role': 'admin'});

      final claims = JwtClaims.parse(token);

      expect(claims, isNotNull);
      expect(claims!.subject, 'user-1');
      expect(claims.role, 'admin');
      expect(
        claims.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      );
    });

    test('an already-expired exp is still parsed; isExpired reports it', () {
      final pastExp = DateTime.utc(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final token = _fakeJwt({'sub': 'user-1', 'exp': pastExp, 'role': 'user'});

      final claims = JwtClaims.parse(token)!;

      expect(claims.isExpired, isTrue);
    });

    test(
      'missing exp returns null claims (cannot safely assume never-expiring)',
      () {
        final token = _fakeJwt({'sub': 'user-1', 'role': 'user'});

        expect(JwtClaims.parse(token), isNull);
      },
    );

    test('malformed base64 in the payload segment returns null', () {
      const token = 'header.not-valid-base64!!!.sig';

      expect(JwtClaims.parse(token), isNull);
    });

    test('wrong segment count returns null', () {
      const token = 'only-one-segment';

      expect(JwtClaims.parse(token), isNull);
    });
  });
}
