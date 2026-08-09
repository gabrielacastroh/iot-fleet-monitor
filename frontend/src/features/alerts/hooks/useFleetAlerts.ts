import { useMemo } from "react";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { useDevices } from "@/features/devices/hooks/useDevices";
import type { FleetAlert } from "@/lib/fleet";
import { isAdmin as getIsAdmin } from "@/lib/utils";
import { toFleetAlert } from "../components/alertTone";
import { useAlerts, useAlertsCount } from "./useAlerts";

/**
 * The one alert feed every screen outside /alerts reads: the dashboard panel,
 * its counter, the bell in the top bar and the "con alerta" filter on the
 * device list.
 *
 * It asks for exactly what /alerts asks for by default — `useAlerts({
 * isResolved: false })`, same query key, same cache entry — so the dashboard
 * cannot show a different set of vehicles than the alerts screen does.
 *
 * Alerts are an admin-only feature, so for anyone else this feed is empty and
 * its callers render nothing at all. There is deliberately no client-side
 * derivation from telemetry thresholds as a fallback: it would put an alert
 * list and a count in front of exactly the reader the backend refuses to send
 * alerts to, and it would be a second source of truth for what an alert is.
 */
export function useFleetAlerts(): {
  alerts: FleetAlert[];
  /** How many alerts are open, which is NOT `alerts.length`: that list is a
   *  page and the counter has to survive a fleet with more alerts than fit in
   *  one. Only the count is safe to display as a total. */
  count: number;
  loading: boolean;
  isFetching: boolean;
} {
  const { data: user, isLoading: userLoading } = useCurrentUser();
  const isAdmin = getIsAdmin(user);

  const devicesQuery = useDevices();
  // Pending only: the dashboard counts what still needs attention, which is
  // the same list /alerts opens on.
  const alertsQuery = useAlerts({ isResolved: false });
  // Same criteria, asked as a count: the panel renders a page of alerts, the
  // KPI reports how many there are. Two different questions about one feed.
  const countQuery = useAlertsCount({ isResolved: false });

  // Alerts only carry `device_id`; the cached device list supplies the names,
  // exactly as the alerts screen does it.
  const deviceNames = useMemo(
    () =>
      new Map(
        (devicesQuery.data ?? []).map((device) => [device.id, device.vehicle_name]),
      ),
    [devicesQuery.data],
  );

  const alerts = useMemo(
    () =>
      isAdmin
        ? // Newest first, which is the order the backend returns them in —
          // whatever slices this list gets the most recent alerts.
          (alertsQuery.data ?? []).map((alert) =>
            toFleetAlert(alert, deviceNames.get(alert.device_id)),
          )
        : [],
    [isAdmin, alertsQuery.data, deviceNames],
  );

  return {
    alerts,
    // Falling back to the page length while the count is in flight keeps the
    // KPI from flashing a zero.
    count: isAdmin ? (countQuery.data ?? alerts.length) : 0,
    // Both alert queries stay disabled for a non-admin, so their `isPending`
    // never resolves — only the role lookup can leave this hook loading.
    loading:
      userLoading || (isAdmin && (alertsQuery.isPending || countQuery.isPending)),
    isFetching: alertsQuery.isFetching || countQuery.isFetching,
  };
}
