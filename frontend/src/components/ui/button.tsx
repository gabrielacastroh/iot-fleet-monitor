import type { ComponentProps } from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva } from "class-variance-authority";
import type { VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  [
    "inline-flex items-center justify-center gap-2 rounded-xl text-sm font-medium whitespace-nowrap",
    "transition-all duration-150 outline-none",
    "focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:ring-offset-2 focus-visible:ring-offset-background",
    "disabled:pointer-events-none disabled:opacity-50",
    "[&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 [&_svg]:shrink-0",
  ],
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-[var(--shadow-soft)] hover:bg-primary/92 active:scale-[0.985]",
        // Kept for the login, which is styled to its own approved mockup.
        gradient:
          "bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-lg shadow-blue-600/25 hover:shadow-xl hover:shadow-blue-600/30 hover:from-blue-500 hover:to-blue-400",
        outline:
          "border bg-card text-foreground shadow-[var(--shadow-soft)] hover:bg-secondary active:scale-[0.985]",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/70",
        ghost: "text-muted-foreground hover:bg-secondary hover:text-foreground",
        destructive:
          "bg-destructive text-destructive-foreground shadow-[var(--shadow-soft)] hover:bg-destructive/90",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4",
        sm: "h-9 gap-1.5 rounded-lg px-3",
        lg: "h-11 px-5 text-[0.9375rem]",
        icon: "size-10 rounded-xl",
        "icon-sm": "size-9 rounded-lg",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

type ButtonProps = ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & { asChild?: boolean };

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: ButtonProps) {
  const Comp = asChild ? Slot : "button";
  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}

export { Button, buttonVariants };
export type { ButtonProps };
