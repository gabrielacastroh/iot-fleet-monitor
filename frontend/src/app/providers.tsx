import type { ReactNode } from "react";
import { PersistQueryClientProvider } from "@tanstack/react-query-persist-client";
import { Toaster } from "sonner";
import { OFFLINE_MAX_AGE, queryClient } from "@/lib/api/queryClient";
import { cacheBuster, persister } from "@/lib/api/persister";
import { TooltipProvider } from "@/components/ui/tooltip";

const persistOptions = {
  persister,
  maxAge: OFFLINE_MAX_AGE,
  // Restoring is scoped to the identity the stored token belongs to, so a
  // different user never inherits the previous one's fleet, session or alerts
  // from this browser. Read once at boot, which is when the restore happens.
  buster: cacheBuster(),
};

/** App-wide providers: query cache, tooltips and the toast host every screen
 *  shares. Kept together so `App.tsx` reads as one composition line.
 *
 *  The persisting variant renders its children immediately — restoring from
 *  IndexedDB is a background step, never a splash screen. Screens read
 *  `isPending` (true while restoring, unlike `isLoading`) and keep showing
 *  skeletons instead of flashing an empty state. */
export function Providers({ children }: { children: ReactNode }) {
  return (
    <PersistQueryClientProvider client={queryClient} persistOptions={persistOptions}>
      <TooltipProvider>
        {children}
        <Toaster
          position="bottom-right"
          expand={false}
          closeButton
          toastOptions={{
            classNames: {
              toast:
                "!rounded-xl !border !border-border !bg-card !text-card-foreground !shadow-[var(--shadow-overlay)]",
              description: "!text-muted-foreground",
              actionButton: "!bg-primary !text-primary-foreground",
            },
          }}
        />
      </TooltipProvider>
    </PersistQueryClientProvider>
  );
}
