import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/fleet_alert.dart';
import '../domain/models/session.dart';
import '../features/alerts/alert_detail_screen.dart';
import '../features/alerts/alerts_locked_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/vehicles/vehicle_detail_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../state/session_provider.dart';
import 'go_router_refresh.dart';
import 'routes.dart';

/// The auth redirect guard (design §7):
/// 1. `session` still resolving -> `null` (never flash `/login`; `app.dart`
///    overlays `BootstrapScreen` instead).
/// 2. Unauthenticated on a private route -> `/login?from=<location>`.
/// 3. Authenticated on `/login`/`/register` -> the `from` param, or
///    `/dashboard`.
/// 4. Otherwise -> `null` (stay put).
///
/// A pure function so the redirect matrix is unit-testable without
/// constructing a `GoRouter` or a `ProviderContainer`.
String? resolveRedirect({
  required AsyncValue<Session?> session,
  required String matchedLocation,
  required Uri uri,
}) {
  if (session.isLoading) return null;

  final isAuthenticated = session.valueOrNull != null;
  final onPublicRoute =
      matchedLocation == Routes.login || matchedLocation == Routes.register;

  if (!isAuthenticated && !onPublicRoute) {
    final from = Uri.encodeComponent(uri.toString());
    return '${Routes.login}?from=$from';
  }

  if (isAuthenticated && onPublicRoute) {
    final from = uri.queryParameters['from'];
    return (from != null && from.isNotEmpty) ? from : Routes.dashboard;
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = SessionRefreshListenable(ref);

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: refreshListenable,
    redirect: (context, state) => resolveRedirect(
      session: ref.read(sessionProvider),
      matchedLocation: state.matchedLocation,
      uri: state.uri,
    ),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vehicles,
                builder: (context, state) => const VehiclesScreen(),
                routes: [
                  GoRoute(
                    path: ':deviceId',
                    builder: (context, state) => VehicleDetailScreen(
                      deviceId: state.pathParameters['deviceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.alerts,
                builder: (context, state) =>
                    const _AdminGate(child: AlertsScreen()),
                routes: [
                  GoRoute(
                    path: ':alertId',
                    builder: (context, state) => _AdminGate(
                      child: AlertDetailScreen(
                        alertId: state.pathParameters['alertId']!,
                        deviceId: state.uri.queryParameters['deviceId'],
                        alert: state.extra as FleetAlert?,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// ROLE-2/ROLE-3: the admin gate for the `/alerts` branch is not a
/// redirect — [AlertsLockedScreen] renders in place so the destination
/// stays visible (design §7). Kept as a tiny router-local widget rather
/// than folding the check into `AlertsScreen`/`AlertDetailScreen`
/// themselves, since neither should need to know it might not be shown.
class _AdminGate extends ConsumerWidget {
  const _AdminGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return isAdmin ? child : const AlertsLockedScreen();
  }
}
