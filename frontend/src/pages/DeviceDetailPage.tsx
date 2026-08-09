import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";
import {
  AlertCircle,
  CalendarClock,
  Fuel,
  Gauge,
  Hash,
  Loader2,
  Pencil,
  SatelliteDish,
  ScanLine,
  Thermometer,
  Trash2,
  Truck,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { AlertsPanel } from "@/features/dashboard/components/AlertsPanel";
import { LazyMetricChart as MetricChart } from "@/features/telemetry/components/LazyMetricChart";
import { LazyVehicleRouteMap as VehicleRouteMap } from "@/features/telemetry/components/LazyVehicleRouteMap";
import { DateRangePicker } from "@/features/telemetry/components/DateRangePicker";
import { useDeviceHistory } from "@/features/telemetry/hooks/useDeviceHistory";
import { DeviceStatusBadge } from "@/features/devices/components/DeviceStatusBadge";
import { FuelGauge } from "@/features/devices/components/VehicleCard";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAlerts } from "@/features/alerts/hooks/useAlerts";
import { toFleetAlert } from "@/features/alerts/components/alertTone";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { useDeleteDevice } from "@/features/devices/hooks/useDevices";
import { useDeviceDetail } from "@/features/devices/hooks/useDeviceDetail";
import { DEFAULT_RANGE_DAYS, buildSeries, rangeFromDays, timeAgo } from "@/lib/fleet";
import type { DateRange } from "@/lib/fleet";
import { formatDateTime, isAdmin as getIsAdmin } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

