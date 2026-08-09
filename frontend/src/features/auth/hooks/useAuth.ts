import { useMutation, useQuery } from "@tanstack/react-query";
import { useAuthStore } from "@/store/authStore";
import { getCurrentUser, login, register } from "../services/authService";
import type { LoginCredentials, RegisterPayload } from "../types/auth";

export function useLogin() {
  return useMutation({
    mutationFn: (credentials: LoginCredentials) => login(credentials),
    onSuccess: ({ access_token }) => {
      useAuthStore.getState().login(access_token);
    },
  });
}

export function useRegister() {
  return useMutation({
    // The account is useless until it can be used — sign the new user in
    // right away instead of bouncing them back to the login form.
    mutationFn: async (payload: RegisterPayload) => {
      await register(payload);
      return login({ username: payload.email, password: payload.password });
    },
    onSuccess: ({ access_token }) => {
      useAuthStore.getState().login(access_token);
    },
  });
}

/**
 * Session data (who is logged in, what they may do). Queried by the layout
 * because the profile and the role are on screen everywhere. A failed
 * `/auth/me` just means no admin affordances are shown — it does not break
 * the screen.
 */
export function useCurrentUser() {
  const token = useAuthStore((state) => state.token);
  return useQuery({
    queryKey: ["session"],
    queryFn: getCurrentUser,
    enabled: Boolean(token),
  });
}
