import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';
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

void main() {
  // VEH-4, literal port of DeviceStatusBadge.tsx's derivation.
  test(
    'isActive=true, lastSeenAt=null resolves to noSignal (Sin señal, no pulse)',
    () {
      final device = _device(isActive: true, lastSeenAt: null);

      expect(deviceStatus(device), FleetStatus.noSignal);
    },
  );

  test('isActive=false resolves to inactive regardless of lastSeenAt', () {
    final withoutReading = _device(isActive: false, lastSeenAt: null);
    final withReading = _device(
      isActive: false,
      lastSeenAt: DateTime.utc(2026),
    );

    expect(deviceStatus(withoutReading), FleetStatus.inactive);
    expect(deviceStatus(withReading), FleetStatus.inactive);
  });

  test('isActive=true with a lastSeenAt resolves to active', () {
    final device = _device(isActive: true, lastSeenAt: DateTime.utc(2026));

    expect(deviceStatus(device), FleetStatus.active);
  });
}
