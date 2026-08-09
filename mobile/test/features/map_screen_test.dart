import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/features/map/map_screen.dart';
import 'package:mobile/features/map/widgets/map_vehicle_sheet.dart';
import 'package:mobile/features/map/widgets/vehicle_marker.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/telemetry_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

Device _device(String id) => Device(
  id: id,
  vehicleName: 'V$id',
  deviceCode: 'C$id',
  plate: 'P$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

TelemetryReading _reading(String deviceId, {double lat = 1, double lng = 1}) =>
    TelemetryReading(
      id: 't-$deviceId',
      deviceId: deviceId,
      latitude: lat,
      longitude: lng,
      speed: 10,
      fuelLevel: 80,
      temperature: 20,
      recordedAt: DateTime.utc(2026, 8, 1),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<Device> devices,
  required List<TelemetryReading> readings,
}) async {
  pinPhoneViewport(tester);
  final deviceRepo = _MockDeviceRepository();
  final telemetryRepo = _MockTelemetryRepository();
  when(() => deviceRepo.peekCache()).thenReturn(null);
  when(() => deviceRepo.fetchAndCache()).thenAnswer((_) async => devices);
  when(() => telemetryRepo.peekCache()).thenReturn(null);
  when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => readings);

  final container = ProviderContainer(
    overrides: [
      deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
      telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: MapScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('MAP-2: zero devices with a reading shows the empty state', (
    tester,
  ) async {
    await _pump(tester, devices: [_device('d1')], readings: const []);

    expect(find.text(AppStrings.mapEmptyTitle), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('MAP-1: renders one marker per device with a reading', (
    tester,
  ) async {
    await _pump(
      tester,
      devices: [_device('d1'), _device('d2')],
      readings: [_reading('d1')],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(VehicleMarkerIcon), findsOneWidget);
  });

  testWidgets(
    'a telemetry_updated-style upsert live-patches the marker set (WS-6)',
    (tester) async {
      final container = await _pump(
        tester,
        devices: [_device('d1'), _device('d2')],
        readings: [_reading('d1')],
      );

      expect(find.byType(VehicleMarkerIcon), findsOneWidget);

      // A small offset from d1's default (1,1): far enough to land in a
      // different cluster cell (coincident points are covered by the
      // clustering test below) but close enough to stay inside the
      // initial viewport at the default zoom, where MarkerLayer actually
      // renders it.
      container
          .read(latestTelemetryProvider.notifier)
          .upsert(_reading('d2', lat: 1.05, lng: 1.05));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleMarkerIcon), findsNWidgets(2));
    },
  );

  testWidgets(
    'vehicles at (near-)coincident positions render as a single cluster '
    'badge instead of overlapping markers',
    (tester) async {
      await _pump(
        tester,
        devices: [_device('d1'), _device('d2')],
        readings: [_reading('d1'), _reading('d2')], // both default to (1, 1)
      );

      expect(find.byType(VehicleMarkerIcon), findsNothing);
      expect(find.byType(VehicleClusterMarker), findsOneWidget);
      expect(
        // Not `find.text('2')` alone: the "Activos 2" filter chip carries
        // the same digit over the map.
        find.descendant(
          of: find.byType(VehicleClusterMarker),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('MAP-4: the search narrows the markers to the matching vehicle', (
    tester,
  ) async {
    await _pump(
      tester,
      devices: [_device('d1'), _device('d2')],
      readings: [_reading('d1'), _reading('d2', lat: 1.05, lng: 1.05)],
    );

    expect(find.byType(VehicleMarkerIcon), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'Pd1');
    await tester.pumpAndSettle();

    expect(find.byType(VehicleMarkerIcon), findsOneWidget);
  });

  testWidgets(
    'MAP-4: a status chip with no matches empties the map, not the screen',
    (tester) async {
      await _pump(tester, devices: [_device('d1')], readings: [_reading('d1')]);

      // The chip strip scrolls: four status chips are wider than a phone.
      final chip = find.byKey(const ValueKey('map_filter_chip_noSignal'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(VehicleMarkerIcon), findsNothing);
      expect(find.text(AppStrings.vehiclesNoMatchesTitle), findsOneWidget);
    },
  );

  testWidgets('MAP-3: tapping a marker opens the sheet over the map', (
    tester,
  ) async {
    await _pump(tester, devices: [_device('d1')], readings: [_reading('d1')]);

    expect(find.byType(MapVehicleSheet), findsNothing);

    await tester.tap(find.byType(VehicleMarkerIcon));
    await tester.pumpAndSettle();

    // Not a modal: the map is still mounted and visible under the sheet.
    expect(find.byType(MapVehicleSheet), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text(AppStrings.mapViewDetailLabel), findsOneWidget);
  });

  testWidgets(
    'MAP-4: narrowing the search to one vehicle opens its sheet',
    (tester) async {
      await _pump(
        tester,
        devices: [_device('d1'), _device('d2')],
        readings: [_reading('d1'), _reading('d2', lat: 1.05, lng: 1.05)],
      );

      expect(find.byType(MapVehicleSheet), findsNothing);

      // Two matches: still ambiguous, so the map stays put.
      await tester.enterText(find.byType(TextField), 'P');
      await tester.pumpAndSettle();
      expect(find.byType(MapVehicleSheet), findsNothing);

      await tester.enterText(find.byType(TextField), 'Pd2');
      await tester.pumpAndSettle();

      expect(find.byType(MapVehicleSheet), findsOneWidget);
      expect(find.text('Vd2'), findsOneWidget);
      // Collapsed: the keyboard is still up while the query is being typed.
      expect(find.text(AppStrings.mapViewDetailLabel), findsNothing);
    },
  );

  testWidgets('the sheet drops when its vehicle is filtered out', (
    tester,
  ) async {
    await _pump(tester, devices: [_device('d1')], readings: [_reading('d1')]);

    await tester.tap(find.byType(VehicleMarkerIcon));
    await tester.pumpAndSettle();
    expect(find.byType(MapVehicleSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pumpAndSettle();

    expect(find.byType(MapVehicleSheet), findsNothing);
  });
}
