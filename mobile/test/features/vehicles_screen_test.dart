import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/features/vehicles/vehicles_screen.dart';
import 'package:mobile/router/routes.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

// Mocked at the repository layer (design §5.2's CachedSource contract)
// rather than through a real Hive box: real Hive I/O deadlocks under
// `testWidgets` in this Flutter/Hive combo (works fine under a plain
// `test()`, as every repository test in test/data/ already relies on) —
// see the apply-progress note for slice 3. Mocking here is also simply
// the right layer for a screen test: DevicesNotifier/CacheBackedNotifier
// already have their own coverage in devices_provider_test.dart.
class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

Device _device(
  String id,
  String name, {
  bool isActive = true,
  DateTime? lastSeenAt,
}) => Device(
  id: id,
  vehicleName: name,
  deviceCode: 'CODE-$id',
  plate: 'PLT$id',
  isActive: isActive,
  lastSeenAt: lastSeenAt ?? DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

TelemetryReading _reading(
  String deviceId, {
  double speed = 40,
  double fuelLevel = 80,
}) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 0,
  longitude: 0,
  speed: speed,
  fuelLevel: fuelLevel,
  temperature: 20,
  recordedAt: DateTime.utc(2026, 8, 1),
);

Future<_MockDeviceRepository> _pumpVehiclesScreen(
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: VehiclesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return deviceRepo;
}

void main() {
  testWidgets(
    'VEH-1: devices without a matching reading still render, with no data shown',
    (tester) async {
      await _pumpVehiclesScreen(
        tester,
        devices: [
          _device('d1', 'Camión 12'),
          _device('d2', 'Camión 13'),
          _device('d3', 'Camión 14'),
        ],
        readings: [_reading('d1'), _reading('d2')],
      );

      expect(find.text('Camión 12'), findsOneWidget);
      expect(find.text('Camión 13'), findsOneWidget);
      expect(find.text('Camión 14'), findsOneWidget);
    },
  );

  testWidgets('VEH-2: a case-insensitive substring match filters the list', (
    tester,
  ) async {
    await _pumpVehiclesScreen(
      tester,
      devices: [_device('d1', 'Camión 12'), _device('d2', 'Grúa 5')],
      readings: [],
    );

    await tester.enterText(find.byType(TextField), 'camion');
    await tester.pumpAndSettle();

    expect(find.text('Camión 12'), findsOneWidget);
    expect(find.text('Grúa 5'), findsNothing);
  });

  testWidgets('VEH-3: the Crítico tab isolates only critical-state devices', (
    tester,
  ) async {
    await _pumpVehiclesScreen(
      tester,
      devices: [
        _device('d1', 'Camión Crítico'),
        _device('d2', 'Camión Normal'),
      ],
      readings: [
        _reading('d1', fuelLevel: 5), // <=10 -> critical overlay
        _reading('d2', fuelLevel: 90),
      ],
    );

    // At phone width the scrolling chip strip may need scrolling before
    // 'Crítico' (the last chip) is actually tappable on-screen. Found by
    // key, not by label: a critical vehicle's status pill renders the same
    // word, so `find.text('Crítico')` is ambiguous here.
    final criticalChip = find.byKey(
      const ValueKey('vehicle_filter_chip_critical'),
    );
    await tester.ensureVisible(criticalChip);
    await tester.pumpAndSettle();
    await tester.tap(criticalChip);
    await tester.pumpAndSettle();

    expect(find.text('Camión Crítico'), findsOneWidget);
    expect(find.text('Camión Normal'), findsNothing);
  });

  testWidgets('VEH-6a: an empty fleet shows the empty-fleet copy', (
    tester,
  ) async {
    await _pumpVehiclesScreen(tester, devices: [], readings: []);

    expect(find.text(AppStrings.vehiclesEmptyFleetTitle), findsOneWidget);
    expect(find.text(AppStrings.vehiclesClearFiltersLabel), findsNothing);
  });

  testWidgets(
    'VEH-6b: a search with no matches shows the no-matches copy and a clear-filters action',
    (tester) async {
      await _pumpVehiclesScreen(
        tester,
        devices: [_device('d1', 'Camión 12')],
        readings: [],
      );

      await tester.enterText(find.byType(TextField), 'no-such-vehicle');
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.vehiclesNoMatchesTitle), findsOneWidget);
      expect(find.text(AppStrings.vehiclesClearFiltersLabel), findsOneWidget);

      await tester.tap(find.text(AppStrings.vehiclesClearFiltersLabel));
      await tester.pumpAndSettle();

      expect(find.text('Camión 12'), findsOneWidget);
    },
  );

  testWidgets('VEH-7: a single device renders without a layout break', (
    tester,
  ) async {
    await _pumpVehiclesScreen(
      tester,
      devices: [_device('d1', 'Camión Único')],
      readings: [_reading('d1')],
    );

    expect(find.text('Camión Único'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'VEH-8: a 500-device fleet renders lazily via exactly one fetch call',
    (tester) async {
      final devices = [
        for (var i = 0; i < 500; i++) _device('d$i', 'Camión $i'),
      ];
      final deviceRepo = await _pumpVehiclesScreen(
        tester,
        devices: devices,
        readings: [],
      );

      expect(find.byType(ListView), findsOneWidget);
      verify(() => deviceRepo.fetchAndCache()).called(1);
    },
  );

  testWidgets('tapping a vehicle card pushes its detail route', (tester) async {
    pinPhoneViewport(tester);
    final deviceRepo = _MockDeviceRepository();
    final telemetryRepo = _MockTelemetryRepository();
    when(() => deviceRepo.peekCache()).thenReturn(null);
    when(
      () => deviceRepo.fetchAndCache(),
    ).thenAnswer((_) async => [_device('d1', 'Camión 12')]);
    when(() => telemetryRepo.peekCache()).thenReturn(null);
    when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
          telemetryRepositoryProvider.overrideWith(
            (ref) async => telemetryRepo,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: Routes.vehicles,
            routes: [
              GoRoute(
                path: Routes.vehicles,
                builder: (context, state) =>
                    const Scaffold(body: VehiclesScreen()),
              ),
              GoRoute(
                path: Routes.vehicleDetail(':deviceId'),
                builder: (context, state) =>
                    const Scaffold(body: Text('vehicle detail')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camión 12'));
    await tester.pumpAndSettle();

    expect(find.text('vehicle detail'), findsOneWidget);
  });
}
