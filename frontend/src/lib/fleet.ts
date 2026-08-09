import type { Device } from "@/features/devices/types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";

export const LOW_FUEL_THRESHOLD = 20;
/** Fuel at or below this is "danger" rather than merely "low" — the more
 *  urgent tier inside `LOW_FUEL_THRESHOLD`. */
export const CRITICAL_FUEL_THRESHOLD = 10;
export const SPEED_LIMIT = 110;

/** The simulator's default fleet center, used before any device has reported
 *  a position yet. Shared by every map that needs somewhere to point the
 *  camera before real coordinates arrive. */
export const DEFAULT_FLEET_CENTER: [number, number] = [-74.05, 4.65];
/** No backend-defined threshold exists yet — a reasonable local default, kept
 *  next to the other fleet limits so the dashboard and the live feed agree. */
export const HIGH_TEMP_THRESHOLD = 90;

/** Latest reading per device. The API returns newest first, so the first hit
 *  for a device id wins. */
export function latestByDevice(
  readings: TelemetryReading[],
): Map<string, TelemetryReading> {
  const latest = new Map<string, TelemetryReading>();
  for (const reading of readings) {
    const current = latest.get(reading.device_id);
    if (!current || reading.recorded_at > current.recorded_at) {
      latest.set(reading.device_id, reading);
    }
  }
  return latest;
}

export interface SeriesPoint {
  time: string;
  speed: number;
  fuel: number;
  temperature: number;
}

/** Chronological series for the charts, capped to the most recent `points`. */
export function buildSeries(readings: TelemetryReading[], points = 24): SeriesPoint[] {
  const window = [...readings]
    .sort((a, b) => a.recorded_at.localeCompare(b.recorded_at))
    .slice(-points);

  // "14:30" on its own collapses two different days onto the same label once a
  // range spans more than one. The span is read from the window itself instead
  // of asking every caller for a flag it would have to keep in sync.
  const first = window.at(0);
  const last = window.at(-1);
  const spansDays =
    !!first &&
    !!last &&
    new Date(first.recorded_at).toDateString() !==
      new Date(last.recorded_at).toDateString();

  return window.map((reading) => {
    const at = new Date(reading.recorded_at);
    const time = at.toLocaleTimeString("es", { hour: "2-digit", minute: "2-digit" });
    return {
      time: spansDays
        ? `${at.toLocaleDateString("es", { day: "2-digit", month: "short" })} ${time}`
        : time,
      speed: Math.round(reading.speed),
      fuel: Math.round(reading.fuel_level),
      temperature: Math.round(reading.temperature),
    };
  });
}

export interface DateRange {
  /** ISO datetimes in UTC — the backend stores `recorded_at` timezone-aware. */
  startDate: string;
  endDate: string;
}

export const DEFAULT_RANGE_DAYS = 7;

/** Range ending now, `days` back.
 *
 *  The end is snapped up to the next minute: at millisecond precision every
 *  call mints a different ISO string for what is the same logical range, so
 *  the query key changes on each render and refetches instead of hitting the
 *  cache. Rounding *up* means the snap can never cut off a reading that just
 *  arrived. */
export function rangeFromDays(days: number): DateRange {
  const end = Math.ceil(Date.now() / 60_000) * 60_000;
  return {
    startDate: new Date(end - days * 86_400_000).toISOString(),
    endDate: new Date(end).toISOString(),
  };
}

export type AlertLevel = "danger" | "warning" | "info";

export interface FleetAlert {
  id: string;
  level: AlertLevel;
  title: string;
  detail: string;
  deviceId: string;
  at: string | null;
}

/**
 * Alerts are derived from the data the backend already has — there is no
 * alerts endpoint yet, and inventing one client-side that looks like a server
 * feed would be a lie about where the numbers come from.
 */
export function deriveAlerts(
  devices: Device[],
  latest: Map<string, TelemetryReading>,
): FleetAlert[] {
  const alerts: FleetAlert[] = [];

  for (const device of devices) {
    const reading = latest.get(device.id);

    if (reading && reading.fuel_level <= LOW_FUEL_THRESHOLD) {
      alerts.push({
        id: `${device.id}-fuel`,
        level: reading.fuel_level <= 10 ? "danger" : "warning",
        title: "Combustible bajo",
        detail: `${device.vehicle_name} · ${Math.round(reading.fuel_level)}% restante`,
        deviceId: device.id,
        at: reading.recorded_at,
      });
    }

    if (reading && reading.speed > SPEED_LIMIT) {
      alerts.push({
        id: `${device.id}-speed`,
        level: "danger",
        title: "Exceso de velocidad",
        detail: `${device.vehicle_name} · ${Math.round(reading.speed)} km/h`,
        deviceId: device.id,
        at: reading.recorded_at,
      });
    }

    if (device.is_active && !device.last_seen_at) {
      alerts.push({
        id: `${device.id}-silent`,
        level: "info",
        title: "Sin señal",
        detail: `${device.vehicle_name} no ha reportado todavía`,
        deviceId: device.id,
        at: null,
      });
    }
  }

  const order: Record<AlertLevel, number> = { danger: 0, warning: 1, info: 2 };
  return alerts.sort((a, b) => order[a.level] - order[b.level]);
}

/** Relative time for feeds: "hace 3 min" beats a full timestamp when the
 *  reader only cares how fresh it is. */
export function timeAgo(value: string | null): string {
  if (!value) return "Sin datos";
  const diffMs = Date.now() - new Date(value).getTime();
  const minutes = Math.round(diffMs / 60_000);
  if (minutes < 1) return "Justo ahora";
  if (minutes < 60) return `Hace ${minutes} min`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `Hace ${hours} h`;
  return `Hace ${Math.round(hours / 24)} d`;
}
