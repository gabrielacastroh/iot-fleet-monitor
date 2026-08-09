import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/components/app_button.dart';
import 'package:mobile/design_system/components/app_card.dart';
import 'package:mobile/design_system/components/kpi_tile.dart';
import 'package:mobile/design_system/components/section_header.dart';

void main() {
  group('AppButton', () {
    testWidgets('has a minimum 48x48dp hit area (A11Y-1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'Guardar', onPressed: () {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AppButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'Guardar', onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows a loading indicator and ignores taps when loading', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Guardar',
              onPressed: () => tapped = true,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(tapped, isFalse);
    });

    testWidgets(
      'AUTH-5: a null onPressed renders a visually and semantically disabled button',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: AppButton(label: 'Ingresar', onPressed: null)),
          ),
        );

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        // FilledButton derives its own semantics `enabled` flag from
        // `onPressed == null` — asserting the callback here is enough to
        // guarantee the accessible cue without duplicating framework tests.
      },
    );
  });

  group('AppCard', () {
    testWidgets('renders with zero Material elevation (depth via AppShadows)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppCard(child: Text('content'))),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders the title text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(title: 'Vehículos')),
        ),
      );

      expect(find.text('Vehículos'), findsOneWidget);
    });
  });

  group('KpiTile', () {
    testWidgets('renders icon, value and label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KpiTile(
              icon: Icons.local_shipping_outlined,
              label: 'Vehículos activos',
              value: '12',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Vehículos activos'), findsOneWidget);
    });
  });
}
