import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/jwt_claims.dart';
import '../data/local/fleet_cache.dart';
import 'api_providers.dart';

/// Opens the encrypted box for whichever user's token is currently in
/// secure storage — `null` when there is none (no session, or a malformed
/// token). Invalidated (and re-read) after login writes a fresh token, and
/// on logout.
final fleetCacheProvider = FutureProvider<FleetCache?>((ref) async {
  final secureStore = ref.watch(secureStoreProvider);
  final token = await secureStore.readToken();
  if (token == null) return null;

  final claims = JwtClaims.parse(token);
  if (claims == null) return null;

  return FleetCache.open(userId: claims.subject, secureStore: secureStore);
});
