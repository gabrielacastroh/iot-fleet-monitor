import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/jwt_claims.dart';
import 'package:mobile/data/realtime/telemetry_socket.dart';
import 'package:mobile/domain/models/app_user.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/domain/models/session.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/state/alerts_provider.dart';
import 'package:mobile/state/cached.dart';
import 'package:mobile/state/devices_provider.dart';
import 'package:mobile/state/realtime_provider.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mobile/state/telemetry_provider.dart';

import '../helpers/fake_websocket_channel.dart';

/// Polls [check] until it's true or [timeout] elapses, instead of a fixed
/// real-time `Future.delayed` — avoids flaking on a slow/cold first test in
/// the suite while still bounding worst-case wait.
Future<void> _waitUntil(
  bool Function() check, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('_waitUntil timed out after $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Session _session({required bool isAdmin}) => Session(
  token: 'token-1',
  user: AppUser(
    id: 'u1',
    name: 'Test',
    email: 't@example.com',
    role: isAdmin ? UserRole.admin : UserRole.user,
    isActive: true,
    createdAt: DateTime.utc(2026),
  ),
  claims: JwtClaims(
    subject: 'u1',
    expiresAt: DateTime.utc(2099),
    role: isAdmin ? 'admin' : 'user',
  ),
);

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._session);
  final Session? _session;

  @override
  Future<Session?> build() async => _session;
}

class _StubDevicesNotifier extends DevicesNotifier {
  @override
  Future<Cached<List<Device>>> build() async => const Cached([]);
}

class _StubLatestTelemetryNotifier extends LatestTelemetryNotifier {
  @override
  Future<Cached<Map<String, TelemetryReading>>> build() async =>
      const Cached({});
}

class _StubLiveFeedNotifier extends LiveFeedNotifier {
  @override
  Future<List<TelemetryReading>> build() async => const [];
}

class _Counter {
  int value = 0;
}

class _CountingAlertsNotifier extends AlertsNotifier {
  _CountingAlertsNotifier(this._counter);
  final _Counter _counter;

  @override
  Future<Cached<List<FleetAlert>>> build() async {
    _counter.value++;
    return const Cached([]);
  }
}

/// Builds a container wired for `realtime_provider.dart`'s graph without
/// touching Hive/network anywhere: `sessionProvider`/`devicesProvider`/
/// `latestTelemetryProvider`/`alertsProvider` are all overridden with stub
/// notifiers, and `telemetrySocketProvider` is overridden to inject
/// [factory] so no real socket ever opens (design §6.1's test plan).
///
/// Resolves `sessionProvider` before returning — in production `AppShell`
/// (and therefore the socket/event pipeline) only ever mounts once
/// `sessionProvider` is authenticated (the router guard), so a WS event can
/// never arrive while it's still `AsyncLoading`. Matching that invariant
/// here avoids a race where `isAdminProvider` reads `false` (its
/// loading-state default) for the very first event.
Future<(ProviderContainer, _Counter)> _buildContainer(
  FakeChannelFactory factory, {
  required bool isAdmin,
}) async {
  final alertsBuildCount = _Counter();
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(
        () => _FakeSessionNotifier(_session(isAdmin: isAdmin)),
      ),
      devicesProvider.overrideWith(_StubDevicesNotifier.new),
      latestTelemetryProvider.overrideWith(_StubLatestTelemetryNotifier.new),
      liveFeedProvider.overrideWith(_StubLiveFeedNotifier.new),
      alertsProvider.overrideWith(
        () => _CountingAlertsNotifier(alertsBuildCount),
      ),
      telemetrySocketProvider.overrideWith((ref) {
        final socket = TelemetrySocket(
          wsBaseUrl: 'ws://localhost:8000',
          channelFactory: factory.call,
        );
        ref.onDispose(socket.close);
        socket.connect('token-1');
        return socket;
      }),
    ],
  );
  await container.read(sessionProvider.future);
  return (container, alertsBuildCount);
}

