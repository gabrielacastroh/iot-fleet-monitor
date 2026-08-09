import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

function Input({ className, type, ...props }: ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        // h-10 matches the default Button and a TabsList, so an input sitting in
        // a filter row lines up with the controls beside it instead of standing
        // 4px taller than all of them.
        "flex h-10 w-full min-w-0 rounded-xl border bg-card px-3.5 text-sm shadow-[var(--shadow-soft)]",
        "transition-[color,box-shadow,border-color] duration-150 outline-none",
        "placeholder:text-muted-foreground/70 selection:bg-primary selection:text-primary-foreground",
        "hover:border-foreground/15",
        "focus-visible:border-primary focus-visible:ring-4 focus-visible:ring-primary/12",
        "aria-invalid:border-destructive aria-invalid:ring-4 aria-invalid:ring-destructive/12",
        "disabled:cursor-not-allowed disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

export { Input };
