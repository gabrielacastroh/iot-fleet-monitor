import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/components/app_empty_state.dart';
import 'package:mobile/design_system/components/metric_chart.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';

TelemetryReading _reading(double speed) => TelemetryReading(
  id: 't-$speed',
  deviceId: 'd1',
  latitude: 0,
  longitude: 0,
  speed: speed,
  fuelLevel: 50,
  temperature: 20,
  recordedAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pump(WidgetTester tester, List<TelemetryReading> readings) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MetricChart(
          title: AppStrings.chartSpeedTitle,
          readings: readings,
          valueOf: (r) => r.speed,
          unit: ' km/h',
          color: Colors.blue,
          icon: Icons.speed_outlined,
          tintSurface: Colors.blue.withValues(alpha: 0.1),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a line chart with a series point per reading', (
    tester,
  ) async {
    await _pump(tester, [_reading(10), _reading(20), _reading(30)]);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots, hasLength(3));
    expect(find.text(AppStrings.chartSpeedTitle), findsOneWidget);
  });

  testWidgets(
    'VDET-6 precondition: an empty history shows an explicit empty state',
    (tester) async {
      await _pump(tester, const []);

      expect(find.byType(LineChart), findsNothing);
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text(AppStrings.noReadingsInRangeMessage), findsOneWidget);
    },
  );
}
