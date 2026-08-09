import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/derived_alerts.dart';
import 'package:mobile/domain/rules/fleet_status.dart';

Device _device({required bool isActive, DateTime? lastSeenAt}) => Device(
  id: 'd1',
  vehicleName: 'Camión 12',
  deviceCode: 'ABC-1234',
  plate: 'AB123CD',
  isActive: isActive,
  lastSeenAt: lastSeenAt,
  createdAt: DateTime.utc(2026, 1, 1),
);

TelemetryReading _reading({
  double fuelLevel = 100,
  double speed = 0,
  double temperature = 20,
}) => TelemetryReading(
  id: 't1',
  deviceId: 'd1',
  latitude: 0,
  longitude: 0,
  speed: speed,
  fuelLevel: fuelLevel,
  temperature: temperature,
  recordedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  // VEH-5 thresholds ported from frontend/src/lib/fleet.ts:4-5
  // (LOW_FUEL_THRESHOLD=20, SPEED_LIMIT=110) and fleet.ts:114 (critical
  // fuel cutoff <=10).
  test('fuel=20 resolves to alert (LOW_FUEL_THRESHOLD, inclusive)', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
    final reading = _reading(fuelLevel: 20);

    expect(fleetOverlayStatus(device, reading), FleetStatus.alert);
  });

  test('fuel=10 resolves to critical (inclusive)', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
    final reading = _reading(fuelLevel: 10);

    expect(fleetOverlayStatus(device, reading), FleetStatus.critical);
  });

  test('speed=110 resolves to active (strictly greater-than, not >=)', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
    final reading = _reading(speed: 110);

    expect(fleetOverlayStatus(device, reading), FleetStatus.active);
  });

  test('speed=110.1 resolves to critical', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
    final reading = _reading(speed: 110.1);

    expect(fleetOverlayStatus(device, reading), FleetStatus.critical);
  });

  test(
    'fuel=5 and speed=120 resolves to critical (either condition alone is sufficient, no double-counting)',
    () {
      final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
      final reading = _reading(fuelLevel: 5, speed: 120);

      expect(fleetOverlayStatus(device, reading), FleetStatus.critical);
    },
  );

  test('fuel=21 and speed=100 stays active (above both thresholds)', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
    final reading = _reading(fuelLevel: 21, speed: 100);

    expect(fleetOverlayStatus(device, reading), FleetStatus.active);
  });

  test(
    'an inactive base state always wins — no overlay even with critical readings',
    () {
      final device = _device(isActive: false, lastSeenAt: null);
      final reading = _reading(fuelLevel: 1, speed: 200);

      expect(fleetOverlayStatus(device, reading), FleetStatus.inactive);
    },
  );

  test(
    'a noSignal base state always wins — no overlay even with critical readings',
    () {
      final device = _device(isActive: true, lastSeenAt: null);
      final reading = _reading(fuelLevel: 1, speed: 200);

      expect(fleetOverlayStatus(device, reading), FleetStatus.noSignal);
    },
  );

  test('no latest reading for an active device stays active', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));

    expect(fleetOverlayStatus(device, null), FleetStatus.active);
  });

  test(
    'a very high temperature alone never triggers an overlay — no HIGH_TEMP_THRESHOLD rule exists (proposal decision 2)',
    () {
      final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));
      final reading = _reading(temperature: 999, fuelLevel: 100, speed: 0);

      expect(fleetOverlayStatus(device, reading), FleetStatus.active);
    },
  );

  test('the pinned threshold constants match fleet.ts exactly', () {
    expect(lowFuelThreshold, 20);
    expect(criticalFuelThreshold, 10);
    expect(speedLimit, 110);
  });
}
