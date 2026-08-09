import { createContext, useContext, useEffect, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/store/authStore";
import type { TelemetryReading } from "../types/telemetry";

const WS_URL = import.meta.env.VITE_WS_URL ?? "ws://localhost:8000/ws/telemetry";
const TELEMETRY_LIMIT = 200;

const RETRY_BASE_DELAY = 1_000;
const RETRY_MAX_DELAY = 30_000;
// The backend rejects a bad token by closing before it accepts the socket,
// which the browser reports as 1006 — the same code a dropped network gives,
// so the two are indistinguishable here. Retrying forever would poll the
// server every 30s for a credential that will never work, so the budget stops
// after ~2 minutes of backoff; `online` and tab focus start it over, which is
// a far better signal to retry on than a timer.
const MAX_RETRIES = 8;

// `device.last_seen_at` only changes through GET /devices, so the table's
// "última conexión" column goes stale while telemetry keeps flowing. The
// simulator emits several readings per second, so invalidating per message
// would mean a request per message. 20s bounds the staleness well under the
// minute a human reads that column at, while capping the refetch at 3/min.
const DEVICES_REFRESH_INTERVAL = 20_000;

export type ConnectionState = "connecting" | "open" | "reconnecting" | "closed";

export const TelemetrySocketContext = createContext<ConnectionState | undefined>(
  undefined,
);

/** Connection state of the app-wide telemetry socket, published by
 *  `TelemetrySocketProvider`. */
export function useTelemetrySocket(): ConnectionState {
  const state = useContext(TelemetrySocketContext);
  if (state === undefined) {
    throw new Error("useTelemetrySocket must be used inside <TelemetrySocketProvider>");
  }
  return state;
}

/**
 * Live telemetry channel. Driven once by `TelemetrySocketProvider` inside the
 * authenticated layout, so every screen shares a single connection that
 * survives navigation.
 *
 * The backend authenticates this socket the same way it authenticates every
 * other request — a browser's WebSocket API just cannot attach an
 * Authorization header to the upgrade request, so the token travels as a
 * query parameter instead.
 *
 * Each incoming reading is written straight into the `["telemetry"]` query
 * cache instead of local state, so the socket feeds the same list the charts,
 * KPIs and map already read from `useTelemetryQuery` — no separate "live
 * feed" state to keep in sync.
 */
export function useTelemetryChannel(): ConnectionState {
  const token = useAuthStore((state) => state.token);
  const queryClient = useQueryClient();
  const [connectionState, setConnectionState] = useState<ConnectionState>("connecting");

  useEffect(() => {
    if (!token) {
      setConnectionState("closed");
      return;
    }

    const url = `${WS_URL}?token=${encodeURIComponent(token)}`;

    // Closing a socket that is still CONNECTING does not always reach the
    // server, so a connection opened after the effect was torn down has to be
    // closed on arrival — otherwise every visit leaks one.
    let disposed = false;
    let socket: WebSocket | null = null;
    let retryTimer: ReturnType<typeof setTimeout> | undefined;
    let retries = 0;
    let reconnected = false;
    // Timestamp instead of a timer: nothing to cancel on unmount.
    let devicesRefreshedAt = Date.now();

    function connect() {
      const current = new WebSocket(url);
      socket = current;

      current.onopen = () => {
        if (disposed) {
          current.close();
          return;
        }
        setConnectionState("open");
        retries = 0;
        if (reconnected) {
          // Every event pushed while the socket was down is gone — the channel
          // has no replay. Refetching is the only way to close the gap between
          // the caches and the server.
          void queryClient.invalidateQueries({ queryKey: ["telemetry"] });
          void queryClient.invalidateQueries({ queryKey: ["devices"] });
          void queryClient.invalidateQueries({ queryKey: ["alerts"] });
        }
        reconnected = true;
      };

      current.onerror = (event) => {
        console.error("[useTelemetryChannel]", event);
      };

      current.onclose = (event) => {
        if (disposed) return;
        // 1008 only arrives if the server closes an already-accepted socket
        // because its token is no longer valid — mirror the REST 401
        // interceptor and drop the session instead of retrying against a
        // credential that will never work.
        if (event.code === 1008) {
          setConnectionState("closed");
          useAuthStore.getState().logout();
          return;
        }
        // A rejected handshake surfaces as 1006 and is handled by the retry
        // budget below — there is nothing to retry against here either.
        if (retries >= MAX_RETRIES) {
          setConnectionState("closed");
          return;
        }
        setConnectionState("reconnecting");
        // Exponential backoff with jitter so a backend restart does not bring
        // every open tab back in the same millisecond.
        const delay = Math.min(RETRY_BASE_DELAY * 2 ** retries, RETRY_MAX_DELAY);
        retries += 1;
        retryTimer = setTimeout(connect, delay * (0.5 + Math.random() * 0.5));
      };

      current.onmessage = (event) => {
        if (disposed) return;
        // The backend wraps every event as { type, data } — telemetry_updated,
        // alert_created and alert_resolved all share the channel. A payload
        // that fails to parse, or isn't a reading, is dropped rather than
        // guessed at: the query cache is typed TelemetryReading[] and pushing
        // an alert envelope in as-is fed undefined lat/lng into the map.
        let message: { type?: string; data?: Record<string, unknown> };
        try {
          message = JSON.parse(event.data);
        } catch {
          return;
        }

        if (message.type === "alert_created" || message.type === "alert_resolved") {
          // Invalidate instead of patching: several filter combinations are
          // cached at once and each one would need its own "does this alert
          // belong here now?" decision — and alert_resolved carries neither
          // message nor created_at, so the record cannot even be rebuilt from
          // the event. Refetching leaves the server as the source of truth.
          void queryClient.invalidateQueries({ queryKey: ["alerts"] });
          return;
        }

        if (message.type !== "telemetry_updated" || !message.data) return;
        const payload = message.data;
        const reading: TelemetryReading = {
          id: payload.reading_id as string,
          device_id: payload.device_id as string,
          latitude: payload.latitude as number,
          longitude: payload.longitude as number,
          speed: payload.speed as number,
          fuel_level: payload.fuel_level as number,
          temperature: payload.temperature as number,
          recorded_at: payload.recorded_at as string,
        };
        queryClient.setQueryData<TelemetryReading[]>(["telemetry"], (prev = []) =>
          [...prev, reading].slice(-TELEMETRY_LIMIT),
        );
        // The per-device cache is a set, not a window: replace this device's
        // row instead of appending, or it would grow without bound and stop
        // being "one reading per device".
        //
        // Only patched when something is already cached — returning undefined
        // leaves the query untouched, so a socket message that lands before
        // the first fetch cannot seed a cache holding a single vehicle.
        // The counter is a server-side count over a sliding window, keyed by
        // the window's start — which this handler has no business knowing, so
        // it patches every cached count instead of one. A reading arriving now
        // is inside any window that ends now, so +1 holds for all of them; the
        // key rolling over each minute is what drops the ones that aged out.
        queryClient.setQueriesData<number>(
          { queryKey: ["telemetry", "count"] },
          (prev) => (prev === undefined ? prev : prev + 1),
        );
        queryClient.setQueryData<TelemetryReading[]>(["telemetry", "latest"], (prev) =>
          prev
            ? [...prev.filter((item) => item.device_id !== reading.device_id), reading]
            : prev,
        );

        const now = Date.now();
        if (now - devicesRefreshedAt >= DEVICES_REFRESH_INTERVAL) {
          devicesRefreshedAt = now;
          void queryClient.invalidateQueries({ queryKey: ["devices"] });
        }
      };
    }

    /**
     * A restored network or a tab coming back to the foreground says more than
     * the backoff clock does: the machine that just woke up has been offline
     * for minutes, and waiting out a 30s timer — or worse, having spent the
     * retry budget while asleep — would leave the screen stale. Retry at once
     * and start the budget over.
     */
    function retryNow() {
      if (disposed || !navigator.onLine) return;
      // A live or in-flight socket needs no help; reconnecting on top of one
      // is how you end up with two.
      if (
        socket &&
        (socket.readyState === WebSocket.OPEN ||
          socket.readyState === WebSocket.CONNECTING)
      ) {
        return;
      }
      clearTimeout(retryTimer);
      retries = 0;
      setConnectionState("reconnecting");
      connect();
    }

    function onVisibilityChange() {
      if (document.visibilityState === "visible") retryNow();
    }

    // Neither browser nor server ping/pong this socket, so a lost network
    // would otherwise sit as a silently open readyState until the OS times
    // out the TCP connection. `navigator.onLine`'s own `offline` event is a
    // reliable, already-available signal — ride it instead of adding a
    // heartbeat. Retrying while offline would just fail again, so this only
    // updates the state and drops the socket; `retryNow` on `online` does the
    // reconnect.
    function onOffline() {
      if (disposed) return;
      clearTimeout(retryTimer);
      retries = 0;
      setConnectionState("closed");
      if (socket && socket.readyState !== WebSocket.CLOSED) socket.close();
    }

    window.addEventListener("online", retryNow);
    window.addEventListener("offline", onOffline);
    document.addEventListener("visibilitychange", onVisibilityChange);

    connect();

    return () => {
      disposed = true;
      clearTimeout(retryTimer);
      window.removeEventListener("online", retryNow);
      window.removeEventListener("offline", onOffline);
      document.removeEventListener("visibilitychange", onVisibilityChange);
      if (socket && socket.readyState === WebSocket.OPEN) socket.close();
    };
  }, [token, queryClient]);

  return connectionState;
}
