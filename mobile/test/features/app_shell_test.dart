import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/core/security/jwt_claims.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/data/repositories/device_repository.dart';
import 'package:mobile/data/repositories/telemetry_repository.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/app_user.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/session.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_websocket_channel.dart';

// Mocked at the repository layer, same reasoning as `vehicles_screen_test.dart`
// — real Hive deadlocks under `testWidgets`. `sessionProvider` is also
// overridden directly (not via a stored token) so `fleetCacheProvider`
// (and therefore Hive) is never reached at all.
class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockTelemetryRepository extends Mock implements TelemetryRepository {}

class _MockAlertRepository extends Mock implements AlertRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._session);
  final Session? _session;

  @override
  Future<Session?> build() async => _session;
}

Device _device(String id) => Device(
  id: id,
  vehicleName: 'Camión $id',
  deviceCode: 'CODE-$id',
  plate: 'PLT$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

TelemetryReading _reading(String deviceId) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 0,
  longitude: 0,
  speed: 40,
  fuelLevel: 80,
  temperature: 20,
  recordedAt: DateTime.utc(2026, 8, 1),
);

Session _adminSession() => Session(
  token: 'token-1',
  user: AppUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@example.com',
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.utc(2026),
  ),
  claims: JwtClaims(
    subject: 'u1',
    role: 'admin',
    expiresAt: DateTime.utc(2099),
  ),
);

Future<FakeChannelFactory> _pumpAuthenticatedApp(
  WidgetTester tester, {
  bool online = true,
  List<Device> devices = const [],
  List<TelemetryReading> readings = const [],
}) async {
  final deviceRepo = _MockDeviceRepository();
  final telemetryRepo = _MockTelemetryRepository();
  final alertRepo = _MockAlertRepository();
  when(() => deviceRepo.peekCache()).thenReturn(null);
  when(() => deviceRepo.fetchAndCache()).thenAnswer((_) async => devices);
  when(() => telemetryRepo.peekCache()).thenReturn(null);
  when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => readings);
  when(() => alertRepo.peekCache()).thenReturn(null);
  when(() => alertRepo.fetchAndCache()).thenAnswer((_) async => []);

  final connectivity = _MockConnectivity();
  when(
    () => connectivity.onConnectivityChanged,
  ).thenAnswer((_) => const Stream.empty());
  when(() => connectivity.checkConnectivity()).thenAnswer(
    (_) async => [online ? ConnectivityResult.wifi : ConnectivityResult.none],
  );

  final factory = FakeChannelFactory();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSessionNotifier(_adminSession()),
        ),
        deviceRepositoryProvider.overrideWith((ref) async => deviceRepo),
        telemetryRepositoryProvider.overrideWith((ref) async => telemetryRepo),
        alertRepositoryProvider.overrideWith((ref) async => alertRepo),
        connectivityClientProvider.overrideWithValue(connectivity),
        telemetrySocketProvider.overrideWith((ref) {
          final socket = TelemetrySocket(
            wsBaseUrl: 'ws://localhost:8000',
            channelFactory: factory.call,
          );
          ref.onDispose(socket.close);
          final token = ref.read(sessionProvider).valueOrNull?.token;
          if (token != null) socket.connect(token);
          return socket;
        }),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  return factory;
}

void main() {
  testWidgets(
    'WS-1/WS-2: mounting the authenticated shell connects exactly one socket',
    (tester) async {
      final factory = await _pumpAuthenticatedApp(tester);

      expect(factory.callCount, 1);
      expect(find.text(AppStrings.dashboardTitle), findsOneWidget);
    },
  );

  testWidgets('OFF-2: the offline banner renders when connectivity is down', (
    tester,
  ) async {
    await _pumpAuthenticatedApp(tester, online: false);

    expect(find.text(AppStrings.offlineBadgeMessage), findsOneWidget);
  });

  testWidgets('the offline banner is absent while online', (tester) async {
    await _pumpAuthenticatedApp(tester);

    expect(find.text(AppStrings.offlineBadgeMessage), findsNothing);
  });

  testWidgets(
    'SAFE-1: the Dashboard header is inset below the status bar/notch',
    (tester) async {
      // A device with a notch (iPhone 16e-class): a non-zero top view
      // padding the shared shell must respect on every branch screen.
      final originalPadding = tester.view.padding;
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 177); // 59dp * 3.0
      addTearDown(() {
        tester.view.padding = originalPadding;
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalDpr;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await _pumpAuthenticatedApp(
        tester,
        devices: [_device('d1')],
        readings: [_reading('d1')],
      );

      final topInset = tester.view.padding.top / tester.view.devicePixelRatio;
      // Disambiguated from the bottom `NavigationBar`'s own "Panel" label
      // (same string, `shellNavItems`) by scoping the finder to the
      // scrollable body content that actually renders the screen header.
      final titleTop = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(ListView),
              matching: find.text(AppStrings.dashboardTitle),
            ),
          )
          .dy;

      // Regression guard for the safe-area bug: the title must never
      // render above (or exactly at) the system status bar/notch inset.
      expect(titleTop, greaterThanOrEqualTo(topInset));
    },
  );
}
