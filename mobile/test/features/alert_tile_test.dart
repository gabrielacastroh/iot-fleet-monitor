import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/components/alert_tile.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/fleet_alert.dart';

FleetAlert _alert(String id, {String message = 'Combustible bajo'}) =>
    FleetAlert(
      id: id,
      deviceId: 'd1',
      alertType: AlertType.lowFuel,
      message: message,
      isResolved: false,
      createdAt: DateTime.utc(2026, 8, 1),
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets(
    'ALT-6: only the single amber/fuel tone renders, never a severity icon',
    (tester) async {
      for (final alert in [
        _alert('a1', message: 'Combustible bajo'),
        _alert('a2', message: 'Otra alerta distinta'),
      ]) {
        await _pump(tester, AlertTile(alert: alert));

        expect(find.text(alert.message), findsOneWidget);
        expect(find.byIcon(Icons.local_gas_station), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      }
    },
  );

  testWidgets('the resolve control is absent when onResolve is not given', (
    tester,
  ) async {
    await _pump(tester, AlertTile(alert: _alert('a1')));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('ALT-3: tapping resolve invokes onResolve', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      AlertTile(alert: _alert('a1'), onResolve: () => tapped = true),
    );

    await tester.tap(find.byType(IconButton));
    expect(tapped, isTrue);
  });

  testWidgets(
    'ALT-5: a non-null resolveDisabledReason disables the control and carries the reason as its semantics label',
    (tester) async {
      var tapped = false;
      await _pump(
        tester,
        AlertTile(
          alert: _alert('a1'),
          onResolve: () => tapped = true,
          resolveDisabledReason: AppStrings.resolveRequiresConnectionMessage,
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(tapped, isFalse);

      final semantics = tester.getSemantics(find.byType(IconButton));
      expect(
        semantics.label,
        contains(AppStrings.resolveRequiresConnectionMessage),
      );
    },
  );

  testWidgets('a resolved alert never shows the resolve control', (
    tester,
  ) async {
    final alert = _alert('a1').copyWith(isResolved: true);
    await _pump(tester, AlertTile(alert: alert, onResolve: () {}));

    expect(find.byType(IconButton), findsNothing);
  });
}
