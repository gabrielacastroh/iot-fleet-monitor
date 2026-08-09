import { useMemo } from "react";
import { useFleetAlerts } from "@/features/alerts/hooks/useFleetAlerts";
import { useDevices } from "@/features/devices/hooks/useDevices";
import {
  useLatestTelemetry,
  useTelemetryCount,
  useTelemetryQuery,
} from "@/features/telemetry/hooks/useTelemetryQuery";
import { latestByDevice } from "@/lib/fleet";

/**
 * Fleet data for a screen, composed from the devices and telemetry queries.
 * Shaped like the old `useFleetData` so the pages that consumed it (dashboard
 * and device list) barely change.
 */
export function useDashboardData() {
  const devicesQuery = useDevices();
  const telemetryQuery = useTelemetryQuery();
  const latestQuery = useLatestTelemetry();
  // A third question about telemetry: how much of it arrived. `readings.length`
  // is the window size (200), not an answer — it freezes there and never moves
  // again once the fleet has reported more than that.
  const countQuery = useTelemetryCount();

  const devices = useMemo(() => devicesQuery.data ?? [], [devicesQuery.data]);
  const readings = useMemo(() => telemetryQuery.data ?? [], [telemetryQuery.data]);

  // Two queries because these are two different questions. `readings` is the
  // rolling fleet-wide window the charts and the live feed plot; `latest` is
  // one row per device. Deriving the second from the first is what made a
  // vehicle silent for a few hours read as "sin datos" — its last reading was
  // real, just ranked past the window's cut by noisier devices.
  const latest = useMemo(
    () => latestByDevice(latestQuery.data ?? []),
    [latestQuery.data],
  );
  // The alerts screen's own feed, not a second reading of the telemetry: the
  // dashboard panel, its counter and the device list's "con alerta" filter all
  // have to be talking about the same vehicles /alerts is.
  const { alerts, count: alertsCount, loading: alertsLoading } = useFleetAlerts();

  // `isPending` ("nothing to show yet"), not `isLoading` ("a request is in
  // flight"): while the offline cache restores, and while a fetch waits for the
  // network to come back, nothing is in flight — `isLoading` would read false
  // with no data and flash "todavía no hay dispositivos" over a fleet that is
  // about to appear.
  return {
    devices,
    devicesLoading: devicesQuery.isPending,
    devicesError: devicesQuery.isError
      ? "No pudimos cargar los dispositivos. Inténtalo de nuevo."
      : null,
    readings,
    // Both, because the cells that render an em dash on "no reading" now read
    // from `latest`: if only the window query were watched, it would resolve
    // first and paint "—" over vehicles whose reading is still in flight.
    telemetryLoading: telemetryQuery.isPending || latestQuery.isPending,
    /** Readings recorded in the last day — a count, not `readings.length`. */
    telemetryCount: countQuery.data ?? 0,
    telemetryCountLoading: countQuery.isPending,
    latest,
    alerts,
    alertsCount,
    alertsLoading,
  };
}
