import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/features/vehicles/widgets/active_alerts_section.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockAlertsApi extends Mock implements AlertsApi {}

FleetAlert _alert(String id, {bool isResolved = false}) => FleetAlert(
  id: id,
  deviceId: 'd1',
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo $id',
  isResolved: isResolved,
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<_MockAlertsApi> _pump(
  WidgetTester tester, {
  List<FleetAlert> alerts = const [],
}) async {
  pinPhoneViewport(tester);
  final api = _MockAlertsApi();
  when(() => api.getForDevice(any())).thenAnswer((_) async => alerts);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [alertsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: const [ActiveAlertsSection(deviceId: 'd1')],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('VDET-4: the device request fires and open alerts render', (
    tester,
  ) async {
    final api = await _pump(tester, alerts: [_alert('a1')]);

    expect(find.text(AppStrings.activeAlertsSectionTitle), findsOneWidget);
    expect(find.text('Combustible bajo a1'), findsOneWidget);
    expect(find.text(AppStrings.alertsViewAllCountLabel(1)), findsOneWidget);
    verify(() => api.getForDevice('d1')).called(1);
  });

  testWidgets('resolved alerts are not "active" and never reach the section', (
    tester,
  ) async {
    await _pump(
      tester,
      alerts: [_alert('a1', isResolved: true), _alert('a2')],
    );

    expect(find.text('Combustible bajo a1'), findsNothing);
    expect(find.text('Combustible bajo a2'), findsOneWidget);
    expect(find.text(AppStrings.alertsViewAllCountLabel(1)), findsOneWidget);
  });

  testWidgets('at most three alerts render, however many are open', (
    tester,
  ) async {
    await _pump(
      tester,
      alerts: [_alert('a1'), _alert('a2'), _alert('a3'), _alert('a4')],
    );

    expect(find.text('Combustible bajo a4'), findsNothing);
    expect(find.text(AppStrings.alertsViewAllCountLabel(4)), findsOneWidget);
  });

  testWidgets('no open alerts shows the all-clear copy, not an empty section', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(AppStrings.vehicleAlertsEmptyBody), findsOneWidget);
    expect(find.text(AppStrings.alertsViewAllCountLabel(0)), findsNothing);
  });
}
