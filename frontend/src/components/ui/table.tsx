import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

function Table({ className, ...props }: ComponentProps<"table">) {
  return (
    // Wide data scrolls inside its own container so the page body never
    // scrolls horizontally on small screens.
    //
    // `relative` is load-bearing: `sr-only` is `position: absolute`, so without
    // a positioned ancestor those labels resolve against the viewport instead
    // of this box. Their static position sits at the far edge of a table wider
    // than the screen, which dragged the whole page into horizontal scroll on
    // mobile — the exact thing this container exists to prevent.
    // `min-w-0` completes the story: `overflow-x-auto` alone still reports the
    // table's full min-content upward, so a grid or flex parent sizes its
    // track to the widest row and the page overflows anyway.
    <div data-slot="table-container" className="relative w-full min-w-0 overflow-x-auto">
      <table
        data-slot="table"
        className={cn("w-full caption-bottom border-collapse text-sm", className)}
        {...props}
      />
    </div>
  );
}

function TableHeader({ className, ...props }: ComponentProps<"thead">) {
  return <thead data-slot="table-header" className={cn(className)} {...props} />;
}

function TableBody({ className, ...props }: ComponentProps<"tbody">) {
  return <tbody data-slot="table-body" className={cn(className)} {...props} />;
}

function TableRow({ className, ...props }: ComponentProps<"tr">) {
  return (
    <tr
      data-slot="table-row"
      className={cn(
        "border-b transition-colors last:border-0 hover:bg-secondary/50",
        className,
      )}
      {...props}
    />
  );
}

function TableHead({ className, ...props }: ComponentProps<"th">) {
  return (
    <th
      data-slot="table-head"
      scope="col"
      className={cn(
        // Symmetric padding: the cards that host these tables trim their own
        // padding down, so a header with no top padding sat on the border.
        // 12px horizontal, not 16: eight columns of real fleet data need every
        // pixel to fit a 1280px desktop without the actions column falling off
        // the edge, and this is still looser than the shadcn default.
        "px-3 pt-3 pb-3 text-left text-xs font-medium whitespace-nowrap text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}

function TableCell({ className, ...props }: ComponentProps<"td">) {
  return (
    <td
      data-slot="table-cell"
      className={cn("px-3 py-3 align-middle", className)}
      {...props}
    />
  );
}

export { Table, TableHeader, TableBody, TableRow, TableHead, TableCell };
