import { Suspense, lazy } from "react";
import type { ComponentProps } from "react";
import { Skeleton } from "@/components/ui/skeleton";
import type { FleetMap as FleetMapType } from "./FleetMap";

// maplibre-gl alone is over 700kB gzipped — nothing above it needs the map
// library, so it's fetched only when the map actually renders.
const FleetMap = lazy(() =>
  import("./FleetMap").then((module) => ({ default: module.FleetMap })),
);

export function LazyFleetMap(props: ComponentProps<typeof FleetMapType>) {
  return (
    <Suspense fallback={<Skeleton className="h-96 w-full rounded-2xl" />}>
      <FleetMap {...props} />
    </Suspense>
  );
}
