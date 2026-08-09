import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';

class _FakeLiveFeedNotifier extends LiveFeedNotifier {
  _FakeLiveFeedNotifier(this._readings);

  final List<TelemetryReading> _readings;

  @override
  Future<List<TelemetryReading>> build() async => _readings;
}

// Mocked at the repository layer (see `vehicles_screen_test.dart`'s note —
// real Hive deadlocks under `testWidgets` in this Flutter/Hive combo).
class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

class _MockAlertRepository extends Mock implements AlertRepository {}

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
  double temperature = 20,
}) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 0,
  longitude: 0,
  speed: speed,
  fuelLevel: fuelLevel,
  temperature: temperature,
  recordedAt: DateTime.utc(2026, 8, 1),
);

FleetAlert _alert(String id, String deviceId) => FleetAlert(
  id: id,
  deviceId: deviceId,
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo',
  isResolved: false,
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<Device> devices,
  required List<TelemetryReading> readings,
  List<FleetAlert> alerts = const [],
  bool isAdmin = false,
  List<TelemetryReading> liveFeed = const [],
}) async {
  final deviceRepo = _MockDeviceRepository();
  final telemetryRepo = _MockTelemetryRepository();
  final alertRepo = _MockAlertRepository();
  when(() => deviceRepo.peekCache()).thenReturn(null);
  when(() => deviceRepo.fetchAndCache()).thenAnswer((_) async => devices);
  when(() => telemetryRepo.peekCache()).thenReturn(null);
  when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => readings);
  when(() => alertRepo.peekCache()).thenReturn(null);
  when(() => alertRepo.fetchAndCache()).thenAnswer((_) async => alerts);

  // The dashboard's content can exceed the default test viewport height;
  // `ListView` (even with a plain children list) only builds elements
  // within the viewport, so a short viewport would silently omit
  // below-the-fold content from `find`. A tall viewport avoids scrolling
  // gymnastics in every test below.
  tester.view.physicalSize = const Size(400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
        alertRepositoryProvider.overrideWith((ref) async => alertRepo),
        isAdminProvider.overrideWithValue(isAdmin),
        liveFeedProvider.overrideWith(() => _FakeLiveFeedNotifier(liveFeed)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DashboardScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('DASH-2: an empty fleet shows the empty-fleet state', (
    tester,
  ) async {
    await _pumpDashboard(tester, devices: [], readings: []);

    expect(find.text(AppStrings.dashboardEmptyFleetTitle), findsOneWidget);
  });

  testWidgets('DASH-1: KPI tiles reflect the fleet aggregate', (tester) async {
    await _pumpDashboard(
      tester,
      devices: [_device('d1', 'Camión 12'), _device('d2', 'Camión 13')],
      readings: [_reading('d1', fuelLevel: 60, temperature: 20)],
    );

    expect(find.text('2'), findsOneWidget); // activeCount (both active)
    expect(find.text('60%'), findsOneWidget); // averageFuelLevel
    expect(find.text('20°C'), findsOneWidget); // averageTemperature
  });

  testWidgets(
    'a vehicle in alert/critical overlay state shows in "Vehículos con problemas"',
    (tester) async {
      await _pumpDashboard(
        tester,
        devices: [_device('d1', 'Camión Crítico'), _device('d2', 'Camión OK')],
        readings: [
          _reading('d1', fuelLevel: 5), // <=10 -> critical overlay
          _reading('d2', fuelLevel: 90),
        ],
      );

      expect(find.text(AppStrings.problemVehiclesSectionTitle), findsOneWidget);
      expect(find.text('Camión Crítico'), findsOneWidget);
      expect(find.text('Camión OK'), findsNothing);
    },
  );

  testWidgets(
    'no problem vehicles: the "Vehículos con problemas" section is omitted',
    (tester) async {
      await _pumpDashboard(
        tester,
        devices: [_device('d1', 'Camión OK')],
        readings: [_reading('d1', fuelLevel: 90)],
      );

      expect(find.text(AppStrings.problemVehiclesSectionTitle), findsNothing);
    },
  );

  testWidgets('ROLE-2: a non-admin session never shows the open-alerts card', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      devices: [_device('d1', 'Camión 12')],
      readings: [],
      isAdmin: false,
    );

    expect(find.text(AppStrings.openAlertsSectionTitle), findsNothing);
  });

  testWidgets('ROLE-3: an admin session shows the open-alerts card', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      devices: [_device('d1', 'Camión 12')],
      readings: [],
      alerts: [_alert('a1', 'd1')],
      isAdmin: true,
    );

    expect(find.text(AppStrings.openAlertsSectionTitle), findsOneWidget);
    expect(find.text('Combustible bajo'), findsOneWidget);
  });

  testWidgets('fleet metrics charts render when the live feed has data', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      devices: [_device('d1', 'Camión 12')],
      readings: [],
      liveFeed: [_reading('d1', speed: 50), _reading('d1', speed: 60)],
    );

    expect(find.text(AppStrings.chartSpeedTitle), findsOneWidget);
    expect(find.text(AppStrings.chartFuelTitle), findsOneWidget);
  });
}
