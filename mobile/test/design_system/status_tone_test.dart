import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/status_tone.dart';
import 'package:mobile/design_system/tokens/app_colors.dart';
import 'package:mobile/domain/rules/fleet_status.dart';

void main() {
  Future<StatusTone> toneFor(WidgetTester tester, FleetStatus status) async {
    late StatusTone tone;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            tone = statusToneOf(context, status);
            return const SizedBox();
          },
        ),
      ),
    );
    return tone;
  }

  // The pinned mapping table, design §2.2 — every FleetStatus maps to the
  // exact Spanish label, icon and color from the table.
  testWidgets('active maps to Activo / success / check_circle_outline', (
    tester,
  ) async {
    final tone = await toneFor(tester, FleetStatus.active);

    expect(tone.label, 'Activo');
    expect(tone.icon, Icons.check_circle_outline);
    expect(tone.dot, AppColors.light.success);
    expect(tone.softText, AppColors.light.onSuccessSoft);
    expect(tone.softSurface, AppColors.light.successSoft);
  });

  testWidgets('inactive maps to Inactivo / neutral / power_settings_new', (
    tester,
  ) async {
    final tone = await toneFor(tester, FleetStatus.inactive);

    expect(tone.label, 'Inactivo');
    expect(tone.icon, Icons.power_settings_new);
    expect(tone.dot, AppColors.mutedForeground);
    expect(tone.softText, AppColors.mutedForeground);
    expect(tone.softSurface, AppColors.secondary);
  });

  testWidgets('noSignal maps to Sin señal / warning / signal_cellular_off', (
    tester,
  ) async {
    final tone = await toneFor(tester, FleetStatus.noSignal);

    expect(tone.label, 'Sin señal');
    expect(tone.icon, Icons.signal_cellular_off);
    expect(tone.dot, AppColors.light.warning);
    expect(tone.softText, AppColors.light.onWarningSoft);
    expect(tone.softSurface, AppColors.light.warningSoft);
  });

  testWidgets('alert maps to Alerta / warning / warning_amber_rounded', (
    tester,
  ) async {
    final tone = await toneFor(tester, FleetStatus.alert);

    expect(tone.label, 'Alerta');
    expect(tone.icon, Icons.warning_amber_rounded);
    expect(tone.dot, AppColors.light.warning);
    expect(tone.softText, AppColors.light.onWarningSoft);
    expect(tone.softSurface, AppColors.light.warningSoft);
  });

  testWidgets('critical maps to Crítico / danger / error_outline', (
    tester,
  ) async {
    final tone = await toneFor(tester, FleetStatus.critical);

    expect(tone.label, 'Crítico');
    expect(tone.icon, Icons.error_outline);
    expect(tone.dot, AppColors.destructive);
    expect(tone.softText, AppColors.light.onDestructiveSoft);
    expect(tone.softSurface, AppColors.destructiveSoft);
  });
}
