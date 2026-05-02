"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

import type { AuthResponse, TokenPair, User } from "@/types/api";

type AuthState = {
  accessToken: string | null;
  refreshToken: string | null;
  user: User | null;
  hydrated: boolean;

  setTokens: (tokens: TokenPair) => void;
  setUser: (user: User) => void;
  loginWith: (resp: AuthResponse) => void;
  logout: () => void;
  setHydrated: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      accessToken: null,
      refreshToken: null,
      user: null,
      hydrated: false,

      setTokens: (tokens) =>
        set({
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token,
        }),
      setUser: (user) => set({ user }),
      loginWith: ({ tokens, user }) =>
        set({
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token,
          user,
        }),
      logout: () =>
        set({ accessToken: null, refreshToken: null, user: null }),
      setHydrated: () => set({ hydrated: true }),
    }),
    {
      name: "flashmind.auth",
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        user: state.user,
      }),
      onRehydrateStorage: () => (state) => {
        state?.setHydrated();
      },
    },
  ),
);
