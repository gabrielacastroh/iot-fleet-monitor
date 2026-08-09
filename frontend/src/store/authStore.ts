import { create } from "zustand";
import { purgeOfflineCache } from "@/lib/api/persister";

const TOKEN_KEY = "auth_token";

interface AuthState {
  token: string | null;
  login: (token: string) => void;
  logout: () => void;
}

// ponytail: localStorage persistence via a plain read on init, no zustand
// persist middleware — one extra dependency feature we don't need for a
// single string value.
export const useAuthStore = create<AuthState>((set) => ({
  token: localStorage.getItem(TOKEN_KEY),
  login: (token) => {
    localStorage.setItem(TOKEN_KEY, token);
    set({ token });
  },
  logout: () => {
    localStorage.removeItem(TOKEN_KEY);
    set({ token: null });
    // The offline cache survives the tab, so forgetting the token is not enough
    // — this user's fleet, session and alerts have to leave the browser too.
    purgeOfflineCache();
  },
}));
