import '../models/device.dart';
import '../models/telemetry_reading.dart';
import 'fleet_status.dart';

/// `LOW_FUEL_THRESHOLD`, `frontend/src/lib/fleet.ts:4`.
const lowFuelThreshold = 20;

/// The `<= 10` cutoff inlined in `deriveAlerts`, `frontend/src/lib/fleet.ts:114`.
const criticalFuelThreshold = 10;

/// `SPEED_LIMIT`, `frontend/src/lib/fleet.ts:5`.
const speedLimit = 110;

/// VEH-5 — the vehicle-list-only 5-state overlay, ported from
/// `frontend/src/lib/fleet.ts`'s `deriveAlerts` (fleet.ts:102-147)
/// thresholds. Applies ONLY when the VEH-4 base state ([deviceStatus]) is
/// `active`; `inactive`/`noSignal` always take precedence over any reading
/// (spec risk resolution #2 — an inactive device never shows an overlay).
///
/// `HIGH_TEMP_THRESHOLD` exists in `fleet.ts:8` but is never read by
/// `deriveAlerts` — no temperature rule exists here either, deliberately
/// (proposal decision 2).
FleetStatus fleetOverlayStatus(Device device, TelemetryReading? reading) {
  final base = deviceStatus(device);
  if (base != FleetStatus.active) return base;
  if (reading == null) return FleetStatus.active;

  if (reading.fuelLevel <= criticalFuelThreshold ||
      reading.speed > speedLimit) {
    return FleetStatus.critical;
  }
  if (reading.fuelLevel <= lowFuelThreshold) {
    return FleetStatus.alert;
  }
  return FleetStatus.active;
}
