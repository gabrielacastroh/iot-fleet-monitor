import { Badge } from "@/components/ui/badge";
import { STATUS_TONE } from "@/lib/status";
import type { FleetStatus } from "@/lib/status";
import { cn } from "@/lib/utils";

/** A device carries three of the fleet's five states; "alerta" and "crítico"
 *  belong to readings, not to the device row itself. */
function deviceStatus(isActive: boolean, lastSeenAt?: string | null): FleetStatus {
  if (!isActive) return "inactive";
  // Active but never reported is a real third state: the fleet manager needs to
  // tell "running" apart from "registered and silent".
  if (lastSeenAt === null) return "noSignal";
  return "active";
}

/** Single rendering of a device's state — it shows up in cards, the tables, the
 *  detail view and the form preview, and they must not drift. Colours come from
 *  STATUS_TONE, the same map the alert dots and icon chips read. */
export function DeviceStatusBadge({
  isActive,
  lastSeenAt,
}: {
  isActive: boolean;
  lastSeenAt?: string | null;
}) {
  const status = deviceStatus(isActive, lastSeenAt);
  const tone = STATUS_TONE[status];

  return (
    <Badge variant={tone.variant}>
      {/* Only "activo" breathes: a pulse on a state that is not live would be
          decoration pretending to be a signal. */}
      {status === "active" && (
        <span className={cn("size-1.5 rounded-full pulse-dot", tone.dot)} aria-hidden />
      )}
      {tone.label}
    </Badge>
  );
}
