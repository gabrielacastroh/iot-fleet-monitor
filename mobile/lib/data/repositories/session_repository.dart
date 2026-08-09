import '../../domain/models/app_user.dart';
import '../api/auth_api.dart';
import '../local/cache_entry.dart';
import '../local/fleet_cache.dart';

/// `POST /auth/login`, `POST /auth/register`, `GET /auth/me`, plus the
/// `session_user` cache. Caching the user is what makes role gating work
/// on a cold **offline** start (design §5.3) — without it a returning admin
/// would be treated as a non-admin.
class SessionRepository {
  SessionRepository(this._authApi);

  final AuthApi _authApi;

  Future<String> login({required String email, required String password}) =>
      _authApi.login(email: email, password: password);

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) => _authApi.register(name: name, email: email, password: password);

  Future<AppUser> fetchAndCacheCurrentUser(FleetCache fleetCache) async {
    final user = await _authApi.me();
    await fleetCache.write(
      FleetCache.sessionUserKey,
      CacheEntry(cachedAt: DateTime.now().toUtc(), payload: user.toJson()),
    );
    return user;
  }

  AppUser? cachedUser(FleetCache fleetCache) {
    final entry = fleetCache.read(FleetCache.sessionUserKey);
    if (entry == null) return null;
    return AppUser.fromJson(entry.payload as Map<String, dynamic>);
  }
}
