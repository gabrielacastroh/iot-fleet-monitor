import { useEffect, useMemo, useRef } from "react";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import type { Feature, FeatureCollection, Point } from "geojson";
import { Link } from "react-router-dom";
import { Maximize2, MapPin } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import type { Device } from "@/features/devices/types/device";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";
import {
  CRITICAL_FUEL_THRESHOLD,
  DEFAULT_FLEET_CENTER,
  HIGH_TEMP_THRESHOLD,
  LOW_FUEL_THRESHOLD,
  SPEED_LIMIT,
  timeAgo,
} from "@/lib/fleet";
import { ROUTES } from "@/app/routes";

const DEFAULT_ZOOM = 12;

const SOURCE_ID = "fleet";
const DOT_LAYER_ID = "fleet-dot";
const HALO_LAYER_ID = "fleet-halo";

// MapLibre paint expressions need literal color values — they can't read CSS
// custom properties — so these mirror --success/--muted-foreground from
// src/index.css, which is what STATUS_TONE.active / STATUS_TONE.inactive paint
// everywhere else. Keep them in sync if that palette changes.
const ACTIVE_COLOR = "#22c55e";
const INACTIVE_COLOR = "#64748b";

interface FleetPointProperties {
  id: string;
  name: string;
  active: boolean;
  speed: number;
  fuel: number;
  temperature: number;
  lastSeenAt: string | null;
}

type FleetFeature = Feature<Point, FleetPointProperties>;
type FleetCollection = FeatureCollection<Point, FleetPointProperties>;

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function metricTile(label: string, value: number, unit: string, valueClass: string): string {
  return `
    <div class="rounded-lg bg-secondary/60 px-2 py-1.5 text-center">
      <p class="text-[0.65rem] font-medium tracking-wide text-muted-foreground uppercase">${label}</p>
      <p class="text-sm font-semibold tabular ${valueClass}">
        ${Math.round(value)}<span class="ml-0.5 text-[0.65rem] font-normal text-muted-foreground">${unit}</span>
      </p>
    </div>
  `;
}

function popupHtml(props: FleetPointProperties): string {
  const speedClass = props.speed > SPEED_LIMIT ? "text-destructive" : "text-foreground";
  const fuelClass =
    props.fuel <= CRITICAL_FUEL_THRESHOLD
      ? "text-destructive"
      : props.fuel <= LOW_FUEL_THRESHOLD
        ? "text-warning"
        : "text-foreground";
  const tempClass = props.temperature > HIGH_TEMP_THRESHOLD ? "text-destructive" : "text-foreground";

  return `
    <div class="min-w-[13rem] space-y-3 p-1">
      <div class="flex items-start justify-between gap-3">
        <p class="truncate pr-4 text-sm font-semibold text-foreground">${escapeHtml(props.name)}</p>
        <span class="inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2 py-0.5 text-[0.65rem] font-medium ${
          props.active
            ? "border-success/20 bg-success-soft text-success"
            : "border-border bg-secondary text-muted-foreground"
        }">
          <span class="size-1.5 rounded-full ${props.active ? "bg-success" : "bg-muted-foreground"}"></span>
          ${props.active ? "En línea" : "Inactivo"}
        </span>
      </div>

      <div class="grid grid-cols-3 gap-1.5">
        ${metricTile("Vel.", props.speed, "km/h", speedClass)}
        ${metricTile("Comb.", props.fuel, "%", fuelClass)}
        ${metricTile("Temp.", props.temperature, "°C", tempClass)}
      </div>

      <div class="flex items-center justify-between gap-3 border-t pt-2">
        <p class="text-xs text-muted-foreground">${escapeHtml(timeAgo(props.lastSeenAt))}</p>
        <a href="${ROUTES.deviceDetail(props.id)}" class="text-xs font-medium text-primary hover:underline">
          Ver detalle →
        </a>
      </div>
    </div>
  `;
}