void main() {
  group('WsConnectionStateNotifier', () {
    test(
      'starts closed (the socket\'s own pre-connect default) and reflects '
      'update() — not seeded from telemetrySocketProvider, since that '
      'provider\'s own onConnectionStateChanged callback can fire '
      'synchronously from inside its build (see realtime_provider.dart)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(wsConnectionStateProvider),
          WsConnectionState.closed,
        );

        container
            .read(wsConnectionStateProvider.notifier)
            .update(WsConnectionState.open);
        expect(
          container.read(wsConnectionStateProvider),
          WsConnectionState.open,
        );
      },
    );
  });

  group('WS-1: the single-connection guarantee', () {
    test('two separate wsEventsProvider listeners on one ProviderContainer '
        'open exactly one channel — proving the guarantee is structural '
        '(provider identity), not TelemetrySocket\'s own guard', () async {
      final factory = FakeChannelFactory();
      final (container, _) = await _buildContainer(factory, isAdmin: true);
      addTearDown(container.dispose);

      container.listen(wsEventsProvider, (_, _) {});
      container.listen(wsEventsProvider, (_, _) {});
      container.listen(wsEventsProvider, (_, _) {});

      expect(factory.callCount, 1);
    });
  });

  group('handleWsEvent (via wsEventRouterProvider)', () {
    test(
      'WS-6: telemetry_updated upserts latestTelemetryProvider and pushes the live feed',
      () async {
        final factory = FakeChannelFactory();
        final (container, _) = await _buildContainer(factory, isAdmin: false);
        addTearDown(container.dispose);

        container.listen(wsEventRouterProvider, (_, _) {});
        await container.read(latestTelemetryProvider.future);
        await container.read(liveFeedProvider.future);

        factory.channels.single.emit('''
        {
          "type": "telemetry_updated",
          "data": {
            "device_id": "d1", "reading_id": "r1", "latitude": 0, "longitude": 0,
            "speed": 42, "fuel_level": 55, "temperature": 21,
            "recorded_at": "2026-08-08T10:00:00.000000"
          }
        }
        ''');
        await Future<void>.delayed(Duration.zero);

        final latest = container.read(latestTelemetryProvider).value!.value;
        expect(latest['d1']?.speed, 42);
        final liveFeed = container.read(liveFeedProvider).value!;
        expect(liveFeed, hasLength(1));
        expect(liveFeed.first.deviceId, 'd1');
      },
    );

    test(
      'WS-7/WS-8 + ROLE-2: an alert event invalidates alertsProvider only for an admin session',
      () async {
        final factory = FakeChannelFactory();
        final (container, alertsBuildCount) = await _buildContainer(
          factory,
          isAdmin: true,
        );
        addTearDown(container.dispose);

        container.listen(wsEventRouterProvider, (_, _) {});
        // A persistent listener, matching how a real screen watches
        // alertsProvider — an invalidate on a provider nobody is watching
        // only rebuilds lazily on next read, not eagerly.
        container.listen(alertsProvider, (_, _) {});
        await container.read(alertsProvider.future);
        expect(alertsBuildCount.value, 1);

        factory.channels.single.emit(
          '{"type": "alert_created", "data": {"id": "a1", "device_id": "d1", "alert_type": "low_fuel", "message": "m", "created_at": "2026-08-08T10:00:00.000000"}}',
        );
        await _waitUntil(() => alertsBuildCount.value == 2);
      },
    );

    test(
      'ROLE-2: an alert event never touches alertsProvider for a non-admin session',
      () async {
        final factory = FakeChannelFactory();
        final (container, alertsBuildCount) = await _buildContainer(
          factory,
          isAdmin: false,
        );
        addTearDown(container.dispose);

        container.listen(wsEventRouterProvider, (_, _) {});
        // Never read alertsProvider at all for a non-admin — the entire
        // point is that it's never constructed.
        expect(alertsBuildCount.value, 0);

        factory.channels.single.emit(
          '{"type": "alert_resolved", "data": {"id": "a1", "device_id": "d1", "alert_type": "low_fuel"}}',
        );
        // A negative assertion can't poll-until-true; wait past the 500ms
        // debounce window with margin, then confirm nothing fired.
        await Future<void>.delayed(const Duration(seconds: 1));

        expect(alertsBuildCount.value, 0);
      },
    );

    test(
      'a burst of alert events produces one debounced invalidation, not one per event',
      () async {
        final factory = FakeChannelFactory();
        final (container, alertsBuildCount) = await _buildContainer(
          factory,
          isAdmin: true,
        );
        addTearDown(container.dispose);

        container.listen(wsEventRouterProvider, (_, _) {});
        container.listen(alertsProvider, (_, _) {});
        await container.read(alertsProvider.future);
        expect(alertsBuildCount.value, 1);

        for (var i = 0; i < 5; i++) {
          factory.channels.single.emit(
            '{"type": "alert_created", "data": {"id": "a$i", "device_id": "d1", "alert_type": "low_fuel", "message": "m", "created_at": "2026-08-08T10:00:00.000000"}}',
          );
        }
        await _waitUntil(() => alertsBuildCount.value == 2);
        expect(alertsBuildCount.value, 2); // 1 initial + 1 debounced refetch
      },
    );
  });
}
