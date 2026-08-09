import { Suspense, lazy } from "react";
import type { ComponentProps } from "react";
import { Skeleton } from "@/components/ui/skeleton";
import type { MetricChart as MetricChartType } from "./MetricChart";

// Recharts is by far the heaviest dependency in the bundle and nothing above
// the fold needs it, so the charting code is fetched only when a chart renders.
const MetricChart = lazy(() =>
  import("./MetricChart").then((module) => ({ default: module.MetricChart })),
);

export function LazyMetricChart(props: ComponentProps<typeof MetricChartType>) {
  // The placeholder matches the card it becomes, so the row doesn't jump when
  // the chunk lands.
  return (
    <Suspense
      fallback={
        <Skeleton
          className={
            props.compact ? "h-full min-h-72 rounded-2xl" : "h-80 rounded-2xl"
          }
        />
      }
    >
      <MetricChart {...props} />
    </Suspense>
  );
}
