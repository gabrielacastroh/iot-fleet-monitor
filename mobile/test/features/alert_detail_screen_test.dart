import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/features/alerts/alert_detail_screen.dart';
import 'package:mobile/router/routes.dart';
import 'package:mobile/design_system/components/app_button.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _OfflineConnectivityNotifier extends ConnectivityNotifier {
  @override
  bool build() => false;
}

class _MockAlertRepository extends Mock implements AlertRepository {}

class _MockAlertsApi extends Mock implements AlertsApi {}

FleetAlert _alert(String id, {String deviceId = 'd1'}) => FleetAlert(
  id: id,
  deviceId: deviceId,
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo $id',
  isResolved: false,
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<_MockAlertsApi> _pump(
  WidgetTester tester, {
  required Widget home,
  List<FleetAlert> openAlerts = const [],
}) async {
  pinPhoneViewport(tester);
  final repository = _MockAlertRepository();
  when(() => repository.peekCache()).thenReturn(null);
  when(() => repository.fetchAndCache()).thenAnswer((_) async => openAlerts);
  final api = _MockAlertsApi();
  when(
    () => api.getForDevice(any()),
  ).thenAnswer((_) async => const <FleetAlert>[]);
  when(
    () => api.getAll(limit: any(named: 'limit')),
  ).thenAnswer((_) async => const <FleetAlert>[]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertRepositoryProvider.overrideWith((ref) async => repository),
        alertsApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets(
    'ALT-2 step 1: renders directly from the passed alert (in-app nav)',
    (tester) async {
      final api = await _pump(
        tester,
        home: Scaffold(
          body: AlertDetailScreen(alertId: 'a1', alert: _alert('a1')),
        ),
      );

      expect(find.text('Combustible bajo a1'), findsOneWidget);
      verifyNever(() => api.getForDevice(any()));
      verifyNever(() => api.getAll(limit: any(named: 'limit')));
    },
  );

  testWidgets(
    'ALT-2 step 1b: resolves from the already-loaded alertsProvider cache',
    (tester) async {
      await _pump(
        tester,
        openAlerts: [_alert('a1')],
        home: const Scaffold(body: AlertDetailScreen(alertId: 'a1')),
      );

      expect(find.text('Combustible bajo a1'), findsOneWidget);
    },
  );

  testWidgets(
    'ALT-2 step 2: a deviceId query resolves via GET /alerts/{deviceId}',
    (tester) async {
      pinPhoneViewport(tester);
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(() => repository.fetchAndCache()).thenAnswer((_) async => []);
      final api = _MockAlertsApi();
      when(
        () => api.getForDevice('d1'),
      ).thenAnswer((_) async => [_alert('a1')]);
      when(
        () => api.getAll(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const <FleetAlert>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            alertsApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: AlertDetailScreen(alertId: 'a1', deviceId: 'd1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Combustible bajo a1'), findsOneWidget);
      verifyNever(() => api.getAll(limit: any(named: 'limit')));
    },
  );

  testWidgets(
    'ALT-2 step 3: no deviceId falls back to GET /alerts?limit=1000',
    (tester) async {
      pinPhoneViewport(tester);
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(() => repository.fetchAndCache()).thenAnswer((_) async => []);
      final api = _MockAlertsApi();
      when(
        () => api.getAll(limit: 1000),
      ).thenAnswer((_) async => [_alert('a2')]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            alertsApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AlertDetailScreen(alertId: 'a2')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Combustible bajo a2'), findsOneWidget);
    },
  );

  testWidgets(
    'ALT-5: offline renders a disabled control with the reason as its semantics label '
    '(unified with alerts_screen.dart\'s AlertTile pattern)',
    (tester) async {
      pinPhoneViewport(tester);
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(() => repository.fetchAndCache()).thenAnswer((_) async => []);
      final api = _MockAlertsApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            alertsApiProvider.overrideWithValue(api),
            connectivityProvider.overrideWith(_OfflineConnectivityNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: AlertDetailScreen(alertId: 'a1', alert: _alert('a1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.onPressed, isNull);

      final semantics = tester.getSemantics(find.byType(AppButton));
      expect(
        semantics.label,
        contains(AppStrings.resolveRequiresConnectionMessage),
      );
    },
  );

  testWidgets(
    'ALT-2 step 4: still not found shows the not-found state with a "Ver todas las alertas" action',
    (tester) async {
      await _pump(
        tester,
        home: const Scaffold(body: AlertDetailScreen(alertId: 'missing')),
      );

      expect(find.text(AppStrings.alertNotFoundTitle), findsOneWidget);
      expect(find.text(AppStrings.alertsViewAllLabel), findsOneWidget);
    },
  );

  testWidgets(
    'the "Ver todas las alertas" action navigates to the alerts list',
    (tester) async {
      pinPhoneViewport(tester);
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(() => repository.fetchAndCache()).thenAnswer((_) async => []);
      final api = _MockAlertsApi();
      when(
        () => api.getAll(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const <FleetAlert>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            alertsApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: Routes.alertDetail('missing'),
              routes: [
                GoRoute(
                  path: Routes.alertDetail(':alertId'),
                  builder: (context, state) => AlertDetailScreen(
                    alertId: state.pathParameters['alertId']!,
                  ),
                ),
                GoRoute(
                  path: Routes.alerts,
                  builder: (context, state) =>
                      const Scaffold(body: Text('alerts list')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.alertsViewAllLabel));
      await tester.pumpAndSettle();

      expect(find.text('alerts list'), findsOneWidget);
    },
  );
}
