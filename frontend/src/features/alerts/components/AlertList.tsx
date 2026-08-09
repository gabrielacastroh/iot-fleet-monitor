import { Link } from "react-router-dom";
import { BellOff, Check, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { timeAgo } from "@/lib/fleet";
import { STATUS_TONE } from "@/lib/status";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/app/routes";
import { ALERT_TONES } from "./alertTone";
import type { Alert } from "../types/alert";

interface AlertListProps {
  alerts: Alert[];
  /** device_id → vehicle name, from the cached device list. */
  deviceNames: Map<string, string>;
  loading: boolean;
  /** Tells the empty state apart: "nothing matched" vs "nothing exists yet". */
  filtered: boolean;
  resolvingId: string | null;
  onResolve: (alert: Alert) => void;
}

export function AlertList({
  alerts,
  deviceNames,
  loading,
  filtered,
  resolvingId,
  onResolve,
}: AlertListProps) {
  if (loading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 5 }).map((_, index) => (
          <Skeleton key={index} className="h-22 rounded-2xl" />
        ))}
      </div>
    );
  }

  if (alerts.length === 0) {
    return (
      <Card>
        <CardContent className="flex flex-col items-center gap-2 py-16 text-center">
          <span className="flex size-12 items-center justify-center rounded-2xl bg-success-soft text-success">
            <BellOff className="size-5" aria-hidden />
          </span>
          <p className="text-sm font-medium">
            {filtered ? "Sin resultados" : "No hay alertas"}
          </p>
          <p className="max-w-sm text-sm text-muted-foreground">
            {filtered
              ? "Ninguna alerta coincide con los filtros seleccionados."
              : "El sistema todavía no generó alertas para esta flota."}
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <ul className="space-y-3">
      {alerts.map((alert) => (
        <li key={alert.id}>
          <AlertRow
            alert={alert}
            deviceName={deviceNames.get(alert.device_id)}
            resolving={resolvingId === alert.id}
            onResolve={onResolve}
          />
        </li>
      ))}
    </ul>
  );
}

function AlertRow({
  alert,
  deviceName,
  resolving,
  onResolve,
}: {
  alert: Alert;
  deviceName: string | undefined;
  resolving: boolean;
  onResolve: (alert: Alert) => void;
}) {
  const tone = ALERT_TONES[alert.alert_type];
  const Icon = tone.icon;

  return (
    <Card className={cn("py-4 shadow-[var(--shadow-soft)]", alert.is_resolved && "bg-card/60")}>
      <CardContent className="flex flex-wrap items-center gap-x-4 gap-y-3">
        <span
          className={cn(
            "flex size-10 shrink-0 items-center justify-center rounded-xl",
            alert.is_resolved ? "bg-secondary text-muted-foreground" : tone.chip,
          )}
        >
          <Icon className="size-4" aria-hidden />
        </span>

        <div className="min-w-0 flex-1 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <p
              className={cn(
                "text-sm font-medium",
                alert.is_resolved && "text-muted-foreground",
              )}
            >
              {alert.message}
            </p>
            <Badge variant={alert.is_resolved ? "neutral" : tone.badge}>{tone.label}</Badge>
          </div>
          <p className="truncate text-xs text-muted-foreground">
            {/* Alerts only carry device_id. A vehicle missing from the cached
                list (deleted, or a list that failed to load) gets a plain
                label instead of a raw uuid and a link that leads nowhere. */}
            {deviceName ? (
              <Link
                to={ROUTES.deviceDetail(alert.device_id)}
                className="font-medium text-foreground hover:underline"
              >
                {deviceName}
              </Link>
            ) : (
              "Vehículo no disponible"
            )}
            {" · "}
            {timeAgo(alert.created_at)}
          </p>
        </div>

        <div className="ml-auto flex shrink-0 items-center gap-3">
          {alert.is_resolved ? (
            <Badge variant="success">
              <Check aria-hidden />
              Resuelta
            </Badge>
          ) : (
            <>
              <Badge variant="outline">
                <span
                  className={cn("size-1.5 rounded-full", STATUS_TONE.critical.dot)}
                  aria-hidden
                />
                Pendiente
              </Badge>
              <Button
                variant="outline"
                size="sm"
                disabled={resolving}
                onClick={() => onResolve(alert)}
              >
                {resolving ? (
                  <Loader2 className="size-4 animate-spin" aria-hidden />
                ) : (
                  <Check className="size-4" aria-hidden />
                )}
                Resolver
              </Button>
            </>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
