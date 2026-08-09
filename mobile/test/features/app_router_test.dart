import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/jwt_claims.dart';
import 'package:mobile/domain/models/app_user.dart';
import 'package:mobile/domain/models/session.dart';
import 'package:mobile/router/app_router.dart';
import 'package:mobile/router/routes.dart';

final _session = Session(
  token: 'x',
  user: AppUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@example.com',
    role: UserRole.user,
    isActive: true,
    createdAt: DateTime.utc(2026),
  ),
  claims: JwtClaims(subject: 'u1', role: 'user', expiresAt: DateTime.utc(2099)),
);

void main() {
  group('resolveRedirect', () {
    test('AUTH-7: session still loading never redirects (no /login flash)', () {
      final redirect = resolveRedirect(
        session: const AsyncValue<Session?>.loading(),
        matchedLocation: Routes.dashboard,
        uri: Uri.parse(Routes.dashboard),
      );

      expect(redirect, isNull);
    });

    test(
      'unauthenticated on a private route redirects to /login with `from`',
      () {
        final redirect = resolveRedirect(
          session: const AsyncValue<Session?>.data(null),
          matchedLocation: Routes.dashboard,
          uri: Uri.parse(Routes.dashboard),
        );

        expect(redirect, '${Routes.login}?from=%2Fdashboard');
      },
    );

    test('unauthenticated on /login is left alone', () {
      final redirect = resolveRedirect(
        session: const AsyncValue<Session?>.data(null),
        matchedLocation: Routes.login,
        uri: Uri.parse(Routes.login),
      );

      expect(redirect, isNull);
    });

    test(
      'authenticated on /login redirects to the `from` param when present',
      () {
        final redirect = resolveRedirect(
          session: AsyncValue<Session?>.data(_session),
          matchedLocation: Routes.login,
          uri: Uri.parse('${Routes.login}?from=%2Fvehicles'),
        );

        expect(redirect, '/vehicles');
      },
    );

    test('authenticated on /login with no `from` redirects to /dashboard', () {
      final redirect = resolveRedirect(
        session: AsyncValue<Session?>.data(_session),
        matchedLocation: Routes.login,
        uri: Uri.parse(Routes.login),
      );

      expect(redirect, Routes.dashboard);
    });

    test('authenticated on a private route is left alone', () {
      final redirect = resolveRedirect(
        session: AsyncValue<Session?>.data(_session),
        matchedLocation: Routes.dashboard,
        uri: Uri.parse(Routes.dashboard),
      );

      expect(redirect, isNull);
    });
  });
}