/** Same filter as the old grid map: only devices with a known reading show up. */
function buildGeoJson(devices: Device[], latest: Map<string, TelemetryReading>): FleetCollection {
  const features: FleetFeature[] = [];
  for (const device of devices) {
    const reading = latest.get(device.id);
    // A reading with a bad coordinate (malformed payload, parsing miss) would
    // otherwise hand MapLibre a NaN geometry and crash the whole map.
    if (!reading || !Number.isFinite(reading.latitude) || !Number.isFinite(reading.longitude)) {
      continue;
    }
    features.push({
      type: "Feature",
      geometry: { type: "Point", coordinates: [reading.longitude, reading.latitude] },
      properties: {
        id: device.id,
        name: device.vehicle_name,
        active: device.is_active,
        speed: reading.speed,
        fuel: reading.fuel_level,
        temperature: reading.temperature,
        lastSeenAt: device.last_seen_at ?? reading.recorded_at,
      },
    });
  }
  return { type: "FeatureCollection", features };
}

function computeBounds(geojson: FleetCollection): maplibregl.LngLatBounds | null {
  if (geojson.features.length === 0) return null;
  const bounds = new maplibregl.LngLatBounds();
  for (const feature of geojson.features) {
    bounds.extend(feature.geometry.coordinates as [number, number]);
  }
  return bounds;
}

