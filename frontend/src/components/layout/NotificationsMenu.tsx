import { Link } from "react-router-dom";
import { ArrowUpRight, Bell, BellOff } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { timeAgo } from "@/lib/fleet";
import type { FleetAlert } from "@/lib/fleet";
import { ALERT_LEVEL_DOT } from "@/lib/status";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/app/routes";

/** Five is what fits without the menu turning into a scrolling surface of its
 *  own — past that the reader is browsing, and browsing belongs on the alerts
 *  screen the footer links to. */
const NOTIFICATION_LIMIT = 5;

/**
 * The bell reads its own contents instead of only counting them: an operator
 * who sees a red 3 wants to know *which* three, and making them load a whole
 * screen to find out is the difference between a glance and a detour.
 *
 * Built on DropdownMenu rather than a popover of our own — it already handles
 * focus trapping, Escape, outside clicks and collision-aware placement, and it
 * is the primitive this app already ships.
 */
export function NotificationsMenu({
  alerts,
  viewAllHref,
}: {
  alerts: FleetAlert[];
  /** Where "ver todas" leads: the alerts module for admins, the dashboard's
   *  own panel for everyone else, whose requests that route would reject. */
  viewAllHref: string;
}) {
  const count = alerts.length;
  const visible = alerts.slice(0, NOTIFICATION_LIMIT);
  const label = count > 0 ? `${count} alertas activas` : "Sin alertas";

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="size-5" aria-hidden />
          {count > 0 && (
            // The ring punches background-coloured space between the bubble and
            // the bell's strokes. Without it the two shapes touch and read as
            // one blob, which is what made the count look oversized even when
            // it was not.
            <span
              className="absolute top-1 right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[0.625rem] leading-none font-semibold text-destructive-foreground ring-2 ring-background"
              aria-hidden
            >
              {count > 9 ? "9+" : count}
            </span>
          )}
          <span className="sr-only">Notificaciones: {label}</span>
        </Button>
      </DropdownMenuTrigger>

      <DropdownMenuContent className="w-[21rem] p-0">
        <div className="flex items-center justify-between gap-3 px-3.5 py-3">
          <p className="text-sm font-semibold">Notificaciones</p>
          {count > 0 && <Badge variant="danger">{count}</Badge>}
        </div>

        <DropdownMenuSeparator className="mx-0 my-0" />

        {visible.length === 0 ? (
          <div className="flex flex-col items-center gap-2 px-6 py-8 text-center">
            <span className="flex size-10 items-center justify-center rounded-xl bg-success-soft text-success">
              <BellOff className="size-4.5" aria-hidden />
            </span>
            <p className="text-sm font-medium">Todo en orden</p>
            <p className="text-xs text-muted-foreground">
              Ningún equipo reporta combustible bajo, exceso de velocidad ni pérdida
              de señal.
            </p>
          </div>
        ) : (
          <ul className="p-1.5">
            {visible.map((alert) => (
              <li key={alert.id}>
                {/* asChild so each row is a real link the arrow keys reach and
                    Enter follows, and so picking one closes the menu. */}
                <DropdownMenuItem asChild className="items-start gap-3 py-2.5">
                  <Link to={ROUTES.deviceDetail(alert.deviceId)}>
                    <span
                      className={cn(
                        "mt-1.5 size-2 shrink-0 rounded-full",
                        ALERT_LEVEL_DOT[alert.level],
                      )}
                      aria-hidden
                    />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium">{alert.title}</span>
                      <span className="block truncate text-xs text-muted-foreground">
                        {alert.detail}
                      </span>
                    </span>
                    <span className="shrink-0 text-xs whitespace-nowrap text-muted-foreground">
                      {timeAgo(alert.at)}
                    </span>
                  </Link>
                </DropdownMenuItem>
              </li>
            ))}
          </ul>
        )}

        <DropdownMenuSeparator className="mx-0 my-0" />

        <div className="p-1.5">
          <DropdownMenuItem
            asChild
            className="justify-center font-medium text-primary [&>svg]:text-primary"
          >
            <Link to={viewAllHref}>
              Ver todas las notificaciones
              <ArrowUpRight className="size-3.5" aria-hidden />
            </Link>
          </DropdownMenuItem>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
