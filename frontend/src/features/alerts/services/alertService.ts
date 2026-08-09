import { apiClient } from "@/lib/api/client";
import type { Alert, AlertType } from "../types/alert";

export interface AlertFilters {
  alertType?: AlertType;
  isResolved?: boolean;
  deviceId?: string;
  limit?: number;
}

export function listAlerts({
  alertType,
  isResolved,
  deviceId,
  limit,
}: AlertFilters = {}): Promise<Alert[]> {
  const params = new URLSearchParams();
  if (alertType) params.set("alert_type", alertType);
  // `false` is a filter ("only pending"), not an absent one — so the check is
  // against undefined and never against falsiness.
  if (isResolved !== undefined) params.set("is_resolved", String(isResolved));
  if (deviceId) params.set("device_id", deviceId);
  if (limit !== undefined) params.set("limit", String(limit));

  const query = params.toString();
  return apiClient
    .get<Alert[]>(`/alerts${query ? `?${query}` : ""}`)
    .then((res) => res.data);
}

/** How many alerts match — the whole set, not a page of it.
 *
 *  `listAlerts(...).length` cannot answer this: the backend caps the listing at
 *  its page size, so a counter built on it freezes at that number once the
 *  fleet has more open alerts than one page. */
export function countAlerts({
  alertType,
  isResolved,
  deviceId,
}: Omit<AlertFilters, "limit"> = {}): Promise<number> {
  const params = new URLSearchParams();
  if (alertType) params.set("alert_type", alertType);
  if (isResolved !== undefined) params.set("is_resolved", String(isResolved));
  if (deviceId) params.set("device_id", deviceId);

  const query = params.toString();
  return apiClient
    .get<{ count: number }>(`/alerts/count${query ? `?${query}` : ""}`)
    .then((res) => res.data.count);
}

export function resolveAlert(alertId: string): Promise<Alert> {
  return apiClient.patch<Alert>(`/alerts/${alertId}/resolve`).then((res) => res.data);
}