export function DeviceDetailPage() {
  const { deviceId } = useParams<{ deviceId: string }>();
  const { data: user, isLoading: userLoading } = useCurrentUser();
  const isAdmin = getIsAdmin(user);
  const navigate = useNavigate();
  const deleteDeviceMutation = useDeleteDevice();

  // Cache-first: the list already in memory paints the header and the tiles on
  // the first frame, and the request that follows only refreshes them. The
  // skeleton is left for the case where we genuinely hold nothing — a deep
  // link or a hard reload.
  const { device, error } = useDeviceDetail(deviceId);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [range, setRange] = useState<DateRange>(() => rangeFromDays(DEFAULT_RANGE_DAYS));

  const {
    data: history = [],
    isPending: historyLoading,
    isError: historyFailed,
  } = useDeviceHistory(deviceId, range);

  // The summary tiles want "the last thing this device said", which is a
  // different question from "what it said inside the chart range" — a
  // vehicle silent for longer than the range would otherwise read as if it
  // had never reported at all.
  const { data: latestPage = [] } = useDeviceHistory(deviceId, { limit: 1 });
  const latestReading = latestPage.at(0);

  // A multi-day range carries far more than the dashboard's 24 points, and
  // cutting it back down would hide most of what the user just asked for.
  const series = useMemo(() => buildSeries(history, 500), [history]);
  // The real, backend-issued feed — same source every other alert surface in
  // the app reads from — scoped to this device instead of the whole fleet.
  // `useAlerts` already gates itself to admins internally.
  const { data: deviceAlerts = [], isPending: alertsLoading } = useAlerts({
    deviceId,
    isResolved: false,
  });
  const alerts = useMemo(
    () =>
      isAdmin
        ? deviceAlerts.map((alert) => toFleetAlert(alert, device?.vehicle_name))
        : [],
    [isAdmin, deviceAlerts, device?.vehicle_name],
  );

  async function handleDelete() {
    if (!device) return;

    try {
      await deleteDeviceMutation.mutateAsync(device.id);
      toast.success("Dispositivo eliminado", {
        description: `${device.vehicle_name} ya no forma parte de la flota.`,
      });
      navigate(ROUTES.devices, { replace: true });
    } catch {
      setConfirmingDelete(false);
      toast.error("No pudimos eliminar el dispositivo", {
        description: "Revisa tu conexión e inténtalo de nuevo.",
      });
    }
  }

  return (
    <>
      <PageHeader
        backTo={ROUTES.devices}
        backLabel="Dispositivos"
        title={device?.vehicle_name ?? "Detalle del dispositivo"}
        description={
          device ? `${device.device_code} · ${device.plate}` : "Ficha del equipo IoT."
        }
        actions={
          // Reserve the space while the role is unknown: buttons that appear a
          // beat later shove the header around.
          userLoading ? (
            <Skeleton className="h-10 w-44 rounded-xl" />
          ) : (
            isAdmin &&
            device && (
              <>
                <Button variant="outline" asChild>
                  <Link to={ROUTES.deviceEdit(device.id)}>
                    <Pencil className="size-4" aria-hidden />
                    Editar
                  </Link>
                </Button>
                <Button
                  variant="ghost"
                  className="text-destructive hover:bg-destructive-soft hover:text-destructive"
                  onClick={() => setConfirmingDelete(true)}
                  disabled={deleteDeviceMutation.isPending}
                >
                  {deleteDeviceMutation.isPending ? (
                    <Loader2 className="size-4 animate-spin" aria-hidden />
                  ) : (
                    <Trash2 className="size-4" aria-hidden />
                  )}
                  Eliminar
                </Button>
              </>
            )
          )
        }
      />

      {error ? (
        <Card className="border-destructive/25 bg-destructive-soft">
          <CardContent>
            <p role="alert" className="flex items-start gap-2 text-sm text-destructive">
              <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
              {error}
            </p>
          </CardContent>
        </Card>
      ) : device === null ? (
        <div className="space-y-4">
          <Skeleton className="h-28 rounded-2xl" />
          <div className="grid gap-4 lg:grid-cols-2">
            <Skeleton className="h-72 rounded-2xl" />
            <Skeleton className="h-72 rounded-2xl" />
          </div>
        </div>
      ) : (
        <Tabs defaultValue="resumen" className="gap-6">
          <TabsList>
            <TabsTrigger value="resumen">Resumen</TabsTrigger>
            <TabsTrigger value="telemetria">Telemetría</TabsTrigger>
            {isAdmin && (
              <TabsTrigger value="alertas">
                Alertas
                {alerts.length > 0 && (
                  <span className="ml-1 rounded-full bg-destructive-soft px-1.5 text-xs font-medium text-destructive">
                    {alerts.length}
                  </span>
                )}
              </TabsTrigger>
            )}
          </TabsList>

          <TabsContent value="resumen" className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <StatTile
                icon={SatelliteDish}
                label="Última señal"
                value={timeAgo(device.last_seen_at)}
              />
              <StatTile
                icon={Gauge}
                label="Velocidad"
                value={
                  latestReading ? `${Math.round(latestReading.speed)} km/h` : "Sin datos"
                }
              />
              <StatTile
                icon={Thermometer}
                label="Temperatura"
                value={
                  latestReading
                    ? `${Math.round(latestReading.temperature)} °C`
                    : "Sin datos"
                }
              />
              <StatTile
                icon={Fuel}
                label="Combustible"
                value={
                  latestReading
                    ? `${Math.round(latestReading.fuel_level)} %`
                    : "Sin datos"
                }
              />
            </div>

            <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem]">
              <Card>
                <CardHeader>
                  <CardTitle>Ficha del vehículo</CardTitle>
                </CardHeader>
                <CardContent>
                  <dl className="divide-y">
                    <DetailRow icon={Truck} label="Vehículo" value={device.vehicle_name} />
                    <DetailRow icon={Hash} label="Código" value={device.device_code} mono />
                    <DetailRow icon={ScanLine} label="Placa" value={device.plate} mono />
                    <DetailRow
                      icon={CalendarClock}
                      label="Registrado"
                      value={formatDateTime(device.created_at)}
                    />
                  </dl>
                </CardContent>
              </Card>

              <Card className="h-fit">
                <CardHeader className="flex-row items-center justify-between">
                  <CardTitle>Estado</CardTitle>
                  <DeviceStatusBadge
                    isActive={device.is_active}
                    lastSeenAt={device.last_seen_at}
                  />
                </CardHeader>
                <CardContent className="space-y-4">
                  <FuelGauge level={latestReading?.fuel_level} />
                  <p className="text-xs leading-relaxed text-muted-foreground">
                    {device.is_active
                      ? "El equipo está activo y se considera en el monitoreo de la flota."
                      : "El equipo está inactivo: sigue registrado pero queda fuera del monitoreo."}
                  </p>
                  <div className="space-y-1 border-t pt-4">
                    <p className="eyebrow">Identificador</p>
                    <p className="font-mono text-xs break-all text-muted-foreground">
                      {device.id}
                    </p>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="telemetria" className="space-y-4">
            <DateRangePicker value={range} onChange={setRange} />

            {historyFailed ? (
              <Card className="border-destructive/25 bg-destructive-soft">
                <CardContent>
                  <p
                    role="alert"
                    className="flex items-start gap-2 text-sm text-destructive"
                  >
                    <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
                    No pudimos cargar el historial de este rango. Inténtalo de nuevo.
                  </p>
                </CardContent>
              </Card>
            ) : (
              <>
                <VehicleRouteMap
                  history={history}
                  current={latestReading}
                  loading={historyLoading}
                />

                {!historyLoading && series.length === 0 && (
                  <Card>
                    <CardContent>
                      {/* Named explicitly so the empty charts read as "nothing in
                          this range" and not "this vehicle never reported". */}
                      <p className="text-sm text-muted-foreground">
                        Este equipo no registró lecturas en el rango seleccionado. Prueba
                        con un rango más amplio.
                      </p>
                    </CardContent>
                  </Card>
                )}

                {/* Speed and fuel pair up on top; temperature takes the full
                    width below so three charts never leave a dead cell. */}
                <div className="grid gap-4 lg:grid-cols-2">
                  <MetricChart
                    title="Velocidad"
                    description="Historial reportado por este equipo."
                    data={series}
                    dataKey="speed"
                    unit=" km/h"
                    color="var(--primary)"
                    loading={historyLoading}
                  />
                  <MetricChart
                    title="Combustible"
                    description="Nivel reportado por este equipo."
                    data={series}
                    dataKey="fuel"
                    unit="%"
                    color="var(--success)"
                    loading={historyLoading}
                    domainMax={100}
                  />
                </div>
                <MetricChart
                  title="Temperatura"
                  description="Temperatura reportada por este equipo."
                  data={series}
                  dataKey="temperature"
                  unit=" °C"
                  color="var(--warning)"
                  loading={historyLoading}
                />
              </>
            )}
          </TabsContent>

          {isAdmin && (
            <TabsContent value="alertas">
              <AlertsPanel alerts={alerts} loading={alertsLoading} />
            </TabsContent>
          )}
        </Tabs>
      )}

      <ConfirmDialog
        open={confirmingDelete}
        title="Eliminar dispositivo"
        description={`Se eliminará "${device?.vehicle_name ?? ""}" junto con su telemetría y sus alertas. Esta acción no se puede deshacer.`}
        isPending={deleteDeviceMutation.isPending}
        onConfirm={() => void handleDelete()}
        onCancel={() => setConfirmingDelete(false)}
      />
    </>
  );
}

function StatTile({
  icon: Icon,
  label,
  value,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
}) {
  return (
    // Same box as the dashboard's KpiCard: both are "icon chip + label +
    // figure", and they were 24px and 20px tall for no reason anyone could see.
    <Card className="gap-0 py-4">
      <CardContent className="flex items-center gap-3 px-4">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-secondary text-muted-foreground">
          <Icon className="size-4" aria-hidden />
        </span>
        <span className="min-w-0">
          <span className="eyebrow block">{label}</span>
          <span className="block truncate text-sm font-medium tabular">{value}</span>
        </span>
      </CardContent>
    </Card>
  );
}

function DetailRow({
  icon: Icon,
  label,
  value,
  mono = false,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
      <dt className="flex items-center gap-2 text-sm text-muted-foreground">
        <Icon className="size-4" aria-hidden />
        {label}
      </dt>
      <dd className={mono ? "font-mono text-xs font-medium" : "text-sm font-medium"}>
        {value}
      </dd>
    </div>
  );
}
