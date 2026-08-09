import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/components/status_badge.dart'
    show PulsingStatusDot, StatusBadge;
import 'package:mobile/design_system/status_tone.dart';
import 'package:mobile/domain/rules/fleet_status.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FleetStatus status, {
    bool socketOpen = false,
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: StatusBadge(status: status, socketOpen: socketOpen),
          ),
        ),
      ),
    );
  }

  // A11Y-5: color is never the sole channel — every state renders both the
  // icon and the Spanish label, never a bare dot.
  for (final status in FleetStatus.values) {
    testWidgets('$status renders its icon and label together', (tester) async {
      await pump(tester, status);

      final tone = statusToneOf(
        tester.element(find.byType(StatusBadge)),
        status,
      );
      expect(find.text(tone.label), findsOneWidget);
      expect(find.byIcon(tone.icon), findsOneWidget);
    });
  }

  testWidgets(
    'the dot only pulses for active + an open socket + animations enabled',
    (tester) async {
      await pump(tester, FleetStatus.active, socketOpen: true);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PulsingStatusDot), findsOneWidget);
    },
  );

  testWidgets('the dot does not pulse when the socket is closed', (
    tester,
  ) async {
    await pump(tester, FleetStatus.active, socketOpen: false);

    expect(find.byType(PulsingStatusDot), findsNothing);
  });

  testWidgets('the dot does not pulse for a non-active state', (tester) async {
    await pump(tester, FleetStatus.noSignal, socketOpen: true);

    expect(find.byType(PulsingStatusDot), findsNothing);
  });

  testWidgets('the dot does not pulse when animations are disabled', (
    tester,
  ) async {
    await pump(
      tester,
      FleetStatus.active,
      socketOpen: true,
      disableAnimations: true,
    );

    expect(find.byType(PulsingStatusDot), findsNothing);
  });
}
