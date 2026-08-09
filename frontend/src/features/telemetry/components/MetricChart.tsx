import { useId } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip as RechartsTooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import type { SeriesPoint } from "@/lib/fleet";

interface MetricChartProps {
  title: string;
  description: string;
  data: SeriesPoint[];
  dataKey: "speed" | "fuel" | "temperature";
  unit: string;
  color: string;
  loading?: boolean;
  /** Domain cap for percentage-style metrics. */
  domainMax?: number;
  /**
   * Dense layouts like the dashboard, where the chart sits beside a taller
   * card: the card stretches to the height it is given and the plot takes
   * whatever is left, so the two columns end flush.
   */
  compact?: boolean;
}

export function MetricChart({
  title,
  description,
  data,
  dataKey,
  unit,
  color,
  loading = false,
  domainMax,
  compact = false,
}: MetricChartProps) {
  // `min-h-40` keeps the plot readable when the neighbouring card is short;
  // above that it just fills the card.
  const plotHeight = compact ? "h-full min-h-40" : "h-48";
  const current = data.at(-1)?.[dataKey];
  // SVG ids are document-global: keying the gradient off `dataKey` alone means
  // two charts of the same metric on one screen would share (and cross) fills.
  // Punctuation is stripped because React's generated ids carry delimiters
  // (`:r0:` / `«r0»`) that don't survive a `url(#…)` reference.
  const gradientId = `fill-${dataKey}-${useId().replace(/[^a-zA-Z0-9]/g, "")}`;

  return (
    <Card className={cn(compact && "h-full")}>
      <CardHeader className="flex-row items-start justify-between">
        <div className="space-y-1">
          <CardTitle>{title}</CardTitle>
          <p className="text-sm text-muted-foreground">{description}</p>
        </div>
        {current != null && (
          <Badge variant="outline" className="tabular">
            {current}
            {unit}
          </Badge>
        )}
      </CardHeader>

      <CardContent className={cn(compact && "min-h-0 flex-1")}>
        {loading ? (
          <Skeleton className={cn("w-full", plotHeight)} />
        ) : data.length === 0 ? (
          <p
            className={cn(
              "flex items-center justify-center text-center text-sm text-muted-foreground",
              plotHeight,
            )}
          >
            Sin lecturas registradas todavía.
          </p>
        ) : (
          <div className={cn("w-full", plotHeight)}>
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -18 }}>
                <defs>
                  <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={color} stopOpacity={0.25} />
                    <stop offset="100%" stopColor={color} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid
                  strokeDasharray="4 4"
                  stroke="var(--border)"
                  vertical={false}
                />
                <XAxis
                  dataKey="time"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                  minTickGap={24}
                />
                <YAxis
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                  domain={domainMax ? [0, domainMax] : ["auto", "auto"]}
                  width={44}
                />
                <RechartsTooltip
                  cursor={{ stroke: "var(--border)" }}
                  contentStyle={{
                    borderRadius: 12,
                    border: "1px solid var(--border)",
                    boxShadow: "var(--shadow-overlay)",
                    fontSize: 12,
                  }}
                  formatter={(value) => [`${value ?? "—"}${unit}`, title]}
                />
                <Area
                  type="monotone"
                  dataKey={dataKey}
                  stroke={color}
                  strokeWidth={2}
                  fill={`url(#${gradientId})`}
                  animationDuration={600}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
