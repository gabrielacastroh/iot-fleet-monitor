import axios from "axios";
import { onlineManager } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAuthStore } from "@/store/authStore";

export const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

export const apiClient = axios.create({ baseURL: API_URL });

apiClient.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.set("Authorization", `Bearer ${token}`);
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error: unknown) => {
    const status = axios.isAxiosError(error) ? error.response?.status : undefined;

    if (status === 401) {
      // The session expired — ProtectedRoute redirects on its own once the
      // token clears, so logging out here is all that is needed.
      useAuthStore.getState().logout();
    } else if (status === undefined || status >= 500) {
      // Every 4xx already has a caller that turns it into a field error or an
      // inline message (login, device form, delete confirm...) — toasting it
      // here too would just say the same thing twice. Only the failures no
      // caller can explain (network down, CORS, a broken backend) land here.
      // Offline the cause is known, so name it: "el servidor no responde" would
      // send the user looking for a problem that is on their side of the wire.
      // Reads keep working from the cache; only writes are lost.
      toast.error(
        onlineManager.isOnline()
          ? "No pudimos conectar con el servidor. Inténtalo de nuevo en unos segundos."
          : "Sin conexión. No podemos guardar cambios hasta que vuelva la red.",
      );
    }

    // Always re-thrown so a mutation/query's own onError can still react
    // (e.g. a form showing a field-level message).
    return Promise.reject(error);
  },
);
