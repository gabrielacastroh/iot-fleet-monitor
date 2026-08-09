import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/jwt_claims.dart';
import 'package:mobile/domain/models/app_user.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/fleet_alert.dart';
import 'package:mobile/domain/models/session.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/features/dashboard/state/fleet_kpis_provider.dart';
import 'package:mobile/state/alerts_provider.dart';
import 'package:mobile/state/cached.dart';
import 'package:mobile/state/devices_provider.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mobile/state/telemetry_provider.dart';

Session _session({required bool isAdmin}) => Session(
  token: 't',
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

Device _device(String id, {bool isActive = true}) => Device(
  id: id,
  vehicleName: 'V$id',
  deviceCode: 'C$id',
  plate: 'P$id',
  isActive: isActive,
  lastSeenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

class _StubDevicesNotifier extends DevicesNotifier {
  @override
  Future<Cached<List<Device>>> build() async =>
      Cached([_device('d1'), _device('d2', isActive: false)]);
}

class _StubLatestTelemetryNotifier extends LatestTelemetryNotifier {
  @override
  Future<Cached<Map<String, TelemetryReading>>> build() async => Cached({
    'd1': TelemetryReading(
      id: 't1',
      deviceId: 'd1',
      latitude: 0,
      longitude: 0,
      speed: 0,
      fuelLevel: 40,
      temperature: 25,
      recordedAt: DateTime.utc(2026),
    ),
  });
}

class _CountingAlertsNotifier extends AlertsNotifier {
  static int buildCount = 0;

  @override
  Future<Cached<List<FleetAlert>>> build() async {
    buildCount++;
    return Cached([
      FleetAlert(
        id: 'a1',
        deviceId: 'd1',
        alertType: AlertType.lowFuel,
        message: 'm',
        isResolved: false,
        createdAt: DateTime.utc(2026),
      ),
    ]);
  }
}

void main() {
  setUp(() {
    _CountingAlertsNotifier.buildCount = 0;
  });

  test(
    'DASH-1: aggregates devices + latest telemetry for a non-admin session',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionNotifier(_session(isAdmin: false)),
          ),
          devicesProvider.overrideWith(_StubDevicesNotifier.new),
          latestTelemetryProvider.overrideWith(
            _StubLatestTelemetryNotifier.new,
          ),
          // Overridden so that if the code under test ever watches
          // alertsProvider unconditionally, this counter (asserted below)
          // would catch it — proving ROLE-2 rather than assuming it.
          alertsProvider.overrideWith(_CountingAlertsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(devicesProvider.future);
      await container.read(latestTelemetryProvider.future);

      final kpis = container.read(fleetKpisProvider);

      expect(kpis.activeCount, 1);
      expect(kpis.averageFuelLevel, 40);
      expect(kpis.averageTemperature, 25);
      expect(kpis.openAlertsCount, isNull); // ROLE-2: omitted for non-admin
      expect(_CountingAlertsNotifier.buildCount, 0); // never constructed
    },
  );

  test(
    'DASH-1: openAlertsCount reflects the open-alerts list length for an admin session',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionNotifier(_session(isAdmin: true)),
          ),
          devicesProvider.overrideWith(_StubDevicesNotifier.new),
          latestTelemetryProvider.overrideWith(
            _StubLatestTelemetryNotifier.new,
          ),
          alertsProvider.overrideWith(_CountingAlertsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.future);
      await container.read(devicesProvider.future);
      await container.read(latestTelemetryProvider.future);
      await container.read(alertsProvider.future);

      final kpis = container.read(fleetKpisProvider);

      expect(kpis.openAlertsCount, 1);
      expect(_CountingAlertsNotifier.buildCount, 1);
    },
  );
}
