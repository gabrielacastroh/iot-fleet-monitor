import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { Fuel, Gauge, Truck } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { DeviceActions } from "./DeviceActions";
import { DeviceStatusBadge } from "./DeviceStatusBadge";
import { CRITICAL_FUEL_THRESHOLD, LOW_FUEL_THRESHOLD, timeAgo } from "@/lib/fleet";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/app/routes";
import type { Device } from "../types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";

export function VehicleCard({
  device,
  reading,
  telemetryLoading = false,
  isAdmin,
  onDelete,
  index = 0,
}: {
  device: Device;
  reading?: TelemetryReading;
  /** Telemetry arrives after the device list, so its cells show a skeleton
   *  rather than an em dash that turns into a number a moment later. */
  telemetryLoading?: boolean;
  isAdmin: boolean;
  onDelete?: (device: Device) => void;
  index?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: 0.28,
        // Cap the stagger so a large fleet does not turn into a slow cascade.
        delay: Math.min(index, 8) * 0.04,
        ease: [0.22, 1, 0.36, 1],
      }}
    >
      <Card className="group gap-4 transition-shadow duration-200 hover:shadow-[var(--shadow-lift)]">
        <CardContent className="space-y-4">
          <div className="flex items-start gap-3">
            <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-secondary text-muted-foreground transition-colors group-hover:bg-primary-soft group-hover:text-primary">
              <Truck className="size-5" aria-hidden />
            </span>

            <div className="min-w-0 flex-1">
              <Link
                to={ROUTES.deviceDetail(device.id)}
                className="block truncate font-medium hover:underline focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
              >
                {device.vehicle_name}
              </Link>
              <p className="truncate font-mono text-xs text-muted-foreground">
                {device.device_code} · {device.plate}
              </p>
            </div>

            <DeviceActions device={device} isAdmin={isAdmin} onDelete={onDelete} />
          </div>

          <div className="flex items-center justify-between gap-3">
            <DeviceStatusBadge
              isActive={device.is_active}
              lastSeenAt={device.last_seen_at}
            />
            <span className="text-xs text-muted-foreground">
              {timeAgo(device.last_seen_at)}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 border-t pt-4">
            <FuelGauge level={reading?.fuel_level} loading={telemetryLoading} />
            <div className="space-y-1.5">
              <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <Gauge className="size-3.5" aria-hidden />
                Velocidad
              </p>
              {telemetryLoading && !reading ? (
                <Skeleton className="h-5 w-16" />
              ) : (
                <p className="text-sm font-medium tabular">
                  {reading ? `${Math.round(reading.speed)} km/h` : "—"}
                </p>
              )}
            </div>
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}

export function FuelGauge({
  level,
  loading = false,
  showLabel = true,
  compact = false,
}: {
  level?: number;
  loading?: boolean;
  /** Off inside tables, where the column header already says "Combustible" and
   *  repeating it on every row is noise. The meter keeps its aria-label, so
   *  nothing is lost for a screen reader. */
  showLabel?: boolean;
  /** Reading and bar side by side instead of stacked. Inside a table the
   *  stacked version makes every row two lines tall, which is what stops ten
   *  of them from fitting on screen. */
  compact?: boolean;
}) {
  const value = level == null ? null : Math.round(level);

  if (compact) {
    return (
      <div className="flex items-center gap-2">
        {loading && value == null ? (
          <Skeleton className="h-4 w-full" />
        ) : value == null ? (
          <span className="text-sm text-muted-foreground">—</span>
        ) : (
          <>
            <span className="w-9 shrink-0 text-sm font-medium tabular">{value}%</span>
            <div
              className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-secondary"
              role="meter"
              aria-valuenow={value}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-label="Nivel de combustible"
            >
              <div
                className={cn(
                  "h-full rounded-full transition-[width] duration-500",
                  value <= CRITICAL_FUEL_THRESHOLD
                    ? "bg-destructive"
                    : value <= LOW_FUEL_THRESHOLD
                      ? "bg-warning"
                      : "bg-success",
                )}
                style={{ width: `${value}%` }}
              />
            </div>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-1.5">
      {showLabel && (
        <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <Fuel className="size-3.5" aria-hidden />
          Combustible
        </p>
      )}
      {loading && value == null ? (
        <div className="space-y-1.5">
          <Skeleton className="h-5 w-10" />
          <Skeleton className="h-1.5 w-full rounded-full" />
        </div>
      ) : value == null ? (
        <p className="text-sm font-medium">—</p>
      ) : (
        <div className="space-y-1.5">
          <p className="text-sm font-medium tabular">{value}%</p>
          <div
            className="h-1.5 w-full overflow-hidden rounded-full bg-secondary"
            role="meter"
            aria-valuenow={value}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label="Nivel de combustible"
          >
            <div
              className={cn(
                "h-full rounded-full transition-[width] duration-500",
                value <= 10
                  ? "bg-destructive"
                  : value <= 20
                    ? "bg-warning"
                    : "bg-success",
              )}
              style={{ width: `${value}%` }}
            />
          </div>
        </div>
      )}
    </div>
  );
}
