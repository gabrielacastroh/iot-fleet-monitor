import { QueryClient } from "@tanstack/react-query";

/**
 * How long a persisted cache may still be restored — and, because only queries
 * the in-memory cache still holds get written out at all, how long an unused
 * query is kept. A `gcTime` below the persisted `maxAge` is the classic bug
 * here: the query is collected first and there is nothing left to persist, so
 * both numbers come from this one constant.
 *
 * Six hours is a work shift. Long enough that a tablet in a garage or a laptop
 * reopened after lunch still shows the fleet it last saw; short enough that we
 * never repaint yesterday's positions on the map as if they were current. Newer
 * data arrives on its own the moment the network is back — `refetchOnReconnect`
 * plus the telemetry socket's invalidation already cover that.
 */
export const OFFLINE_MAX_AGE = 6 * 60 * 60 * 1000;

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: OFFLINE_MAX_AGE,
      retry: 1,
    },
    mutations: {
      // Offline, the default ("online") leaves a mutation paused with no
      // outcome: the delete dialog spins forever and the device form never
      // answers. Letting it run means axios fails immediately and the user gets
      // the interceptor's "sin conexión" toast instead of a hang.
      networkMode: "always",
    },
  },
});