export function FleetMap({
  devices,
  latest,
  loading,
  /** Card content fills its container's height; the dashboard's fixed h-80/h-96
   *  is the default so every existing caller keeps its current size, and the
   *  full-page map view overrides it to fill the viewport instead. */
  heightClassName = "h-80 lg:h-96",
  /** Route to the standalone full-page map. Only the dashboard's compact card
   *  needs a way out to the bigger view — the full-page map itself has nowhere
   *  further to expand to. */
  expandHref,
}: {
  devices: Device[];
  latest: Map<string, TelemetryReading>;
  loading: boolean;
  heightClassName?: string;
  expandHref?: string;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const loadedRef = useRef(false);
  // Camera should snap to the fleet once, the first time positions arrive —
  // never again, or every WebSocket tick would yank the view around.
  const hasFitBoundsRef = useRef(false);

  const geojson = useMemo(() => buildGeoJson(devices, latest), [devices, latest]);
  const plottedCount = geojson.features.length;

  // The "load" handler below fires asynchronously and only ever runs once, so
  // it can't close over `geojson` directly — if devices/telemetry resolve
  // before the map finishes loading (plausible against a fast local backend),
  // that closure would be stale with no guarantee anything triggers a re-sync
  // afterward. A ref kept current on every render sidesteps the race.
  const geojsonRef = useRef(geojson);
  geojsonRef.current = geojson;

  // Mount the map exactly once. Everything after this reacts through the
  // `geojson` effect below instead of recreating the map.
  useEffect(() => {
    if (!containerRef.current) return;

    // StrictMode double-invokes this effect in dev: mount, cleanup, mount
    // again — the first map's async "load" can still fire after its own
    // cleanup already called remove(). Without this guard that stale
    // callback goes on to addSource/addLayer/fitBounds on a dead map
    // instance, which can leave the *second*, real map's WebGL context in a
    // broken state with nothing thrown to the console.
    let cancelled = false;

    const map = new maplibregl.Map({
      container: containerRef.current,
      // CARTO's free raster basemaps: no API key, CORS enabled, and the
      // "light_all" style sits under the UI's palette without fighting the
      // marker colors the way full-colour OSM tiles do.
      style: {
        version: 8,
        sources: {
          basemap: {
            type: "raster",
            tiles: ["https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap contributors © CARTO",
          },
        },
        layers: [{ id: "basemap", type: "raster", source: "basemap" }],
      },
      center: DEFAULT_FLEET_CENTER,
      zoom: DEFAULT_ZOOM,
    });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    map.on("error", (e) => console.error("[FleetMap]", e.error));

    map.on("load", () => {
      if (cancelled) return;
      map.addSource(SOURCE_ID, { type: "geojson", data: geojsonRef.current });

      map.addLayer({
        id: HALO_LAYER_ID,
        type: "circle",
        source: SOURCE_ID,
        paint: {
          "circle-radius": 14,
          "circle-color": ["case", ["get", "active"], ACTIVE_COLOR, INACTIVE_COLOR],
          "circle-opacity": 0.25,
        },
      });
      map.addLayer({
        id: DOT_LAYER_ID,
        type: "circle",
        source: SOURCE_ID,
        paint: {
          "circle-radius": 6,
          "circle-color": ["case", ["get", "active"], ACTIVE_COLOR, INACTIVE_COLOR],
          "circle-stroke-width": 2,
          "circle-stroke-color": "#ffffff",
        },
      });

      map.on("mouseenter", DOT_LAYER_ID, () => {
        map.getCanvas().style.cursor = "pointer";
      });
      map.on("mouseleave", DOT_LAYER_ID, () => {
        map.getCanvas().style.cursor = "";
      });
      map.on("click", DOT_LAYER_ID, (event) => {
        const feature = event.features?.[0];
        if (!feature || feature.geometry.type !== "Point") return;
        new maplibregl.Popup({ offset: 12, maxWidth: "280px" })
          .setLngLat(feature.geometry.coordinates as [number, number])
          .setHTML(popupHtml(feature.properties as unknown as FleetPointProperties))
          .addTo(map);
      });

      const bounds = computeBounds(geojsonRef.current);
      if (bounds) {
        map.fitBounds(bounds, { padding: 48, maxZoom: 14, duration: 0 });
        hasFitBoundsRef.current = true;
      }

      loadedRef.current = true;
    });

    mapRef.current = map;

    return () => {
      cancelled = true;
      loadedRef.current = false;
      map.remove();
      mapRef.current = null;
    };
    // Mount once; live updates flow through the `geojson` effect below.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Push updates into the existing source — never recreate the map or source.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !loadedRef.current) return;

    const source = map.getSource(SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    if (!source) return;
    source.setData(geojson);

    if (!hasFitBoundsRef.current) {
      const bounds = computeBounds(geojson);
      if (bounds) {
        map.fitBounds(bounds, { padding: 48, maxZoom: 14 });
        hasFitBoundsRef.current = true;
      }
    }
  }, [geojson]);

  return (
    <Card className="overflow-hidden">
      {/* `min-w-0` on the text block: the badge is `shrink-0`, so without it
          neither side of this row can give and the header pushes the card
          past the viewport on a phone. */}
      <CardHeader className="flex-row items-center justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <CardTitle>Posición de la flota</CardTitle>
          <p className="text-sm text-muted-foreground">
            Última ubicación reportada por cada equipo.
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Badge variant={plottedCount > 0 ? "brand" : "neutral"}>
            {plottedCount} en el mapa
          </Badge>
          {expandHref && (
            <Button variant="outline" size="sm" asChild>
              <Link to={expandHref}>
                <Maximize2 className="size-4" aria-hidden />
                Ver más grande
              </Link>
            </Button>
          )}
        </div>
      </CardHeader>

      <CardContent>
        {/* Fixed height instead of an aspect ratio: the map is the anchor of
            the dashboard's second row and it has to stay tall enough to read
            the fleet's spread, whatever width the column ends up with. This is
            the outer box — the inner container below must keep its own sizing
            for the reason spelled out there. */}
        <div
          className={`relative w-full overflow-hidden rounded-xl border ${heightClassName}`}
        >
          {/* Sized with h-full, not `absolute inset-0`: MapLibre stamps its
              own `.maplibregl-map { position: relative }` on this node, and
              because its stylesheet loads after Tailwind's it wins the tie on
              equal specificity — the insets would then stop stretching the
              box, collapsing it to 0 height whose `overflow: hidden` clips
              the canvas away entirely (map draws, screen stays blank).
              Container stays mounted even while loading/empty so the map ref
              is never null when the init effect runs. */}
          <div ref={containerRef} className="size-full" />

          {loading ? (
            <Skeleton className="absolute inset-0 rounded-xl" />
          ) : (
            plottedCount === 0 && (
              <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-2 bg-background/80 text-center">
                <span className="flex size-11 items-center justify-center rounded-xl border bg-card text-muted-foreground shadow-[var(--shadow-soft)]">
                  <MapPin className="size-5" aria-hidden />
                </span>
                <p className="text-sm font-medium">Sin posiciones todavía</p>
                <p className="max-w-xs text-sm text-muted-foreground">
                  Cuando los equipos envíen telemetría con coordenadas, aparecerán aquí.
                </p>
              </div>
            )
          )}
        </div>
      </CardContent>
    </Card>
  );
}
