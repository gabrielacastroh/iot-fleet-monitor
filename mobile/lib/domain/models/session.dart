import '../../core/security/jwt_claims.dart';
import 'app_user.dart';

/// The in-memory shape of an authenticated session: the raw token (for the
/// WebSocket URL), the cached user (for role gating and profile), and the
/// decoded claims (for the proactive expiry check).
class Session {
  const Session({
    required this.token,
    required this.user,
    required this.claims,
  });

  final String token;
  final AppUser user;
  final JwtClaims claims;
}
