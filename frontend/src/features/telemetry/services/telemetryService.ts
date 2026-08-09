import { apiClient } from "@/lib/api/client";
import type { TelemetryReading } from "../types/telemetry";

interface TelemetryQuery {
  deviceId?: string;
  limit?: number;
}

export function listTelemetry({
  deviceId,
  limit = 100,
}: TelemetryQuery = {}): Promise<TelemetryReading[]> {
  const params = new URLSearchParams({ limit: String(limit) });
  if (deviceId) params.set("device_id", deviceId);
  return apiClient
    .get<TelemetryReading[]>(`/telemetry?${params.toString()}`)
    .then((res) => res.data);
}

interface TelemetryCountQuery {
  deviceId?: string;
  /** ISO datetimes. Omitted means "everything ever recorded". */
  startDate?: string;
  endDate?: string;
}

/** How many readings match — the whole set, not a page of it.
 *
 *  `listTelemetry(...).length` cannot answer this: it is capped by `limit`, so
 *  counting its rows reports the page size back and stops moving the moment
 *  the fleet reports more than one page. */
export function countTelemetry({
  deviceId,
  startDate,
  endDate,
}: TelemetryCountQuery = {}): Promise<number> {
  const params = new URLSearchParams();
  if (deviceId) params.set("device_id", deviceId);
  if (startDate) params.set("start_date", startDate);
  if (endDate) params.set("end_date", endDate);

  const query = params.toString();
  return apiClient
    .get<{ count: number }>(`/telemetry/count${query ? `?${query}` : ""}`)
    .then((res) => res.data.count);
}

/** Current state of the fleet: the latest reading of every device that ever
 *  reported, however old. No limit — the backend bounds it by device count. */
export function listLatestReadings(): Promise<TelemetryReading[]> {
  return apiClient
    .get<TelemetryReading[]>("/telemetry/latest")
    .then((res) => res.data);
}

interface DeviceHistoryQuery {
  limit?: number;
  /** ISO datetimes; omitted params let the backend fall back to "latest N". */
  startDate?: string;
  endDate?: string;
}

/** Default limit sits well above the list default because a multi-day range at
 *  one reading per minute would otherwise be cut to the last 100 points — the
 *  chart would silently show hours of a range the user asked days for. */
export function getDeviceHistory(
  deviceId: string,
  { limit = 500, startDate, endDate }: DeviceHistoryQuery = {},
): Promise<TelemetryReading[]> {
  const params = new URLSearchParams({ limit: String(limit) });
  if (startDate) params.set("start_date", startDate);
  if (endDate) params.set("end_date", endDate);
  return apiClient
    .get<TelemetryReading[]>(`/telemetry/${deviceId}/history?${params.toString()}`)
    .then((res) => res.data);
}
