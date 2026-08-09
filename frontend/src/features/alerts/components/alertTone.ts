import { Fuel } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import type { FleetAlert } from "@/lib/fleet";
import { STATUS_TONE } from "@/lib/status";
import type { StatusTone } from "@/lib/status";
import type { Alert, AlertType } from "../types/alert";

interface AlertTone {
  label: string;
  icon: LucideIcon;
  /** Icon chip classes. */
  chip: string;
  badge: StatusTone["variant"];
}

/**
 * Severity is DERIVED here, from `alert_type`. The backend's alert payload has
 * no severity field — do not read these tones as something the API returned.
 *
 * The colour comes from the shared state map: low fuel is the fleet's "alerta",
 * so it wears the same amber it does on the dashboard, the tables and the live
 * feed.
 */
export const ALERT_TONES: Record<AlertType, AlertTone> = {
  low_fuel: {
    label: "Combustible bajo",
    icon: Fuel,
    chip: STATUS_TONE.alert.soft,
    badge: STATUS_TONE.alert.variant,
  },
};

/**
 * A backend alert read as a `FleetAlert`, so the shared alert lists render one
 * shape instead of branching on where the alert came from. Admins get real
 * server-issued alerts and everyone else gets the client-derived ones; to the
 * notifications menu that difference is not interesting.
 *
 * Severity is fixed at "warning": every server alert is a low-fuel alert, and
 * the payload carries no severity field to say otherwise.
 *
 * `deviceName` is optional because the payload does not carry it: the alerts
 * screen renders the vehicle in its own column, while the compact lists have
 * one line for everything and need it folded into the detail. A caller with no
 * device list falls back to the bare message rather than printing a uuid.
 */
export function toFleetAlert(alert: Alert, deviceName?: string): FleetAlert {
  return {
    id: alert.id,
    level: "warning",
    title: ALERT_TONES[alert.alert_type].label,
    detail: deviceName ? `${deviceName} · ${alert.message}` : alert.message,
    deviceId: alert.device_id,
    at: alert.created_at,
  };
}
