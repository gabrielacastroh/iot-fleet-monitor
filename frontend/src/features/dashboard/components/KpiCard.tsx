import { motion } from "framer-motion";
import type { LucideIcon } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

export interface KpiCardProps {
  label: string;
  value: string | number;
  unit?: string;
  icon: LucideIcon;
  tone?: "primary" | "success" | "warning" | "danger";
  /** One short line of context under the figure ("de 12 en la flota"). */
  hint?: string;
  loading?: boolean;
  index?: number;
}

const TONE_STYLES = {
  primary: "bg-primary-soft text-primary",
  success: "bg-success-soft text-success",
  warning: "bg-warning-soft text-warning",
  danger: "bg-destructive-soft text-destructive",
} as const;

/** Compact fleet indicator: figure, label, one line of context. Nothing else —
 *  the row of five sits above the fold and every extra pixel here pushes the
 *  map and the alerts out of the first viewport. */
export function KpiCard({
  label,
  value,
  unit,
  icon: Icon,
  tone = "primary",
  hint,
  loading = false,
  index = 0,
}: KpiCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: index * 0.05, ease: [0.22, 1, 0.36, 1] }}
    >
      <Card className="h-full gap-0 py-4 transition-shadow duration-200 hover:shadow-[var(--shadow-lift)]">
        <CardContent className="flex items-start justify-between gap-3 px-4">
          <div className="min-w-0 space-y-1">
            {/* Wraps instead of truncating: at five columns "Telemetrías
                recibidas" clips to "Telemetrías rec…", and a KPI nobody can
                read in one glance has lost the only job it has. `h-full` on
                the card keeps the row aligned when one label takes two lines. */}
            <p className="eyebrow leading-snug">{label}</p>
            {loading ? (
              <Skeleton className="h-7 w-16" />
            ) : (
              <p className="flex items-baseline gap-1 text-2xl font-semibold tracking-tight tabular">
                {value}
                {unit && (
                  <span className="text-sm font-medium text-muted-foreground">
                    {unit}
                  </span>
                )}
              </p>
            )}
            {hint && (
              <p className="text-xs leading-snug text-muted-foreground">{hint}</p>
            )}
          </div>
          <span
            className={cn(
              "flex size-8 shrink-0 items-center justify-center rounded-lg",
              TONE_STYLES[tone],
            )}
          >
            <Icon className="size-4" aria-hidden />
          </span>
        </CardContent>
      </Card>
    </motion.div>
  );
}
