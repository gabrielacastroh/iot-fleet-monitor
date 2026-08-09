import type { ReactNode } from "react";
import {
  TelemetrySocketContext,
  useTelemetryChannel,
} from "../hooks/useTelemetrySocket";

/**
 * Owns the one telemetry socket of the app. Mounted inside the authenticated
 * layout route — it needs a token, and mounting it there means navigation never
 * tears the connection down nor opens a second one. Screens read the state with
 * `useTelemetrySocket()`; the cache writes reach them through TanStack Query.
 */
export function TelemetrySocketProvider({ children }: { children: ReactNode }) {
  const connectionState = useTelemetryChannel();

  return (
    <TelemetrySocketContext.Provider value={connectionState}>
      {children}
    </TelemetrySocketContext.Provider>
  );
}
