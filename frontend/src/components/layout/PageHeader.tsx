import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";

interface PageHeaderProps {
  title: string;
  description?: string;
  /** Route the back arrow returns to. A fixed target instead of history.back()
   *  so the destination is the same no matter how the page was reached. */
  backTo?: string;
  backLabel?: string;
  actions?: ReactNode;
  /** Escape hatch for pages that own their spacing — a full-height board lays
   *  its rows out with `gap`, where the default `mb-8` would double up. */
  className?: string;
}

/** Title block for a page. It lives inside the routed content — not in the
 *  shell — so navigating swaps the header with the page instead of remounting
 *  the whole frame. */
export function PageHeader({
  title,
  description,
  backTo,
  backLabel = "Volver",
  actions,
  className,
}: PageHeaderProps) {
  return (
    <header
      className={cn(
        "mb-8 flex flex-wrap items-start justify-between gap-4",
        className,
      )}
    >
      <div className="min-w-0 space-y-1">
        {backTo && (
          <Link
            to={backTo}
            className="group -ml-1 inline-flex items-center gap-1.5 rounded-lg px-1 py-0.5 text-sm text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none"
          >
            <ArrowLeft
              className="size-3.5 transition-transform duration-150 group-hover:-translate-x-0.5"
              aria-hidden
            />
            {backLabel}
          </Link>
        )}
        {/* 24px is the ceiling of the type scale: the page title is the largest
            thing on screen and does not need to grow past it on wide viewports. */}
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        {description && <p className="text-sm text-muted-foreground">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </header>
  );
}
