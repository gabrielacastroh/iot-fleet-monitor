import '../models/device.dart';
import '../models/telemetry_reading.dart';
import 'fleet_status.dart';

/// DASH-1's dashboard aggregate. Mobile-authored — no exact web equivalent
/// to port. [averageFuelLevel]/[averageTemperature] are computed only over
/// devices that have a latest reading (not gated by active-only, since
/// DASH-1's wording doesn't further qualify it); `null` means no device has
/// reported yet, distinct from `0`. [openAlertsCount] stays nullable so the
/// KPI row can OMIT (not zero) the tile for a non-admin session (ROLE-2).
class FleetKpis {
  const FleetKpis({
    required this.activeCount,
    required this.averageFuelLevel,
    required this.averageTemperature,
    required this.openAlertsCount,
  });

  final int activeCount;
  final double? averageFuelLevel;
  final double? averageTemperature;
  final int? openAlertsCount;
}

FleetKpis computeFleetKpis({
  required List<Device> devices,
  required Map<String, TelemetryReading> latestByDevice,
  required int? openAlertsCount,
}) {
  final activeCount = devices
      .where((device) => deviceStatus(device) == FleetStatus.active)
      .length;

  final readings = [
    for (final device in devices) latestByDevice[device.id],
  ].whereType<TelemetryReading>().toList();

  return FleetKpis(
    activeCount: activeCount,
    averageFuelLevel: _average(readings.map((r) => r.fuelLevel)),
    averageTemperature: _average(readings.map((r) => r.temperature)),
    openAlertsCount: openAlertsCount,
  );
}

double? _average(Iterable<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
