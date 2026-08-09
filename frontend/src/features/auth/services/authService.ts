import { apiClient } from "@/lib/api/client";
import type { AuthToken, LoginCredentials, RegisterPayload, User } from "../types/auth";

export function login(credentials: LoginCredentials): Promise<AuthToken> {
  const form = new URLSearchParams();
  form.set("username", credentials.username);
  form.set("password", credentials.password);
  return apiClient.post<AuthToken>("/auth/login", form).then((res) => res.data);
}

export function register(payload: RegisterPayload): Promise<User> {
  return apiClient.post<User>("/auth/register", payload).then((res) => res.data);
}

export function getCurrentUser(): Promise<User> {
  return apiClient.get<User>("/auth/me").then((res) => res.data);
}
