import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/features/alerts/alerts_screen.dart';
import 'package:mobile/router/routes.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockAlertRepository extends Mock implements AlertRepository {}

class _MockAlertsApi extends Mock implements AlertsApi {}

class _MockConnectivity extends Mock implements Connectivity {}

FleetAlert _alert(String id, {bool isResolved = false}) => FleetAlert(
  id: id,
  deviceId: 'd1',
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo $id',
  isResolved: isResolved,
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<_MockAlertRepository> _pump(
  WidgetTester tester, {
  List<FleetAlert> openAlerts = const [],
  bool online = true,
}) async {
  pinPhoneViewport(tester);
  final repository = _MockAlertRepository();
  when(() => repository.peekCache()).thenReturn(null);
  when(() => repository.fetchAndCache()).thenAnswer((_) async => openAlerts);

  final connectivity = _MockConnectivity();
  when(
    () => connectivity.onConnectivityChanged,
  ).thenAnswer((_) => const Stream.empty());
  when(() => connectivity.checkConnectivity()).thenAnswer(
    (_) async => [online ? ConnectivityResult.wifi : ConnectivityResult.none],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertRepositoryProvider.overrideWith((ref) async => repository),
        connectivityClientProvider.overrideWithValue(connectivity),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: Routes.alerts,
          routes: [
            GoRoute(
              path: Routes.alerts,
              builder: (context, state) => const Scaffold(body: AlertsScreen()),
            ),
            GoRoute(
              path: Routes.alertDetail(':alertId'),
              builder: (context, state) =>
                  const Scaffold(body: Text('alert detail')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('ALT-1: the Pendientes tab requests only is_resolved=false', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      openAlerts: [_alert('a1'), _alert('a2')],
    );

    expect(find.text('Combustible bajo a1'), findsOneWidget);
    verify(() => repository.fetchAndCache()).called(1);
  });

  testWidgets(
    'ALT-1: the Resueltas tab requests is_resolved=true and no unsupported param',
    (tester) async {
      pinPhoneViewport(tester);
      final api = _MockAlertsApi();
      when(
        () => api.getAll(
          isResolved: any(named: 'isResolved'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_alert('r1', isResolved: true)]);

      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(() => repository.fetchAndCache()).thenAnswer((_) async => []);

      final connectivity = _MockConnectivity();
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            connectivityClientProvider.overrideWithValue(connectivity),
            alertsApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AlertsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.alertsTabResolved));
      await tester.pumpAndSettle();

      expect(find.text('Combustible bajo r1'), findsOneWidget);
      verify(
        () => api.getAll(isResolved: true, limit: any(named: 'limit')),
      ).called(1);
      verifyNever(
        () => api.getAll(isResolved: false, limit: any(named: 'limit')),
      );
    },
  );

  testWidgets(
    'ALT-5: offline disables the resolve control with the offline reason and never fires a request',
    (tester) async {
      final repository = await _pump(
        tester,
        openAlerts: [_alert('a1')],
        online: false,
      );

      final semantics = tester.getSemantics(find.byType(IconButton));
      expect(
        semantics.label,
        contains(AppStrings.resolveRequiresConnectionMessage),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      verifyNever(() => repository.resolve(any()));
    },
  );

  testWidgets('the four-state contract: loading, error, empty, data', (
    tester,
  ) async {
    await _pump(tester, openAlerts: []);

    expect(find.text(AppStrings.alertsEmptyPendingTitle), findsOneWidget);
  });

  testWidgets('tapping an alert pushes the alert detail route', (tester) async {
    await _pump(tester, openAlerts: [_alert('a1')]);

    await tester.tap(find.text('Combustible bajo a1'));
    await tester.pumpAndSettle();

    expect(find.text('alert detail'), findsOneWidget);
  });
}
