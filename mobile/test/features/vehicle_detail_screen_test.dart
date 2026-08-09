import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/status_tone.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/fleet_status.dart';
import 'package:mobile/features/vehicles/vehicle_detail_screen.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

class _MockAlertsApi extends Mock implements AlertsApi {}

Device _device(String id, String name, {bool neverReported = false}) => Device(
  id: id,
  vehicleName: name,
  deviceCode: 'CODE-$id',
  plate: 'PLT-$id',
  isActive: true,
  lastSeenAt: neverReported ? null : DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<_MockAlertsApi> _pump(
  WidgetTester tester, {
  required List<Device> devices,
  List<TelemetryReading> readings = const [],
  String deviceId = 'd1',
  bool isAdmin = false,
}) async {
  pinPhoneViewport(tester);
  final deviceRepo = _MockDeviceRepository();
  final telemetryRepo = _MockTelemetryRepository();
  final alertsApi = _MockAlertsApi();
  when(() => deviceRepo.peekCache()).thenReturn(null);
  when(() => deviceRepo.fetchAndCache()).thenAnswer((_) async => devices);
  when(() => telemetryRepo.peekCache()).thenReturn(null);
  when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => readings);
  when(
    () => telemetryRepo.fetchHistory(
      deviceId: any(named: 'deviceId'),
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const []);
  when(() => alertsApi.getForDevice(any())).thenAnswer((_) async => []);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
        alertsApiProvider.overrideWithValue(alertsApi),
        isAdminProvider.overrideWithValue(isAdmin),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: VehicleDetailScreen(deviceId: deviceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return alertsApi;
}

void main() {
  testWidgets('deep-link by deviceId resolves the correct device', (
    tester,
  ) async {
    await _pump(
      tester,
      devices: [_device('d1', 'Camión 12'), _device('d2', 'Camión 13')],
      deviceId: 'd2',
    );

    expect(find.text('Camión 13'), findsWidgets);
    expect(find.text('Camión 12'), findsNothing);
  });

  testWidgets('an unknown deviceId shows the not-found state', (tester) async {
    await _pump(
      tester,
      devices: [_device('d1', 'Camión 12')],
      deviceId: 'missing',
    );

    expect(find.text(AppStrings.vehicleNotFoundTitle), findsOneWidget);
  });

  testWidgets('the VEH-4 status badge reflects the device state', (
    tester,
  ) async {
    await _pump(
      tester,
      devices: [_device('d1', 'Camión 12', neverReported: true)],
    );

    final label = statusToneOf(
      tester.element(find.byType(Scaffold).first),
      FleetStatus.noSignal,
    ).label;
    expect(find.text(label), findsWidgets);
  });

  testWidgets(
    'current state, telemetry and alerts share one scroll — no tabs',
    (tester) async {
      await _pump(
        tester,
        devices: [_device('d1', 'Camión 12')],
        isAdmin: true,
      );

      expect(find.byType(TabBar), findsNothing);
      expect(find.text(AppStrings.vehicleLastUpdateLabel), findsOneWidget);
      expect(find.text(AppStrings.telemetrySectionTitle), findsOneWidget);
      expect(find.text(AppStrings.activeAlertsSectionTitle), findsOneWidget);
    },
  );

  testWidgets(
    'ROLE-2: a non-admin gets no alerts section and never calls the endpoint',
    (tester) async {
      final alertsApi = await _pump(
        tester,
        devices: [_device('d1', 'Camión 12')],
      );

      expect(find.text(AppStrings.activeAlertsSectionTitle), findsNothing);
      verifyNever(() => alertsApi.getForDevice(any()));
    },
  );
}
