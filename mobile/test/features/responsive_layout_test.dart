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
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_websocket_channel.dart';

// Mocked at the repository layer — real Hive deadlocks under `testWidgets`,
// same reasoning as `app_shell_test.dart`.
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

Device _device(String id, String name) => Device(
  id: id,
  vehicleName: name,
  deviceCode: 'CODE-$id',
  plate: 'PLT$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026, 8, 1),
  createdAt: DateTime.utc(2026, 8, 1),
);

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final deviceRepo = _MockDeviceRepository();
  final telemetryRepo = _MockTelemetryRepository();
  final alertRepo = _MockAlertRepository();
  when(() => deviceRepo.peekCache()).thenReturn(null);
  when(
    () => deviceRepo.fetchAndCache(),
  ).thenAnswer((_) async => [_device('d1', 'Camión 12')]);
  when(() => telemetryRepo.peekCache()).thenReturn(null);
  when(() => telemetryRepo.fetchAndCache()).thenAnswer((_) async => []);
  when(() => alertRepo.peekCache()).thenReturn(null);
  when(() => alertRepo.fetchAndCache()).thenAnswer((_) async => []);

  final connectivity = _MockConnectivity();
  when(
    () => connectivity.onConnectivityChanged,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.wifi]);

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
            channelFactory: FakeChannelFactory().call,
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
}

void main() {
  testWidgets('RESP-1: a 375dp-wide phone shows the bottom NavigationBar', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(375, 812));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RESP-1: an 800dp-wide tablet shows the NavigationRail, not the bottom bar',
    (tester) async {
      await _pumpAt(tester, const Size(800, 1024));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RESP-1: vehicles is single-pane (push navigation) below 600dp', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(375, 812));

    await tester.tap(find.text(AppStrings.vehiclesTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.vehiclesSelectPromptTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RESP-1: vehicles switches to a list-detail two-pane layout at ≥600dp',
    (tester) async {
      await _pumpAt(tester, const Size(800, 1024));

      await tester.tap(find.text(AppStrings.vehiclesTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.vehiclesSelectPromptTitle), findsOneWidget);
      expect(find.text('Camión 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(375, 812), // small phone, portrait
    const Size(430, 932), // large phone, portrait
    const Size(812, 375), // small phone, landscape
    const Size(800, 1024), // tablet, portrait
    const Size(1024, 800), // tablet, landscape
  ]) {
    testWidgets(
      'RESP-2: the dashboard renders with no overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pumpAt(tester, size);

        expect(tester.takeException(), isNull);
      },
    );
  }
}
