import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';

void main() {
  final json = {
    'id': 'd1',
    'vehicle_name': 'Camión 12',
    'device_code': 'ABC-1234',
    'plate': 'AB123CD',
    'is_active': true,
    'last_seen_at': '2026-08-07T15:44:54.044240',
    'created_at': '2026-08-01T10:00:00.000000',
  };

  test('round trips through JSON', () {
    final device = Device.fromJson(json);

    expect(device.id, 'd1');
    expect(device.vehicleName, 'Camión 12');
    expect(device.deviceCode, 'ABC-1234');
    expect(device.plate, 'AB123CD');
    expect(device.isActive, isTrue);
    expect(device.lastSeenAt?.isUtc, isTrue);
    expect(device.createdAt.isUtc, isTrue);

    final roundTripped = Device.fromJson(device.toJson());
    expect(roundTripped, device);
  });

  test('last_seen_at: null round trips as null', () {
    final device = Device.fromJson({...json, 'last_seen_at': null});

    expect(device.lastSeenAt, isNull);
    expect(Device.fromJson(device.toJson()).lastSeenAt, isNull);
  });
}
