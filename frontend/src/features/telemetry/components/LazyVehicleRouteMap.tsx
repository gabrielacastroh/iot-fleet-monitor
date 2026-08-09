import { Suspense, lazy } from "react";
import type { ComponentProps } from "react";
import { Skeleton } from "@/components/ui/skeleton";
import type { VehicleRouteMap as VehicleRouteMapType } from "./VehicleRouteMap";

// maplibre-gl alone is over 700kB gzipped — nothing above it needs the map
// library, so it's fetched only when the map actually renders.
const VehicleRouteMap = lazy(() =>
  import("./VehicleRouteMap").then((module) => ({ default: module.VehicleRouteMap })),
);

export function LazyVehicleRouteMap(props: ComponentProps<typeof VehicleRouteMapType>) {
  return (
    <Suspense fallback={<Skeleton className="h-96 w-full rounded-2xl" />}>
      <VehicleRouteMap {...props} />
    </Suspense>
  );
}
