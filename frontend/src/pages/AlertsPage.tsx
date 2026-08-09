import { useMemo, useState } from "react";
import { toast } from "sonner";
import { AlertCircle } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { AlertList } from "@/features/alerts/components/AlertList";
import { useAlerts, useResolveAlert } from "@/features/alerts/hooks/useAlerts";
import { useDevices } from "@/features/devices/hooks/useDevices";
import type { Alert } from "@/features/alerts/types/alert";

type StatusFilter = "pending" | "resolved" | "all";

export function AlertsPage() {
  // No filter by type: the backend raises one kind of alert, so a type tab
  // would be a control with a single meaningful position.
  const [status, setStatus] = useState<StatusFilter>("pending");

  // `isPending` covers the two states where there is nothing to show and
  // nothing in flight either — the offline cache restoring, and a fetch paused
  // waiting for the network — which `isLoading` reports as "not loading".
  const {
    data: alerts = [],
    isPending,
    isError,
  } = useAlerts({
    isResolved: status === "all" ? undefined : status === "resolved",
  });

  // Alerts only carry device_id; the cached device list supplies the names.
  const { data: devices = [] } = useDevices();
  const deviceNames = useMemo(
    () => new Map(devices.map((device) => [device.id, device.vehicle_name])),
    [devices],
  );

  const resolveMutation = useResolveAlert();

  async function handleResolve(alert: Alert) {
    try {
      await resolveMutation.mutateAsync(alert.id);
      toast.success("Alerta resuelta", {
        description: alert.message,
      });
    } catch {
      toast.error("No pudimos resolver la alerta", {
        description: "Es posible que ya no exista. Actualiza e inténtalo de nuevo.",
      });
    }
  }

  return (
    <>
      <PageHeader
        title="Alertas predictivas"
        description="Alertas generadas por el backend a partir de la telemetría de la flota."
      />

      <div className="space-y-5">
        <div className="flex flex-wrap items-center gap-3">
          <Tabs
            value={status}
            onValueChange={(value) => setStatus(value as StatusFilter)}
          >
            <TabsList>
              <TabsTrigger value="pending">Pendientes</TabsTrigger>
              <TabsTrigger value="resolved">Resueltas</TabsTrigger>
              <TabsTrigger value="all">Todas</TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        {isError ? (
          <Card className="border-destructive/25 bg-destructive-soft">
            <CardContent>
              <p role="alert" className="flex items-start gap-2 text-sm text-destructive">
                <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden />
                No pudimos cargar las alertas. Inténtalo de nuevo en unos segundos.
              </p>
            </CardContent>
          </Card>
        ) : (
          <>
            <p className="eyebrow" aria-live="polite">
              {alerts.length} {alerts.length === 1 ? "alerta" : "alertas"}
            </p>

            <AlertList
              alerts={alerts}
              deviceNames={deviceNames}
              loading={isPending}
              filtered={status !== "all"}
              resolvingId={resolveMutation.isPending ? resolveMutation.variables : null}
              onResolve={(alert) => void handleResolve(alert)}
            />
          </>
        )}
      </div>
    </>
  );
}
