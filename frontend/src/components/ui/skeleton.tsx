import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

/** Placeholder that reserves the final layout, so content landing never
 *  shifts the page (CLS). */
function Skeleton({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="skeleton"
      className={cn("animate-pulse rounded-lg bg-secondary", className)}
      {...props}
    />
  );
}

export { Skeleton };
