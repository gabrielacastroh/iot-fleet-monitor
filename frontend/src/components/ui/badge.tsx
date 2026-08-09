import type { ComponentProps } from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva } from "class-variance-authority";
import type { VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex w-fit shrink-0 items-center justify-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-medium whitespace-nowrap transition-colors [&>svg]:size-3 [&>svg]:pointer-events-none",
  {
    variants: {
      variant: {
        neutral: "border-border bg-secondary text-muted-foreground",
        brand: "border-primary/15 bg-primary-soft text-primary",
        success: "border-success/20 bg-success-soft text-success",
        warning: "border-warning/25 bg-warning-soft text-warning",
        danger: "border-destructive/20 bg-destructive-soft text-destructive",
        outline: "border-border bg-card text-foreground",
      },
    },
    defaultVariants: { variant: "neutral" },
  },
);

type BadgeProps = ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & { asChild?: boolean };

function Badge({ className, variant, asChild = false, ...props }: BadgeProps) {
  const Comp = asChild ? Slot : "span";
  return (
    <Comp
      data-slot="badge"
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  );
}

export { Badge, badgeVariants };
