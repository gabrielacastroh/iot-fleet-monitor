import { Link } from "react-router-dom";
import { ArrowUpRight, BellOff } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { timeAgo } from "@/lib/fleet";
import type { FleetAlert } from "@/lib/fleet";
import { ALERT_LEVEL_DOT } from "@/lib/status";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

/** A summary, not the module: the four newest alerts say "this is what is
 *  open right now" and "Ver todas" carries the reader to the screen that
 *  manages them. The badge keeps counting all of them. */
const ALERT_LIMIT = 4;

export function AlertsPanel({
  alerts,
  loading,
  viewAllHref,
}: {
  alerts: FleetAlert[];
  loading: boolean;
  /** Rendered only when the caller knows the reader may open the alerts
   *  module — the route is admin-only. */
  viewAllHref?: string;
}) {
  return (
    <Card id="alertas" className="h-full">
      <CardHeader className="flex-row items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <CardTitle className="truncate">Alertas recientes</CardTitle>
          {alerts.length > 0 && <Badge variant="danger">{alerts.length}</Badge>}
        </div>
        {viewAllHref && (
          <Button variant="ghost" size="sm" asChild>
            <Link to={viewAllHref}>
              Ver todas
              <ArrowUpRight className="size-3.5" aria-hidden />
            </Link>
          </Button>
        )}
      </CardHeader>

      <CardContent>
        {loading ? (
          <div className="space-y-2">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-12 w-full" />
            ))}
          </div>
        ) : alerts.length === 0 ? (
          <div className="flex flex-col items-center gap-2 py-10 text-center">
            <span className="flex size-11 items-center justify-center rounded-xl bg-success-soft text-success">
              <BellOff className="size-5" aria-hidden />
            </span>
            <p className="text-sm font-medium">Todo en orden</p>
            <p className="max-w-xs text-sm text-muted-foreground">
              No hay alertas pendientes para la flota.
            </p>
          </div>
        ) : (
          <ul className="space-y-1">
            {alerts.slice(0, ALERT_LIMIT).map((alert) => (
              <li key={alert.id}>
                <Link
                  to={ROUTES.deviceDetail(alert.deviceId)}
                  className="flex items-center gap-3 rounded-lg px-3 py-2 transition-colors duration-150 hover:bg-secondary/60 focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
                >
                  <span
                    className={cn(
                      "size-2 shrink-0 rounded-full",
                      ALERT_LEVEL_DOT[alert.level],
                    )}
                    aria-hidden
                  />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium">
                      {alert.title}
                    </span>
                    <span className="block truncate text-xs text-muted-foreground">
                      {alert.detail}
                    </span>
                  </span>
                  <span className="shrink-0 text-xs whitespace-nowrap text-muted-foreground">
                    {timeAgo(alert.at)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
