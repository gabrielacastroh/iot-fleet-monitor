import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/domain/rules/fleet_kpis.dart';

Device _device(String id, {bool isActive = true, bool hasSignal = true}) =>
    Device(
      id: id,
      vehicleName: 'V$id',
      deviceCode: 'C$id',
      plate: 'P$id',
      isActive: isActive,
      lastSeenAt: hasSignal ? DateTime.utc(2026) : null,
      createdAt: DateTime.utc(2026),
    );

TelemetryReading _reading(
  String deviceId, {
  double fuelLevel = 50,
  double temperature = 20,
}) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 0,
  longitude: 0,
  speed: 0,
  fuelLevel: fuelLevel,
  temperature: temperature,
  recordedAt: DateTime.utc(2026),
);

void main() {
  group('computeFleetKpis', () {
    test(
      'DASH-1: activeCount only counts devices whose base state is active',
      () {
        final kpis = computeFleetKpis(
          devices: [
            _device('d1'), // active
            _device('d2', isActive: false), // inactive
            _device('d3', hasSignal: false), // noSignal
          ],
          latestByDevice: const {},
          openAlertsCount: null,
        );

        expect(kpis.activeCount, 1);
      },
    );

    test(
      'DASH-1: average fuel/temperature is over devices with a latest reading only',
      () {
        final kpis = computeFleetKpis(
          devices: [_device('d1'), _device('d2'), _device('d3')],
          latestByDevice: {
            'd1': _reading('d1', fuelLevel: 80, temperature: 20),
            'd2': _reading('d2', fuelLevel: 40, temperature: 30),
            // d3 has no reading — excluded from the average, not treated as 0.
          },
          openAlertsCount: null,
        );

        expect(kpis.averageFuelLevel, 60);
        expect(kpis.averageTemperature, 25);
      },
    );

    test(
      'DASH-1: no devices with a reading yields a null average, not NaN/0',
      () {
        final kpis = computeFleetKpis(
          devices: [_device('d1')],
          latestByDevice: const {},
          openAlertsCount: null,
        );

        expect(kpis.averageFuelLevel, isNull);
        expect(kpis.averageTemperature, isNull);
      },
    );

    test(
      'DASH-1/ROLE-2: openAlertsCount is passed through as-is, null for non-admin',
      () {
        expect(
          computeFleetKpis(
            devices: const [],
            latestByDevice: const {},
            openAlertsCount: null,
          ).openAlertsCount,
          isNull,
        );
        expect(
          computeFleetKpis(
            devices: const [],
            latestByDevice: const {},
            openAlertsCount: 3,
          ).openAlertsCount,
          3,
        );
      },
    );
  });
}
