import type { ComponentProps } from "react";
import * as TabsPrimitive from "@radix-ui/react-tabs";
import { cn } from "@/lib/utils";

function Tabs({ className, ...props }: ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      // min-w-0 so a list of tabs inside a flex row can shrink and scroll
      // instead of pushing the page into horizontal overflow on a phone.
      className={cn("flex min-w-0 flex-col gap-4", className)}
      {...props}
    />
  );
}

function TabsList({ className, ...props }: ComponentProps<typeof TabsPrimitive.List>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      className={cn(
        // Five filter tabs are wider than a 360px phone: the strip scrolls
        // inside itself rather than widening the page.
        "inline-flex w-fit max-w-full items-center gap-1 overflow-x-auto rounded-xl bg-secondary p-1",
        className,
      )}
      {...props}
    />
  );
}

function TabsTrigger({
  className,
  ...props
}: ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        "inline-flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors",
        "hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/40 focus-visible:outline-none",
        "data-[state=active]:bg-card data-[state=active]:text-foreground data-[state=active]:shadow-[var(--shadow-soft)]",
        className,
      )}
      {...props}
    />
  );
}

function TabsContent({
  className,
  ...props
}: ComponentProps<typeof TabsPrimitive.Content>) {
  return (
    <TabsPrimitive.Content
      data-slot="tabs-content"
      className={cn("outline-none", className)}
      {...props}
    />
  );
}

export { Tabs, TabsList, TabsTrigger, TabsContent };
