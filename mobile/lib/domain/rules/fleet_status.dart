import '../models/device.dart';

/// The fleet's five states, literal port of `frontend/src/lib/status.ts`
/// (`FleetStatus` type, status.ts:15). A device only ever occupies 3 of the
/// 5 — `alert`/`critical` come exclusively from `derived_alerts.dart`'s
/// reading-level overlay (VEH-5).
enum FleetStatus { active, inactive, noSignal, alert, critical }

/// VEH-4 — the 3-state device badge derivation, a literal port of the
/// web's `DeviceStatusBadge.tsx`:
/// ```
/// !device.isActive                        -> inactive
/// device.isActive && lastSeenAt == null   -> noSignal
/// otherwise                               -> active
/// ```
FleetStatus deviceStatus(Device device) {
  if (!device.isActive) return FleetStatus.inactive;
  if (device.lastSeenAt == null) return FleetStatus.noSignal;
  return FleetStatus.active;
}
