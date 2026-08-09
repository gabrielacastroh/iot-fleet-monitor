import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/device.dart';
import 'package:mobile/domain/models/telemetry_reading.dart';
import 'package:mobile/state/cached.dart';
import 'package:mobile/state/devices_provider.dart';
import 'package:mobile/state/map_markers_provider.dart';
import 'package:mobile/state/telemetry_provider.dart';

Device _device(String id) => Device(
  id: id,
  vehicleName: 'V$id',
  deviceCode: 'C$id',
  plate: 'P$id',
  isActive: true,
  lastSeenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

TelemetryReading _reading(String deviceId) => TelemetryReading(
  id: 't-$deviceId',
  deviceId: deviceId,
  latitude: 1,
  longitude: 1,
  speed: 10,
  fuelLevel: 80,
  temperature: 20,
  recordedAt: DateTime.utc(2026),
);

class _StubDevicesNotifier extends DevicesNotifier {
  _StubDevicesNotifier(this._devices);
  final List<Device> _devices;

  @override
  Future<Cached<List<Device>>> build() async => Cached(_devices);
}

class _StubLatestTelemetryNotifier extends LatestTelemetryNotifier {
  _StubLatestTelemetryNotifier(this._readings);
  final Map<String, TelemetryReading> _readings;

  @override
  Future<Cached<Map<String, TelemetryReading>>> build() async =>
      Cached(_readings);
}

ProviderContainer _container({
  required List<Device> devices,
  required Map<String, TelemetryReading> readings,
}) {
  final container = ProviderContainer(
    overrides: [
      devicesProvider.overrideWith(() => _StubDevicesNotifier(devices)),
      latestTelemetryProvider.overrideWith(
        () => _StubLatestTelemetryNotifier(readings),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('MAP-2: a device with no matching reading is excluded', () async {
    final container = _container(
      devices: [_device('d1'), _device('d2')],
      readings: {'d1': _reading('d1')},
    );
    await container.read(devicesProvider.future);
    await container.read(latestTelemetryProvider.future);

    final markers = container.read(mapMarkersProvider);

    expect(markers, hasLength(1));
    expect(markers.single.device.id, 'd1');
  });

  test('MAP-2: no device has a reading -> an empty marker list', () async {
    final container = _container(
      devices: [_device('d1'), _device('d2')],
      readings: const {},
    );
    await container.read(devicesProvider.future);
    await container.read(latestTelemetryProvider.future);

    expect(container.read(mapMarkersProvider), isEmpty);
  });
}
