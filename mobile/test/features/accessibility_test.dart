import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/features/alerts/alerts_screen.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/vehicles/vehicles_screen.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

class _MockAlertRepository extends Mock implements AlertRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

Device _device(String id, String name) => Device(
  id: id,
  vehicleName: name,
  deviceCode: 'CODE-$id',
  plate: 'PLT$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

FleetAlert _alert(String id) => FleetAlert(
  id: id,
  deviceId: 'd1',
  alertType: AlertType.lowFuel,
  message: 'Combustible bajo $id',
  isResolved: false,
  createdAt: DateTime.utc(2026, 8, 1),
);

List<Override> _connectivityOverride({bool online = true}) {
  final connectivity = _MockConnectivity();
  when(
    () => connectivity.onConnectivityChanged,
  ).thenAnswer((_) => const Stream.empty());
  when(() => connectivity.checkConnectivity()).thenAnswer(
    (_) async => [online ? ConnectivityResult.wifi : ConnectivityResult.none],
  );
  return [connectivityClientProvider.overrideWithValue(connectivity)];
}

Future<void> _pumpVehicles(WidgetTester tester) async {
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
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: VehiclesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAlerts(WidgetTester tester) async {
  pinPhoneViewport(tester);
  final repository = _MockAlertRepository();
  when(() => repository.peekCache()).thenReturn(null);
  when(
    () => repository.fetchAndCache(),
  ).thenAnswer((_) async => [_alert('a1')]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertRepositoryProvider.overrideWith((ref) async => repository),
        ..._connectivityOverride(),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AlertsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDashboard(WidgetTester tester) async {
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
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DashboardScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLogin(WidgetTester tester) async {
  pinPhoneViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('A11Y-1/A11Y-2/A11Y-4: touch targets, contrast, semantics labels', () {
    testWidgets('login screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLogin(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('dashboard screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDashboard(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('vehicles screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpVehicles(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('alerts screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpAlerts(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('A11Y-3: 2.0x text scale reflows without clipping/overlap errors', () {
    Future<void> pumpAtScale(
      WidgetTester tester,
      Widget child, {
      double scale = 2.0,
    }) async {
      pinPhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(theme: AppTheme.light, home: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('login screen at 2.0x text scale', (tester) async {
      await pumpAtScale(tester, const LoginScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard screen at 2.0x text scale', (tester) async {
      final deviceRepo = _MockDeviceRepository();
      final telemetryRepo = _MockTelemetryRepository();
      when(() => deviceRepo.peekCache()).thenReturn(null);
      when(
        () => deviceRepo.fetchAndCache(),
      ).thenAnswer((_) async => [_device('d1', 'Camión 12')]);
      when(() => telemetryRepo.peekCache()).thenReturn(null);
      when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => []);

      pinPhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
            telemetryRepositoryProvider.overrideWith(
              (ref) async => telemetryRepo,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: DashboardScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('vehicles screen at 2.0x text scale', (tester) async {
      final deviceRepo = _MockDeviceRepository();
      final telemetryRepo = _MockTelemetryRepository();
      when(() => deviceRepo.peekCache()).thenReturn(null);
      when(
        () => deviceRepo.fetchAndCache(),
      ).thenAnswer((_) async => [_device('d1', 'Camión 12')]);
      when(() => telemetryRepo.peekCache()).thenReturn(null);
      when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => []);

      pinPhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
            telemetryRepositoryProvider.overrideWith(
              (ref) async => telemetryRepo,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: VehiclesScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('alerts screen at 2.0x text scale', (tester) async {
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(
        () => repository.fetchAndCache(),
      ).thenAnswer((_) async => [_alert('a1')]);

      pinPhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
            ..._connectivityOverride(),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: AlertsScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
