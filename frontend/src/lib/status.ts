/**
 * The fleet's five states, in one place.
 *
 * A state has to look the same on every screen — the badge in a table, the dot
 * in the alert list, the chip behind an alert icon and the fill of a signal bar
 * are all the same vocabulary, and before this they each picked their own
 * classes. `DeviceStatusBadge` renders the device-facing subset; everything
 * that needs only a colour reads the tokens here instead of hardcoding one.
 *
 * Colour convention: active = green, no signal / alert = amber, critical = red,
 * inactive = grey. Only tokens from src/index.css.
 */
import type { AlertLevel } from "@/lib/fleet";

export type FleetStatus = "active" | "inactive" | "noSignal" | "alert" | "critical";

export interface StatusTone {
  label: string;
  /** Badge variant — the only place a fleet state picks its colour. */
  variant: "success" | "neutral" | "warning" | "danger";
  /** Solid fill: status dots and meter bars. */
  dot: string;
  /** Tinted surface + matching text: icon chips. */
  soft: string;
}

export const STATUS_TONE: Record<FleetStatus, StatusTone> = {
  active: {
    label: "Activo",
    variant: "success",
    dot: "bg-success",
    soft: "bg-success-soft text-success",
  },
  inactive: {
    label: "Inactivo",
    variant: "neutral",
    dot: "bg-muted-foreground",
    soft: "bg-secondary text-muted-foreground",
  },
  noSignal: {
    label: "Sin señal",
    variant: "warning",
    dot: "bg-warning",
    soft: "bg-warning-soft text-warning",
  },
  alert: {
    label: "Alerta",
    variant: "warning",
    dot: "bg-warning",
    soft: "bg-warning-soft text-warning",
  },
  critical: {
    label: "Crítico",
    variant: "danger",
    dot: "bg-destructive",
    soft: "bg-destructive-soft text-destructive",
  },
};

/**
 * Severity as a single coloured dot, for the lists too narrow to spend width on
 * an icon chip — the dashboard's alert panel and the top bar's notifications
 * menu. Both read this map, so a red dot in the bell means what a red dot on
 * the dashboard means. `info` is only ever the registered-but-silent alert,
 * which is the fleet's "sin señal".
 */
export const ALERT_LEVEL_DOT: Record<AlertLevel, string> = {
  danger: STATUS_TONE.critical.dot,
  warning: STATUS_TONE.alert.dot,
  info: STATUS_TONE.noSignal.dot,
};
