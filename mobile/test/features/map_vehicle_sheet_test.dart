import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/fleet_status.dart';
import 'package:mobile/features/map/widgets/map_vehicle_sheet.dart';
import 'package:mobile/state/map_markers_provider.dart';

import '../helpers/test_viewport.dart';

Device _device() => Device(
  id: 'd1',
  vehicleName: 'Camión 12',
  deviceCode: 'CODE-1',
  plate: 'PLT1',
  isActive: true,
  lastSeenAt: DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

TelemetryReading _reading() => TelemetryReading(
  id: 't1',
  deviceId: 'd1',
  latitude: 4.711,
  longitude: -74.0721,
  speed: 40,
  fuelLevel: 70,
  temperature: 20,
  recordedAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pump(WidgetTester tester, {required bool isExpanded}) async {
  pinPhoneViewport(tester);
  final marker = VehicleMarker(
    device: _device(),
    reading: _reading(),
    status: FleetStatus.active,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MapVehicleSheet(
          marker: marker,
          isExpanded: isExpanded,
          onToggle: () {},
          onDismiss: () {},
          onOpenDetail: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MAP-3: collapsed shows identity, state and the two metrics', (
    tester,
  ) async {
    await _pump(tester, isExpanded: false);

    expect(find.text('Camión 12'), findsOneWidget);
    expect(find.textContaining('PLT1'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('40 km/h'), findsOneWidget);
  });

  testWidgets('collapsed hides the details and the detail CTA', (tester) async {
    await _pump(tester, isExpanded: false);

    expect(find.text(AppStrings.mapViewDetailLabel), findsNothing);
    expect(find.text(AppStrings.mapLocationLabel), findsNothing);
  });

  testWidgets(
    'expanded adds last update, coordinates and the detail CTA',
    (tester) async {
      await _pump(tester, isExpanded: true);

      expect(find.text(AppStrings.vehicleLastUpdateLabel), findsOneWidget);
      expect(find.text(AppStrings.mapLocationLabel), findsOneWidget);
      // No reverse geocoding exists — the sheet shows the coordinates that
      // arrived, never a guessed place name.
      expect(
        find.text(AppStrings.mapCoordinatesLabel(4.711, -74.0721)),
        findsOneWidget,
      );
      expect(find.text(AppStrings.mapViewDetailLabel), findsOneWidget);
    },
  );

  testWidgets('MAP-3: the CTA reports the request to open the detail', (
    tester,
  ) async {
    var detailTaps = 0;
    pinPhoneViewport(tester);
    final marker = VehicleMarker(
      device: _device(),
      reading: _reading(),
      status: FleetStatus.active,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MapVehicleSheet(
            marker: marker,
            isExpanded: true,
            onToggle: () {},
            onDismiss: () {},
            onOpenDetail: () => detailTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.mapViewDetailLabel));
    await tester.pumpAndSettle();

    expect(detailTaps, 1);
  });
}
