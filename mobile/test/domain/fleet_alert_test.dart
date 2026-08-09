import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/fleet_alert.dart';

const _json = {
  'id': 'a1',
  'device_id': 'd1',
  'alert_type': 'low_fuel',
  'message': 'Fuel is low',
  'is_resolved': false,
  'created_at': '2026-08-08T10:00:00.000000',
};

void main() {
  test('round-trips through JSON', () {
    final alert = FleetAlert.fromJson(_json);

    expect(alert.id, 'a1');
    expect(alert.deviceId, 'd1');
    expect(alert.alertType, AlertType.lowFuel);
    expect(alert.message, 'Fuel is low');
    expect(alert.isResolved, isFalse);
    expect(alert.createdAt.isUtc, isTrue);

    final roundTripped = FleetAlert.fromJson(alert.toJson());
    expect(roundTripped, alert);
  });

  test('an unrecognized alert_type falls back to AlertType.unknown', () {
    final alert = FleetAlert.fromJson({..._json, 'alert_type': 'engine_fault'});

    expect(alert.alertType, AlertType.unknown);
  });
}
