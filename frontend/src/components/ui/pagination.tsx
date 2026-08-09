import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * Page numbers to render: the first and last page stay reachable and the gaps
 * collapse to an ellipsis — `1 … 4 5 6 … 20`. A fleet of 500 devices is 20
 * pages at 25 rows, and a control that grows with the fleet is the same
 * scaling problem the table itself is solving. Never more than 7 slots.
 */
function pageRange(page: number, pageCount: number): (number | "gap")[] {
  if (pageCount <= 7) {
    return Array.from({ length: pageCount }, (_, index) => index + 1);
  }

  // Keep the window three wide even at the edges, so the control does not
  // change width as the user walks from page 1 to the last one.
  const start = Math.max(2, Math.min(page - 1, pageCount - 3));
  const end = Math.min(pageCount - 1, Math.max(page + 1, 4));

  const items: (number | "gap")[] = [1];
  if (start > 2) items.push("gap");
  for (let value = start; value <= end; value += 1) items.push(value);
  if (end < pageCount - 1) items.push("gap");
  items.push(pageCount);
  return items;
}

/** Page controls. The "showing X-Y of N" line lives with the caller's result
 *  counter, which is the live region screen readers track whether or not there
 *  is a page to turn. Page size is the caller's decision, not a user-facing
 *  control — nothing here reads or changes it. */
export function Pagination({
  page,
  pageCount,
  onPageChange,
  className,
}: {
  page: number;
  pageCount: number;
  onPageChange: (page: number) => void;
  className?: string;
}) {
  return (
    <nav
      aria-label="Paginación"
      className={cn("flex flex-wrap items-center justify-end gap-3", className)}
    >
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="icon-sm"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          aria-label="Página anterior"
        >
          <ChevronLeft aria-hidden />
        </Button>

        {pageRange(page, pageCount).map((item, index) =>
          item === "gap" ? (
            <span
              key={`gap-${index}`}
              aria-hidden
              className="px-1 text-sm text-muted-foreground"
            >
              …
            </span>
          ) : (
            <Button
              key={item}
              variant={item === page ? "secondary" : "ghost"}
              size="icon-sm"
              aria-label={`Página ${item}`}
              aria-current={item === page ? "page" : undefined}
              onClick={() => onPageChange(item)}
              className={cn("tabular", item === page && "text-foreground")}
            >
              {item}
            </Button>
          ),
        )}

        <Button
          variant="ghost"
          size="icon-sm"
          disabled={page >= pageCount}
          onClick={() => onPageChange(page + 1)}
          aria-label="Página siguiente"
        >
          <ChevronRight aria-hidden />
        </Button>
      </div>
    </nav>
  );
}
