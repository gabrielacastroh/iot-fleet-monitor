import { useQuery } from "@tanstack/react-query";
import { getDeviceHistory } from "../services/telemetryService";

interface HistoryQuery {
  limit?: number;
  startDate?: string;
  endDate?: string;
}

/** History for one device. The query is part of the key so switching the range
 *  refetches and each range stays cached on its own. */
export function useDeviceHistory(deviceId: string | undefined, query?: HistoryQuery) {
  return useQuery({
    queryKey: [
      "telemetry",
      "history",
      deviceId,
      query?.startDate,
      query?.endDate,
      query?.limit,
    ],
    // `enabled` guarantees deviceId is defined by the time this runs.
    queryFn: () => getDeviceHistory(deviceId as string, query),
    enabled: Boolean(deviceId),
  });
}
