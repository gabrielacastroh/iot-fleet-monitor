import { AnimatePresence, motion } from "framer-motion";
import { Activity } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { ConnectionState } from "../hooks/useTelemetrySocket";
import type { TelemetryReading } from "../types/telemetry";
import type { Device } from "@/features/devices/types/device";
import { HIGH_TEMP_THRESHOLD, LOW_FUEL_THRESHOLD, timeAgo } from "@/lib/fleet";
import { STATUS_TONE } from "@/lib/status";
import type { StatusTone } from "@/lib/status";
import { cn } from "@/lib/utils";

// The socket's state is a fleet state like any other: live is "activo",
// retrying is "sin señal", and a dead channel is "crítico". Reading the tones
// off the shared map keeps this badge the same green/amber/red as the rows it
// sits next to.
const CONNECTION: Record<ConnectionState, { label: string; tone: StatusTone }> = {
  open: { label: "En vivo", tone: STATUS_TONE.active },
  connecting: { label: "Conectando", tone: STATUS_TONE.noSignal },
  reconnecting: { label: "Reconectando", tone: STATUS_TONE.noSignal },
  closed: { label: "Sin conexión", tone: STATUS_TONE.critical },
};

const EVENT_LIMIT = 12;

interface FeedEvent {
  key: string;
  code: string;
  metric: string;
  value: string;
  tone: string;
  at: string;
}

/**
 * One reading carries three metrics but an operator reads one line at a time,
 * so each event highlights the metric that would make them act: fuel below the
 * fleet threshold first, then temperature above it, and speed as the plain
 * "this vehicle is reporting" fallback.
 *
 * These are display thresholds, not alert rules — only the predictive fuel
 * check raises a real alert. Highlighting a hot reading tells an operator
 * where to look; it never claims the backend flagged it.
 */
function toEvent(reading: TelemetryReading, code: string): FeedEvent {
  const base = { key: reading.id, code, at: reading.recorded_at };

  if (reading.fuel_level <= LOW_FUEL_THRESHOLD) {
    return {
      ...base,
      metric: "Combustible",
      value: `${Math.round(reading.fuel_level)} %`,
      tone: "text-destructive",
    };
  }
  if (reading.temperature >= HIGH_TEMP_THRESHOLD) {
    return {
      ...base,
      metric: "Temperatura",
      value: `${Math.round(reading.temperature)} °C`,
      tone: "text-warning",
    };
  }
  return {
    ...base,
    metric: "Velocidad",
    value: `${Math.round(reading.speed)} km/h`,
    tone: "text-foreground",
  };
}

/** The socket feed, read as events instead of payloads: which vehicle, which
 *  metric, what value, how long ago. */
export function LiveTelemetryCard({
  connectionState,
  readings,
  devices,
}: {
  connectionState: ConnectionState;
  readings: TelemetryReading[];
  devices: Device[];
}) {
  const status = CONNECTION[connectionState];

  const codeById = new Map(devices.map((device) => [device.id, device.device_code]));
  // Newest first: on a live feed the top of the list is where the eye already
  // is. Sorted rather than reversed because the batch from the REST call and
  // the readings the socket appends do not arrive in the same order, and a
  // "hace X" column that doesn't descend reads as scrambled.
  // Keyed by reading id, so a row keeps its identity while the socket pushes
  // new readings above it: only the arriving row animates in and the one
  // falling off the limit animates out. Position-derived keys made every row
  // remount on each message, which is what read as a flicker at simulator
  // rates. The map also drops duplicate ids — a refetch that overlaps the
  // socket can deliver the same reading twice, and React needs unique keys.
  const events = [...new Map(readings.map((reading) => [reading.id, reading])).values()]
    .sort((a, b) => b.recorded_at.localeCompare(a.recorded_at))
    .slice(0, EVENT_LIMIT)
    .map((reading) =>
      // A reading whose device is not in the cache (just registered, or removed
      // mid-session) still says something useful — the raw uuid does not.
      toEvent(reading, codeById.get(reading.device_id) ?? "Sin registrar"),
    );

  return (
    <Card className="h-full">
      <CardHeader className="flex-row items-center justify-between">
        <div className="space-y-1">
          <CardTitle>Actividad en tiempo real</CardTitle>
          <p className="text-sm text-muted-foreground">
            Últimas lecturas recibidas por el canal WebSocket.
          </p>
        </div>
        <Badge variant={status.tone.variant}>
          <span
            className={cn(
              "size-1.5 rounded-full",
              status.tone.dot,
              connectionState !== "closed" && "pulse-dot",
            )}
            aria-hidden
          />
          {status.label}
        </Badge>
      </CardHeader>

      <CardContent>
        {events.length === 0 ? (
          <div className="flex flex-col items-center gap-2 py-10 text-center">
            <span className="flex size-11 items-center justify-center rounded-xl bg-primary-soft text-primary">
              <Activity className="size-5" aria-hidden />
            </span>
            <p className="text-sm font-medium">
              {connectionState === "closed"
                ? "Canal cerrado"
                : "Esperando la primera lectura"}
            </p>
            <p className="max-w-xs text-sm text-muted-foreground">
              {connectionState === "closed"
                ? "No hay conexión con el canal de telemetría."
                : "Las lecturas aparecerán aquí en cuanto los equipos empiecen a reportar."}
            </p>
          </div>
        ) : (
          <ul className="max-h-72 space-y-1 overflow-y-auto pr-1">
            {/* popLayout takes the row leaving the list out of the flow at
                once, so the rows below settle into their new position in a
                single move instead of jumping and then sliding back. */}
            <AnimatePresence initial={false} mode="popLayout">
              {events.map((event) => (
                <motion.li
                  key={event.key}
                  layout="position"
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.24, ease: "easeOut" }}
                  className="flex items-center gap-3 rounded-lg px-3 py-2 text-xs transition-colors duration-150 hover:bg-secondary/60"
                >
                  <span className="w-16 shrink-0 truncate font-mono font-medium">
                    {event.code}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-muted-foreground">
                    {event.metric}
                  </span>
                  <span className={cn("shrink-0 font-medium tabular", event.tone)}>
                    {event.value}
                  </span>
                  <span className="w-20 shrink-0 truncate text-right text-muted-foreground">
                    {timeAgo(event.at)}
                  </span>
                </motion.li>
              ))}
            </AnimatePresence>
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
