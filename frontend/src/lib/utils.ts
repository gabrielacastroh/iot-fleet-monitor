import { clsx } from "clsx";
import type { ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import type { User } from "@/features/auth/types/auth";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function isAdmin(user: User | null | undefined): boolean {
  return user?.role === "admin";
}

export function formatDateTime(value: string | null, fallback = "—"): string {
  if (!value) return fallback;
  return new Date(value).toLocaleString("es", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}
