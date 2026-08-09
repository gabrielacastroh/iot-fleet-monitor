import { useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  ArrowUpRight,
  Activity,
  AlertTriangle,
  Fuel,
  Gauge,
  Radio,
  Thermometer,
  Truck,
} from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { AlertsPanel } from "@/features/dashboard/components/AlertsPanel";
import { DeviceTable } from "@/features/dashboard/components/DeviceTable";
import { LazyFleetMap as FleetMap } from "@/features/dashboard/components/LazyFleetMap";
import { KpiCard } from "@/features/dashboard/components/KpiCard";
import { LiveTelemetryCard } from "@/features/telemetry/components/LiveTelemetryCard";
import { LazyMetricChart as MetricChart } from "@/features/telemetry/components/LazyMetricChart";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { useDashboardData } from "@/features/dashboard/hooks/useDashboardData";
import { useTelemetrySocket } from "@/features/telemetry/hooks/useTelemetrySocket";
import { buildSeries, HIGH_TEMP_THRESHOLD, LOW_FUEL_THRESHOLD } from "@/lib/fleet";
import { cn, isAdmin as getIsAdmin } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

/** The dashboard shows a shortlist, not the inventory — the full table lives
 *  on /devices and a second copy of it here only costs scroll. */
const RECENT_DEVICE_LIMIT = 6;

