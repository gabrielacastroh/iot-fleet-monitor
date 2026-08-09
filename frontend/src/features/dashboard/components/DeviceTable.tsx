import { Link } from "react-router-dom";
import { Truck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { DeviceStatusBadge } from "@/features/devices/components/DeviceStatusBadge";
import { FuelGauge } from "@/features/devices/components/VehicleCard";
import { timeAgo } from "@/lib/fleet";
import { ROUTES } from "@/app/routes";
import type { Device } from "@/features/devices/types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";

const SKELETON_ROWS = 4;

/** Read-only shortlist for the dashboard — row actions live on the full
 *  devices page, not here. Picking a row hands the device back to the caller,
 *  which decides where that leads. */
export function DeviceTable({
  devices,
  latest,
  loading,
  onSelect,
  isAdmin = false,
}: {
  devices: Device[];
  latest: Map<string, TelemetryReading>;
  loading: boolean;
  onSelect: (device: Device) => void;
  isAdmin?: boolean;
}) {
  return (
    <Card className="py-2">
      <CardContent className="px-2">
        {loading ? (
          <div className="space-y-3 p-2">
            {Array.from({ length: SKELETON_ROWS }).map((_, index) => (
              <Skeleton key={index} className="h-12 w-full" />
            ))}
          </div>
        ) : devices.length === 0 ? (
          <EmptyState isAdmin={isAdmin} />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead>Vehículo</TableHead>
                <TableHead>Placa</TableHead>
                <TableHead>Estado</TableHead>
                <TableHead>Última conexión</TableHead>
                <TableHead className="w-28">Combustible</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {devices.map((device) => (
                <TableRow
                  key={device.id}
                  tabIndex={0}
                  role="button"
                  aria-label={`Ver detalle de ${device.vehicle_name}`}
                  onClick={() => onSelect(device)}
                  onKeyDown={(event) => {
                    if (event.key !== "Enter" && event.key !== " ") return;
                    event.preventDefault();
                    onSelect(device);
                  }}
                  className="cursor-pointer focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
                >
                  <TableCell>
                    <div className="flex items-center gap-3">
                      <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-secondary text-muted-foreground">
                        <Truck className="size-4" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <p className="truncate font-medium">{device.vehicle_name}</p>
                        {/* Labelled for the same reason as the devices table:
                            code and plate are two mono strings that otherwise
                            read as the same value printed twice. */}
                        <span className="flex items-center gap-1 text-xs text-muted-foreground">
                          Código
                          <span className="truncate font-mono">{device.device_code}</span>
                        </span>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {device.plate}
                  </TableCell>
                  <TableCell>
                    <DeviceStatusBadge
                      isActive={device.is_active}
                      lastSeenAt={device.last_seen_at}
                    />
                  </TableCell>
                  <TableCell className="text-xs whitespace-nowrap text-muted-foreground">
                    {timeAgo(device.last_seen_at)}
                  </TableCell>
                  <TableCell>
                    <FuelGauge
                      level={latest.get(device.id)?.fuel_level}
                      showLabel={false}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  );
}

function EmptyState({ isAdmin }: { isAdmin: boolean }) {
  return (
    <div className="flex flex-col items-center gap-2 py-16 text-center">
      <span className="flex size-12 items-center justify-center rounded-2xl bg-secondary text-muted-foreground">
        <Truck className="size-5" aria-hidden />
      </span>
      <p className="text-sm font-medium">Todavía no hay dispositivos</p>
      <p className="max-w-sm text-sm text-muted-foreground">
        Registra el primer equipo IoT para empezar a monitorear la flota.
      </p>
      {isAdmin && (
        <Button asChild className="mt-2">
          <Link to={ROUTES.newDevice}>Registrar vehículo</Link>
        </Button>
      )}
    </div>
  );
}
