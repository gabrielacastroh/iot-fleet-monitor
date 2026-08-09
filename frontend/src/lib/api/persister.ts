import { del, get, set } from "idb-keyval";
import type { PersistedClient, Persister } from "@tanstack/react-query-persist-client";
import { queryClient } from "./queryClient";

const CACHE_KEY = "fleet-query-cache";

// The same key `authStore` writes the JWT under, duplicated on purpose: this
// module is imported *by* the store, and importing it back would close a cycle
// (client.ts → authStore → here → authStore).
const TOKEN_KEY = "auth_token";

// Every cache event triggers a save, and the telemetry socket writes a reading
// several times per second — unthrottled, each one would cost a full dehydrate
// plus an IndexedDB round trip. Trailing throttle: only the last state inside
// the window reaches disk.
const WRITE_THROTTLE = 2_000;

let writeTimer: ReturnType<typeof setTimeout> | undefined;
let pending: PersistedClient | undefined;

/**
 * Cache partition key for whoever is signed in, taken from the JWT's `sub`.
 *
 * The decode exists ONLY to keep one user from restoring another's fleet,
 * session and alerts off this browser. It authenticates nothing and trusts
 * nothing the token claims — the backend remains the only judge of that. A
 * payload we cannot read falls back to a value derived from the token itself,
 * which is still per-user; a shared constant would be the one fallback that
 * lets two accounts collide.
 */
export function cacheBuster(): string {
  const token = localStorage.getItem(TOKEN_KEY);
  if (!token) return "anon";
  try {
    const segment = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const { sub } = JSON.parse(atob(segment)) as { sub?: unknown };
    if (typeof sub === "string" && sub) return sub;
  } catch {
    // Malformed token: fall through to the token-derived key below.
  }
  return `token:${token.slice(-24)}`;
}

/** The three methods `PersistQueryClientProvider` needs, on IndexedDB —
 *  localStorage would be synchronous and capped at ~5MB, which the telemetry
 *  buffer alone can approach. */
export const persister: Persister = {
  persistClient(client) {
    // The provider snapshots `persistOptions` when it subscribes, which happens
    // before a login can change who is signed in. Stamping the buster at write
    // time keeps the stored cache labelled with its actual owner.
    pending = { ...client, buster: cacheBuster() };
    if (writeTimer) return;
    writeTimer = setTimeout(() => {
      writeTimer = undefined;
      const snapshot = pending;
      pending = undefined;
      if (snapshot) void set(CACHE_KEY, snapshot);
    }, WRITE_THROTTLE);
  },
  restoreClient: () => get<PersistedClient>(CACHE_KEY),
  removeClient() {
    // Drop what the throttle still owes, or a queued write would put the cache
    // we are purging straight back on disk.
    clearTimeout(writeTimer);
    writeTimer = undefined;
    pending = undefined;
    return del(CACHE_KEY);
  },
};

/**
 * Wipes the signed-out user's data from memory and from IndexedDB. The
 * persisted cache holds the fleet, the session (name, email, role) and, for
 * admins, the alerts — all of it outlives the tab, so dropping the token is not
 * enough: the next person to open this browser would restore it.
 *
 * Lives here rather than in the store so `authStore` can call it without
 * importing the provider layer.
 */
export function purgeOfflineCache() {
  // Order matters: clearing the cache emits removal events the persister
  // subscription turns into a write, and `removeClient` cancels that write.
  queryClient.clear();
  void persister.removeClient();
}
