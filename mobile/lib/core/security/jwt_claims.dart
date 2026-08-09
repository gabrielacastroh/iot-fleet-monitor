import 'dart:convert';

/// Payload-only decode of a JWT's `sub`/`exp`/`role` claims. The signature
/// is never verified client-side — that is the server's job on every
/// request; this only reads claims to drive local UX (proactive expiry
/// checks, role gating).
class JwtClaims {
  const JwtClaims({
    required this.subject,
    required this.expiresAt,
    required this.role,
  });

  final String subject;
  final DateTime expiresAt;
  final String role;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Returns null on any malformed token: wrong segment count, invalid
  /// base64url, invalid JSON, or a missing `exp` (an unverifiable
  /// expiration can't safely be treated as "never expires").
  static JwtClaims? parse(String token) {
    final segments = token.split('.');
    if (segments.length != 3) return null;

    try {
      final normalized = base64Url.normalize(segments[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map) return null;

      final sub = payload['sub'];
      final exp = payload['exp'];
      final role = payload['role'];
      if (sub is! String || exp is! int || role is! String) return null;

      return JwtClaims(
        subject: sub,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        role: role,
      );
    } catch (_) {
      return null;
    }
  }
}
