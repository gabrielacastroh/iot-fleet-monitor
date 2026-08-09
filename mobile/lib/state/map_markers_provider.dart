import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/device.dart';
import '../domain/models/telemetry_reading.dart';
import '../domain/rules/derived_alerts.dart';
import '../domain/rules/fleet_status.dart';
import 'devices_provider.dart';
import 'telemetry_provider.dart';

/// One marker candidate: a device that has a reading, and the VEH-4/VEH-5
/// state that reading resolves to.
class VehicleMarker {
  const VehicleMarker({
    required this.device,
    required this.reading,
    required this.status,
  });

  final Device device;
  final TelemetryReading reading;
  final FleetStatus status;
}

/// MAP-1/MAP-2: one marker per device with a reading, live-patched via
/// WS-6 because it composes [devicesProvider]/[latestTelemetryProvider]
/// directly (no fetching of its own). A device with no latest reading is
/// excluded, never given fabricated coordinates.
final mapMarkersProvider = Provider<List<VehicleMarker>>((ref) {
  final devices = ref.watch(devicesProvider).valueOrNull?.value ?? const [];
  final telemetryByDevice =
      ref.watch(latestTelemetryProvider).valueOrNull?.value ?? const {};

  return [
    for (final device in devices)
      if (telemetryByDevice[device.id] case final reading?)
        VehicleMarker(
          device: device,
          reading: reading,
          status: fleetOverlayStatus(device, reading),
        ),
  ];
});
