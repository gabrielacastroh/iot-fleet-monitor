import { useQuery } from "@tanstack/react-query";
import { rangeFromDays } from "@/lib/fleet";
import {
  countTelemetry,
  listLatestReadings,
  listTelemetry,
} from "../services/telemetryService";

const TELEMETRY_LIMIT = 200;

/** Window the "telemetry received" counter reports on. A running total would
 *  climb into the millions and stop saying anything about today; a day is the
 *  span an operator actually compares against yesterday. */
const COUNT_WINDOW_DAYS = 1;

/** Recent fleet activity: the newest readings across every device, mixed. What
 *  the live feed and the trend charts read — a rolling window is exactly the
 *  right shape for "what just happened".
 *
 *  It is the wrong shape for "what is each vehicle at right now": the limit is
 *  fleet-wide, so devices compete for the same 200 slots and a quiet one drops
 *  out entirely. Use `useLatestTelemetry` for per-device state. */
export function useTelemetryQuery() {
  return useQuery({
    queryKey: ["telemetry"],
    queryFn: () => listTelemetry({ limit: TELEMETRY_LIMIT }),
  });
}

/** How much telemetry arrived in the last day.
 *
 *  Asked of the backend instead of measured on `useTelemetryQuery`'s data: that
 *  list is a 200-row window, so its length is the window size, not a count —
 *  it reads 200 forever once the fleet has reported more than that.
 *
 *  The window start is snapped to the minute by `rangeFromDays`, so the key is
 *  stable for a minute and the query refetches as the window slides. Live
 *  readings are added by the socket in between. */
export function useTelemetryCount() {
  const { startDate } = rangeFromDays(COUNT_WINDOW_DAYS);
  return useQuery({
    queryKey: ["telemetry", "count", startDate],
    queryFn: () => countTelemetry({ startDate }),
  });
}

/** One reading per device — the fleet's current state. Bounded by how many
 *  devices exist, not by how much telemetry piled up, so it stays correct as
 *  the table grows. Devices that never reported are absent, which the UI reads
 *  as "sin datos" and must stay distinct from "reported a while ago". */
export function useLatestTelemetry() {
  return useQuery({
    queryKey: ["telemetry", "latest"],
    queryFn: listLatestReadings,
  });
}
