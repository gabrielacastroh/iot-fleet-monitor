import { useNavigate } from "react-router-dom";
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
import { DeviceActions } from "./DeviceActions";
import { DeviceStatusBadge } from "./DeviceStatusBadge";
import { FuelGauge } from "./VehicleCard";
import { timeAgo } from "@/lib/fleet";
import { ROUTES } from "@/app/routes";
import type { Device } from "../types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";

/** Dense inventory view — the default for the devices screen, because a fleet
 *  of hundreds is read by scanning rows, not by browsing cards. It renders
 *  exactly the page it is handed; the caller owns the slicing. */
export function DevicesTable({
  devices,
  latest,
  telemetryLoading,
  isAdmin,
  onDelete,
}: {
  devices: Device[];
  latest: Map<string, TelemetryReading>;
  telemetryLoading: boolean;
  isAdmin: boolean;
  onDelete: (device: Device) => void;
}) {
  const navigate = useNavigate();

  return (
    // The card takes the height the page hands it and the table stretches
    // inside: `h-full` on a <table> makes the browser share the leftover space
    // between its rows, so ten devices fill the board instead of sitting in a
    // block at the top. Nothing is fixed in pixels — on a short viewport the
    // rows fall back to their content height and the container scrolls.
    <Card className="h-full py-2">
      <CardContent className="min-h-0 flex-1 px-2 [&_[data-slot=table-container]]:h-full">
        {/* `table-fixed` with a width per column: on auto layout every page
            re-measures its own rows, so turning from page 1 to 2 shifted every
            column sideways as the content changed. Fixed widths make the
            columns a property of the table, not of the page you happen to be
            on. `min-w` keeps them from crushing on a narrow screen — the
            container scrolls instead. */}
        <Table className="h-full min-w-[920px] table-fixed [&_td]:px-4 [&_th]:px-4">
          <TableHeader className="[&_th]:py-4">
            <TableRow className="hover:bg-transparent">
              <TableHead className="w-[11%]">Dispositivo</TableHead>
              <TableHead className="w-[18%]">Vehículo</TableHead>
              {/* Its own column rather than a second line under the name: the
                  stacked version doubled every row's height, and a plate is
                  not the same value as the device code it used to sit beside. */}
              <TableHead className="w-[10%]">Placa</TableHead>
              <TableHead className="w-[11%]">Estado</TableHead>
              {/* Fuel, speed and temperature sit together: they are the three
                  sensors a reading carries, and scanning them as a block beats
                  hunting for them across the row. */}
              <TableHead className="w-[13%]">Combustible</TableHead>
              <TableHead className="w-[9%] text-right">Velocidad</TableHead>
              <TableHead className="w-[10%] text-right">Temperatura</TableHead>
              <TableHead className="w-[11%]">Última conexión</TableHead>
              <TableHead className="w-[7%] text-right">Acciones</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {devices.map((device) => {
              const reading = latest.get(device.id);
              return (
                <TableRow
                  key={device.id}
                  tabIndex={0}
                  role="button"
                  aria-label={`Ver detalle de ${device.vehicle_name}`}
                  onClick={() => navigate(ROUTES.deviceDetail(device.id))}
                  onKeyDown={(event) => {
                    if (event.key !== "Enter" && event.key !== " ") return;
                    event.preventDefault();
                    navigate(ROUTES.deviceDetail(device.id));
                  }}
                  className="cursor-pointer focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
                >
                  <TableCell className="py-4">
                    {/* One line, always: "SIM-012" broken across two rows reads
                        as two different codes. */}
                    <span className="font-mono text-xs font-medium whitespace-nowrap">
                      {device.device_code}
                    </span>
                  </TableCell>

                  <TableCell className="py-4">
                    <p className="truncate font-medium">{device.vehicle_name}</p>
                  </TableCell>

                  <TableCell className="py-4 font-mono text-xs text-muted-foreground">
                    <span className="block truncate">{device.plate}</span>
                  </TableCell>

                  <TableCell className="py-4">
                    <DeviceStatusBadge
                      isActive={device.is_active}
                      lastSeenAt={device.last_seen_at}
                    />
                  </TableCell>

                  <TableCell className="py-4">
                    <FuelGauge
                      level={reading?.fuel_level}
                      loading={telemetryLoading}
                      showLabel={false}
                      compact
                    />
                  </TableCell>

                  <TableCell className="py-4 text-right whitespace-nowrap">
                    {telemetryLoading && !reading ? (
                      <Skeleton className="ml-auto h-4 w-16" />
                    ) : (
                      <span className="text-sm tabular">
                        {reading ? `${Math.round(reading.speed)} km/h` : "—"}
                      </span>
                    )}
                  </TableCell>

                  <TableCell className="py-4 text-right whitespace-nowrap">
                    {telemetryLoading && !reading ? (
                      <Skeleton className="ml-auto h-4 w-14" />
                    ) : (
                      // Reported as-is: no alert rule backs a temperature
                      // limit, so the column must not colour one in.
                      <span className="text-sm tabular">
                        {reading ? `${Math.round(reading.temperature)} °C` : "—"}
                      </span>
                    )}
                  </TableCell>

                  <TableCell className="py-4 text-xs whitespace-nowrap text-muted-foreground">
                    {timeAgo(device.last_seen_at)}
                  </TableCell>

                  <TableCell
                    className="py-4 text-right"
                    // The row navigates on click; the actions menu inside it
                    // must not drag the user to the detail page on its way.
                    onClick={(event) => event.stopPropagation()}
                    onKeyDown={(event) => event.stopPropagation()}
                  >
                    <DeviceActions
                      device={device}
                      isAdmin={isAdmin}
                      onDelete={onDelete}
                    />
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
