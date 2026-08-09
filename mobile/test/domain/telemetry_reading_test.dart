import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';

void main() {
  final json = {
    'id': 't1',
    'device_id': 'd1',
    'latitude': -34.6,
    'longitude': -58.4,
    'speed': 80.5,
    'fuel_level': 55.0,
    'temperature': 72.3,
    'recorded_at': '2026-08-07T15:44:54.044240',
  };

  test('round trips through JSON', () {
    final reading = TelemetryReading.fromJson(json);

    expect(reading.id, 't1');
    expect(reading.deviceId, 'd1');
    expect(reading.latitude, -34.6);
    expect(reading.longitude, -58.4);
    expect(reading.speed, 80.5);
    expect(reading.fuelLevel, 55.0);
    expect(reading.temperature, 72.3);
    expect(reading.recordedAt.isUtc, isTrue);

    final roundTripped = TelemetryReading.fromJson(reading.toJson());
    expect(roundTripped, reading);
  });

  test(
    'int-as-double JSON values decode without crashing (LooseDoubleConverter)',
    () {
      final reading = TelemetryReading.fromJson({
        ...json,
        'latitude': 0,
        'speed': 0,
        'fuel_level': 100,
        'temperature': 0,
      });

      expect(reading.latitude, 0.0);
      expect(reading.speed, 0.0);
      expect(reading.fuelLevel, 100.0);
      expect(reading.temperature, 0.0);
    },
  );
}
