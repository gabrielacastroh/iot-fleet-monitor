import { useEffect, useMemo, useRef } from "react";
import * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import type { Feature, FeatureCollection, LineString, Point } from "geojson";
import { MapPin } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import type { TelemetryReading } from "@/features/telemetry/types/telemetry";
import { DEFAULT_FLEET_CENTER } from "@/lib/fleet";

const DEFAULT_ZOOM = 12;

const ROUTE_SOURCE_ID = "vehicle-route";
const ROUTE_LAYER_ID = "vehicle-route-line";
const POSITION_SOURCE_ID = "vehicle-position";
const POSITION_LAYER_ID = "vehicle-position-dot";
const POSITION_HALO_LAYER_ID = "vehicle-position-halo";

// Mirrors --primary from src/index.css — MapLibre paint expressions can't
// read CSS custom properties, so the value is copied here.
const ROUTE_COLOR = "#2563eb";

type RouteCollection = FeatureCollection<LineString, Record<string, never>>;
type PositionCollection = FeatureCollection<Point, Record<string, never>>;

function hasCoords(reading: TelemetryReading): boolean {
  return Number.isFinite(reading.latitude) && Number.isFinite(reading.longitude);
}

function buildRoute(history: TelemetryReading[]): RouteCollection {
  const coordinates = [...history]
    .filter(hasCoords)
    .sort((a, b) => a.recorded_at.localeCompare(b.recorded_at))
    .map((reading): [number, number] => [reading.longitude, reading.latitude]);

  const feature: Feature<LineString, Record<string, never>> = {
    type: "Feature",
    geometry: { type: "LineString", coordinates },
    properties: {},
  };
  return { type: "FeatureCollection", features: coordinates.length >= 2 ? [feature] : [] };
}

function buildPosition(current: TelemetryReading | undefined): PositionCollection {
  if (!current || !hasCoords(current)) return { type: "FeatureCollection", features: [] };
  const feature: Feature<Point, Record<string, never>> = {
    type: "Feature",
    geometry: { type: "Point", coordinates: [current.longitude, current.latitude] },
    properties: {},
  };
  return { type: "FeatureCollection", features: [feature] };
}

function computeBounds(route: RouteCollection, position: PositionCollection): maplibregl.LngLatBounds | null {
  const points = [
    ...route.features.flatMap((f) => f.geometry.coordinates),
    ...position.features.map((f) => f.geometry.coordinates),
  ] as [number, number][];
  if (points.length === 0) return null;
  const bounds = new maplibregl.LngLatBounds();
  for (const point of points) bounds.extend(point);
  return bounds;
}

/** Route walked by one vehicle (from telemetry history) plus its last known position. */
export function VehicleRouteMap({
  history,
  current,
  loading,
}: {
  history: TelemetryReading[];
  current: TelemetryReading | undefined;
  loading: boolean;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const loadedRef = useRef(false);
  const hasFitBoundsRef = useRef(false);

  const route = useMemo(() => buildRoute(history), [history]);
  const position = useMemo(() => buildPosition(current), [current]);
  const hasData = route.features.length > 0 || position.features.length > 0;

  // See FleetMap: the "load" handler fires async and only runs once, so it
  // can't close over route/position directly.
  const routeRef = useRef(route);
  routeRef.current = route;
  const positionRef = useRef(position);
  positionRef.current = position;

  useEffect(() => {
    if (!containerRef.current) return;
    let cancelled = false;

    const map = new maplibregl.Map({
      container: containerRef.current,
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
    map.on("error", (e) => console.error("[VehicleRouteMap]", e.error));

    map.on("load", () => {
      if (cancelled) return;

      map.addSource(ROUTE_SOURCE_ID, { type: "geojson", data: routeRef.current });
      map.addLayer({
        id: ROUTE_LAYER_ID,
        type: "line",
        source: ROUTE_SOURCE_ID,
        layout: { "line-join": "round", "line-cap": "round" },
        paint: { "line-color": ROUTE_COLOR, "line-width": 3, "line-opacity": 0.7 },
      });

      map.addSource(POSITION_SOURCE_ID, { type: "geojson", data: positionRef.current });
      map.addLayer({
        id: POSITION_HALO_LAYER_ID,
        type: "circle",
        source: POSITION_SOURCE_ID,
        paint: { "circle-radius": 14, "circle-color": ROUTE_COLOR, "circle-opacity": 0.25 },
      });
      map.addLayer({
        id: POSITION_LAYER_ID,
        type: "circle",
        source: POSITION_SOURCE_ID,
        paint: {
          "circle-radius": 6,
          "circle-color": ROUTE_COLOR,
          "circle-stroke-width": 2,
          "circle-stroke-color": "#ffffff",
        },
      });

      const bounds = computeBounds(routeRef.current, positionRef.current);
      if (bounds) {
        map.fitBounds(bounds, { padding: 48, maxZoom: 15, duration: 0 });
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
    // Mount once; live updates flow through the effect below.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !loadedRef.current) return;

    const routeSource = map.getSource(ROUTE_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    const positionSource = map.getSource(POSITION_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    if (!routeSource || !positionSource) return;
    routeSource.setData(route);
    positionSource.setData(position);

    if (!hasFitBoundsRef.current) {
      const bounds = computeBounds(route, position);
      if (bounds) {
        map.fitBounds(bounds, { padding: 48, maxZoom: 15 });
        hasFitBoundsRef.current = true;
      }
    }
  }, [route, position]);

  return (
    <Card className="overflow-hidden">
      <CardHeader>
        <CardTitle>Recorrido</CardTitle>
        <p className="text-sm text-muted-foreground">
          Ruta reportada en el rango seleccionado y última posición conocida.
        </p>
      </CardHeader>

      <CardContent>
        <div className="relative h-80 w-full overflow-hidden rounded-xl border lg:h-96">
          <div ref={containerRef} className="size-full" />

          {loading ? (
            <Skeleton className="absolute inset-0 rounded-xl" />
          ) : (
            !hasData && (
              <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-2 bg-background/80 text-center">
                <span className="flex size-11 items-center justify-center rounded-xl border bg-card text-muted-foreground shadow-[var(--shadow-soft)]">
                  <MapPin className="size-5" aria-hidden />
                </span>
                <p className="text-sm font-medium">Sin posiciones todavía</p>
                <p className="max-w-xs text-sm text-muted-foreground">
                  Este equipo no reportó coordenadas en el rango seleccionado.
                </p>
              </div>
            )
          )}
        </div>
      </CardContent>
    </Card>
  );
}