export function DashboardPage() {
  // The socket itself lives in the layout route; this screen only renders its
  // state.
  const connectionState = useTelemetrySocket();
  const navigate = useNavigate();
  const { data: user, isLoading: userLoading } = useCurrentUser();
  const isAdmin = getIsAdmin(user);
  const {
    devices,
    devicesLoading,
    devicesError,
    readings,
    telemetryLoading,
    telemetryCount,
    telemetryCountLoading,
    latest,
    alerts,
    alertsCount,
    alertsLoading,
  } = useDashboardData();

  const series = useMemo(() => buildSeries(readings), [readings]);

  const stats = useMemo(() => {
    // The averages cover the same vehicles the "activos" figure counts. Reading
    // every row of `latest` instead pulled decommissioned trucks into the fleet
    // average — /telemetry/latest returns the last reading of every device that
    // ever reported, and a vehicle taken out of service keeps its last one
    // forever.
    const activeIds = new Set(
      devices
        .filter((device) => device.is_active && device.last_seen_at != null)
        .map((device) => device.id),
    );
    const reported = [...latest.values()].filter((reading) =>
      activeIds.has(reading.device_id),
    );
    const avgFuel = reported.length
      ? Math.round(
          reported.reduce((sum, reading) => sum + reading.fuel_level, 0) /
            reported.length,
        )
      : null;
    const avgTemp = reported.length
      ? Math.round(
          reported.reduce((sum, reading) => sum + reading.temperature, 0) /
            reported.length,
        )
      : null;

    return { total: devices.length, active: activeIds.size, avgFuel, avgTemp };
  }, [devices, latest]);

  const loading = devicesLoading || telemetryLoading;

  // Shortlist criterion: anything with an open alert first, then whatever
  // reported most recently — the rows an operator would scan anyway.
  const recentDevices = useMemo(() => {
    const alerted = new Set(alerts.map((alert) => alert.deviceId));
    return [...devices]
      .sort((a, b) => {
        const byAlert = Number(alerted.has(b.id)) - Number(alerted.has(a.id));
        if (byAlert !== 0) return byAlert;
        return (b.last_seen_at ?? "").localeCompare(a.last_seen_at ?? "");
      })
      .slice(0, RECENT_DEVICE_LIMIT);
  }, [devices, alerts]);

  return (
    <>
      <PageHeader
        title="Dashboard"
        description="Actividad de la flota en tiempo real."
        actions={
          // Reserve the space while the role is unknown: a button that appears
          // a beat later shoves the header around.
          userLoading ? (
            <Skeleton className="h-10 w-44 rounded-xl" />
          ) : (
            isAdmin && (
              <Button asChild>
                <Link to={ROUTES.newDevice}>
                  <Truck className="size-4" aria-hidden />
                  Registrar vehículo
                </Link>
              </Button>
            )
          )
        }
      />

      <div className="space-y-5">
        {devicesError && (
          <Card className="border-destructive/25 bg-destructive-soft">
            <CardContent>
              <p role="alert" className="text-sm text-destructive">
                {devicesError}
              </p>
            </CardContent>
          </Card>
        )}

        <section
          aria-label="Indicadores de la flota"
          className={cn(
            "grid gap-4 sm:grid-cols-2 lg:grid-cols-3",
            // The alerts tile only exists for an admin, and a five-column track
            // with four tiles in it leaves a hole at the end of the row.
            isAdmin ? "xl:grid-cols-5" : "xl:grid-cols-4",
          )}
        >
          <KpiCard
            index={0}
            label="Vehículos activos"
            value={stats.active}
            icon={Activity}
            tone="success"
            loading={devicesLoading}
            hint={`de ${stats.total} en la flota`}
          />
          {/* The count, not `alerts.length`: the panel below renders a page of
              the feed, and a fleet with more open alerts than fit in one page
              would show the page size here as a total. */}
          {isAdmin && (
            <KpiCard
              index={1}
              label="Alertas activas"
              value={alertsCount}
              icon={AlertTriangle}
              tone={alertsCount > 0 ? "danger" : "success"}
              loading={alertsLoading}
              hint={alertsCount > 0 ? "requieren atención" : "todo en orden"}
            />
          )}
          <KpiCard
            index={2}
            label="Telemetrías recibidas"
            value={telemetryCount}
            icon={Radio}
            tone="primary"
            loading={telemetryCountLoading}
            hint="últimas 24 h"
          />
          <KpiCard
            index={3}
            label="Combustible promedio"
            value={stats.avgFuel ?? "—"}
            unit={stats.avgFuel == null ? undefined : "%"}
            icon={Fuel}
            tone={
              stats.avgFuel != null && stats.avgFuel <= LOW_FUEL_THRESHOLD
                ? "danger"
                : "success"
            }
            loading={loading}
            hint="última lectura"
          />
          <KpiCard
            index={4}
            label="Temperatura promedio"
            value={stats.avgTemp ?? "—"}
            unit={stats.avgTemp == null ? undefined : "°C"}
            icon={Thermometer}
            tone={
              stats.avgTemp != null && stats.avgTemp > HIGH_TEMP_THRESHOLD
                ? "danger"
                : "success"
            }
            loading={loading}
            hint="última lectura"
          />
        </section>

        {/* Map and alerts share the fold: where the fleet is, and what needs
            attention right now. Everything below is context for those two.
            Alerts are admin-only, so for everyone else the map takes the whole
            width instead of leaving a column the reader may not be shown. */}
        <div
          className={cn(
            "grid grid-cols-1 gap-4",
            isAdmin && "xl:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)]",
          )}
        >
          <FleetMap
            devices={devices}
            latest={latest}
            loading={loading}
            expandHref={ROUTES.map}
          />
          {isAdmin && (
            <AlertsPanel alerts={alerts} loading={alertsLoading} viewAllHref={ROUTES.alerts} />
          )}
        </div>

        <div className="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]">
          <LiveTelemetryCard
            connectionState={connectionState}
            readings={readings}
            devices={devices}
          />

          {/* Tabs instead of two stacked charts: an operator compares one
              metric at a time, and side-by-side charts cost a whole viewport
              of height for a comparison nobody makes. */}
          {/* The stretch chain — section, Tabs, TabsContent — hands the grid
              row's height down to the chart card so it ends flush with the
              live feed beside it. */}
          <section aria-label="Métricas de la flota" className="flex flex-col">
            <Tabs defaultValue="speed" className="min-h-0 flex-1 gap-3">
              <TabsList>
                <TabsTrigger value="speed">
                  <Gauge className="size-4" aria-hidden />
                  Velocidad
                </TabsTrigger>
                <TabsTrigger value="fuel">
                  <Fuel className="size-4" aria-hidden />
                  Combustible
                </TabsTrigger>
              </TabsList>
              <TabsContent value="speed" className="min-h-0 flex-1">
                <MetricChart
                  compact
                  title="Velocidad"
                  description="Lecturas más recientes de la flota."
                  data={series}
                  dataKey="speed"
                  unit=" km/h"
                  color="var(--primary)"
                  loading={telemetryLoading}
                />
              </TabsContent>
              <TabsContent value="fuel" className="min-h-0 flex-1">
                <MetricChart
                  compact
                  title="Combustible"
                  description="Nivel reportado por los equipos."
                  data={series}
                  dataKey="fuel"
                  unit="%"
                  color="var(--success)"
                  loading={telemetryLoading}
                  domainMax={100}
                />
              </TabsContent>
            </Tabs>
          </section>
        </div>

        <section aria-label="Vehículos con actividad reciente" className="space-y-3">
          <div className="flex items-center justify-between gap-3">
            <div className="min-w-0">
              <h2 className="text-base font-semibold">Actividad reciente</h2>
              <p className="text-sm text-muted-foreground">
                Vehículos con alertas abiertas o última señal más reciente.
              </p>
            </div>
            <Button variant="ghost" size="sm" asChild>
              <Link to={ROUTES.devices}>
                Ver todos los vehículos
                <ArrowUpRight className="size-3.5" aria-hidden />
              </Link>
            </Button>
          </div>

          {/* Rows navigate straight to the vehicle's page — the dashboard no
              longer carries a detail pane, so there is nothing to select. */}
          <DeviceTable
            devices={recentDevices}
            latest={latest}
            loading={devicesLoading}
            onSelect={(device) => navigate(ROUTES.deviceDetail(device.id))}
            isAdmin={isAdmin}
          />
        </section>
      </div>
    </>
  );
}
