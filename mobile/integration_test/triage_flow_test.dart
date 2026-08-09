import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/app.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../test/helpers/fake_secure_storage_platform.dart';
import '../test/helpers/fake_websocket_channel.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// Scopes a bottom-`NavigationBar` tap to that bar specifically — several
/// screens (e.g. the vehicle detail's own tabs) reuse the same label text
/// (`AppStrings.alertsTitle` == `AppStrings.vehicleDetailAlertsTab`, both
/// "Alertas") elsewhere on screen at the same time.
Finder _navDestination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// End-to-end triage flow (T7.12, design §11): login -> dashboard ->
/// vehicle detail (Alertas tab) -> alerts list -> alert detail -> resolve,
/// against a `DioAdapter`-stubbed API and a fake WS channel — proving both
/// the main navigation flows and WS-6/WS-8's fan-out/invalidate-not-patch
/// policy end to end, with the real `alerts_screen`/`alert_detail_screen`
/// resolve action (not a stub).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('triage_flow_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'login -> dashboard -> vehicle detail -> alerts -> alert detail -> resolve',
    (tester) async {
      // Pins the layout to RESP-1's single-pane phone breakpoint — the
      // desktop/CI runner's real window is wide enough to trip the ≥600dp
      // two-pane/NavigationRail layout otherwise, which is covered on its
      // own in `responsive_layout_test.dart`.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);

      adapter
        ..onPost(
          '/auth/login',
          (server) => server.reply(200, {
            'access_token': _jwt(),
            'token_type': 'bearer',
          }),
          data: Matchers.any,
        )
        ..onGet('/auth/me', (server) => server.reply(200, _userJson))
        ..onGet('/devices', (server) => server.reply(200, [_deviceJson]))
        ..onGet(
          '/telemetry/latest',
          (server) => server.reply(200, [_readingJson]),
        )
        ..onGet(
          '/alerts',
          (server) => server.reply(200, [_alertJson]),
          queryParameters: {'is_resolved': false, 'limit': 200},
        )
        ..onGet(
          '/alerts/d1',
          (server) => server.reply(200, [_alertJson]),
          queryParameters: {'limit': 200},
        )
        ..onPatch(
          '/alerts/a1/resolve',
          (server) => server.reply(200, {..._alertJson, 'is_resolved': true}),
        );

      final wsFactory = FakeChannelFactory();

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
            dioProvider.overrideWithValue(dio),
            connectivityClientProvider.overrideWithValue(connectivity),
            telemetrySocketProvider.overrideWith((ref) {
              final socket = TelemetrySocket(
                wsBaseUrl: 'ws://localhost:8000',
                channelFactory: wsFactory.call,
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

      // --- login ---
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      // --- dashboard --- ("Panel" also labels the bottom nav destination.
      expect(find.text(AppStrings.dashboardTitle), findsWidgets);

      // WS-6: a telemetry_updated event upserts the live feed.
      wsFactory.channels.single.emit(
        jsonEncode({
          'type': 'telemetry_updated',
          'data': {..._readingJson, 'reading_id': 't2', 'speed': 55},
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // --- navigation: vehicles -> vehicle detail ---
      await tester.tap(_navDestination(AppStrings.vehiclesTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camión 12').first);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.vehicleLastUpdateLabel), findsOneWidget);

      // --- vehicle detail: alerts section (VDET-4) ---
      // One scroll, no tabs: the open alerts sit below the telemetry
      // charts, so the flow scrolls to them instead of switching tab.
      await tester.scrollUntilVisible(
        find.text(AppStrings.activeAlertsSectionTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Combustible bajo a1'), findsOneWidget);

      // --- navigation: alerts list ---
      await tester.tap(_navDestination(AppStrings.alertsTitle));
      await tester.pumpAndSettle();
      expect(find.text('Combustible bajo a1'), findsOneWidget);

      // --- alert detail: view then resolve ---
      await tester.tap(find.text('Combustible bajo a1'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.alertDetailTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.resolveAlertLabel));
      await tester.pumpAndSettle();

      // Popped back to the (now empty) Pendientes list.
      expect(find.text(AppStrings.alertsEmptyPendingTitle), findsOneWidget);

      // WS-8: alert_resolved is an invalidation signal only — never a
      // local patch. It must not crash even though the alert is already
      // gone from the cached open list.
      wsFactory.channels.single.emit(
        jsonEncode({
          'type': 'alert_resolved',
          'data': {'id': 'a1', 'device_id': 'd1', 'alert_type': 'low_fuel'},
        }),
      );
      await tester.pump(const Duration(milliseconds: 600)); // debounce
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

const _userJson = {
  'id': 'u1',
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'role': 'admin',
  'is_active': true,
  'created_at': '2026-08-07T15:44:54.044240',
};

const _deviceJson = {
  'id': 'd1',
  'vehicle_name': 'Camión 12',
  'device_code': 'CODE-D1',
  'plate': 'PLT-D1',
  'is_active': true,
  'last_seen_at': '2026-08-07T15:44:54.044240',
  'created_at': '2026-08-01T00:00:00.000000',
};

const _readingJson = {
  'id': 't1',
  'device_id': 'd1',
  'latitude': -34.6,
  'longitude': -58.4,
  'speed': 80,
  'fuel_level': 55,
  'temperature': 22,
  'recorded_at': '2026-08-07T15:44:54.044240',
};

const _alertJson = {
  'id': 'a1',
  'device_id': 'd1',
  'alert_type': 'low_fuel',
  'message': 'Combustible bajo a1',
  'is_resolved': false,
  'created_at': '2026-08-07T15:44:54.044240',
};

/// A minimal, non-expiring HS256-shaped (unsigned) JWT — same construction
/// every unit test in `test/data/session_repository_test.dart` etc. uses.
String _jwt() {
  String segment(Map<String, dynamic> payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  final exp =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  final header = segment({'alg': 'none'});
  final payload = segment({'sub': 'u1', 'role': 'admin', 'exp': exp});
  return '$header.$payload.signature';
}
