import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCurrentUser } from "@/features/auth/hooks/useAuth";
import { isAdmin } from "@/lib/utils";
import { countAlerts, listAlerts, resolveAlert } from "../services/alertService";
import type { AlertFilters } from "../services/alertService";

/**
 * The whole `/alerts` router is admin-only, so asking for it as anyone else
 * buys a 403 and an error state nobody can act on — the query stays idle until
 * the session says "admin". This gate is for the UI, not for security: the one
 * that matters lives in the backend.
 *
 * The filters travel in the key so each combination caches on its own; the
 * socket invalidates the `["alerts"]` prefix, which covers all of them.
 */
export function useAlerts(filters: AlertFilters = {}) {
  const { data: user } = useCurrentUser();
  return useQuery({
    queryKey: ["alerts", filters],
    queryFn: () => listAlerts(filters),
    enabled: isAdmin(user),
  });
}

/** How many alerts match, asked of the backend.
 *
 *  `useAlerts(...).data.length` is not this number: the listing is capped at
 *  the backend's page size, so a counter built on it stops at 100 no matter
 *  how many alerts are open. Same `["alerts"]` prefix, so the socket's
 *  invalidation on alert events already covers it. */
export function useAlertsCount(filters: Omit<AlertFilters, "limit"> = {}) {
  const { data: user } = useCurrentUser();
  return useQuery({
    queryKey: ["alerts", "count", filters],
    queryFn: () => countAlerts(filters),
    enabled: isAdmin(user),
  });
}

export function useResolveAlert() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (alertId: string) => resolveAlert(alertId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["alerts"] }),
  });
}
