import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/realtime/ws_event.dart';
import 'package:mobile/domain/models/fleet_alert.dart';

void main() {
  group('parseWsEvent', () {
    test('parses a telemetry_updated payload (WS-6)', () {
      final event = parseWsEvent('''
      {
        "type": "telemetry_updated",
        "data": {
          "device_id": "d1",
          "reading_id": "r1",
          "latitude": -34.6,
          "longitude": -58.4,
          "speed": 40,
          "fuel_level": 80,
          "temperature": 22,
          "recorded_at": "2026-08-08T10:00:00.000000"
        }
      }
      ''');

      expect(event, isA<TelemetryUpdatedWsEvent>());
      final reading = (event! as TelemetryUpdatedWsEvent).reading;
      expect(reading.id, 'r1');
      expect(reading.deviceId, 'd1');
      expect(reading.latitude, -34.6);
      expect(reading.speed, 40);
      expect(reading.recordedAt.isUtc, isTrue);
    });

    test('parses an alert_created payload (WS-7)', () {
      final event = parseWsEvent('''
      {
        "type": "alert_created",
        "data": {
          "id": "a1",
          "device_id": "d1",
          "alert_type": "low_fuel",
          "message": "Fuel is low",
          "created_at": "2026-08-08T10:00:00.000000"
        }
      }
      ''');

      expect(event, isA<AlertCreatedWsEvent>());
    });

    test(
      'parses an alert_resolved payload with no message/created_at (WS-8)',
      () {
        final event = parseWsEvent('''
      {
        "type": "alert_resolved",
        "data": {
          "id": "a1",
          "device_id": "d1",
          "alert_type": "low_fuel"
        }
      }
      ''');

        expect(event, isA<AlertResolvedWsEvent>());
        final resolved = event! as AlertResolvedWsEvent;
        expect(resolved.id, 'a1');
        expect(resolved.deviceId, 'd1');
        expect(resolved.alertType, AlertType.lowFuel);
      },
    );

    test('WS-10: an unrecognized type is dropped, not thrown', () {
      final event = parseWsEvent('{"type": "something_else", "data": {}}');
      expect(event, isNull);
    });

    test('WS-10: a missing type is dropped, not thrown', () {
      final event = parseWsEvent('{"data": {}}');
      expect(event, isNull);
    });

    test('WS-10: malformed JSON is dropped, not thrown', () {
      final event = parseWsEvent('not json at all');
      expect(event, isNull);
    });

    test('WS-10: a well-known type with a malformed data shape is dropped', () {
      final event = parseWsEvent(
        '{"type": "telemetry_updated", "data": {"device_id": "d1"}}',
      );
      expect(event, isNull);
    });
  });
}
