import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/derived_alerts.dart';
import 'package:mobile/features/vehicles/widgets/vehicle_hero_card.dart';

import '../helpers/test_viewport.dart';

Device _device({DateTime? lastSeenAt}) => Device(
  id: 'd1',
  vehicleName: 'Camión 12',
  deviceCode: 'CODE-1',
  plate: 'PLT1',
  isActive: true,
  lastSeenAt: lastSeenAt,
  createdAt: DateTime.utc(2026, 8, 1),
);

TelemetryReading _reading() => TelemetryReading(
  id: 't1',
  deviceId: 'd1',
  latitude: 0,
  longitude: 0,
  speed: 55,
  fuelLevel: 40,
  temperature: 22,
  recordedAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required Device device,
  TelemetryReading? reading,
}) async {
  pinPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: VehicleHeroCard(
          device: device,
          status: fleetOverlayStatus(device, reading),
          reading: reading,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('VDET-2: the latest reading fills the four metric tiles', (
    tester,
  ) async {
    await _pump(
      tester,
      device: _device(lastSeenAt: DateTime.utc(2026, 8, 1)),
      reading: _reading(),
    );

    expect(find.text(AppStrings.vehicleLastUpdateLabel), findsOneWidget);
    expect(find.text(AppStrings.vehiclesFuelLabel), findsOneWidget);
    expect(find.text(AppStrings.vehiclesSpeedLabel), findsOneWidget);
    expect(find.text(AppStrings.vehicleTemperatureLabel), findsOneWidget);
    expect(find.text(AppStrings.vehicleSinceLastSignalLabel), findsOneWidget);
    expect(find.textContaining('40'), findsWidgets);
    expect(find.textContaining('55'), findsWidgets);
    expect(find.textContaining('22'), findsWidgets);
  });

  testWidgets('a reporting device with no reading yet shows em dashes, not zeros', (
    tester,
  ) async {
    await _pump(tester, device: _device(lastSeenAt: DateTime.utc(2026, 8, 1)));

    expect(find.text(AppStrings.kpiNoDataValue), findsNWidgets(3));
    expect(find.text(AppStrings.neverReportedMessage), findsNothing);
  });

  testWidgets(
    'VDET-7: a never-reported device shows dedicated copy, distinct from VDET-6',
    (tester) async {
      await _pump(tester, device: _device(lastSeenAt: null));

      expect(find.text(AppStrings.neverReportedMessage), findsOneWidget);
      expect(find.text(AppStrings.noReadingsInRangeMessage), findsNothing);
      expect(find.text(AppStrings.vehiclesFuelLabel), findsNothing);
    },
  );
}
