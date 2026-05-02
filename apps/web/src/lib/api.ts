"use client";

import axios, { AxiosError, AxiosRequestConfig } from "axios";

import { useAuthStore } from "@/stores/auth-store";
import type { TokenPair } from "@/types/api";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

export const api = axios.create({
  baseURL: API_URL,
  timeout: 15000,
});

/** Extrai mensagem legível de erros Ninja/Axios (`detail` string ou lista). */
export function formatApiError(error: unknown): string {
  if (!axios.isAxiosError(error)) {
    return error instanceof Error ? error.message : "Erro inesperado.";
  }
  const data = error.response?.data as { detail?: unknown } | undefined;
  const detail = data?.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return detail
      .map((item) => (typeof item === "string" ? item : JSON.stringify(item)))
      .join("; ");
  }
  return error.message || "Erro de rede.";
}

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken;
  if (token && !config.headers.Authorization) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ─── Refresh token com anti-stampede ───────────────────────────
// Quando várias requisições recebem 401 ao mesmo tempo, evitamos
// fazer N refreshes paralelos: a primeira dispara o refresh e as
// demais ficam na fila aguardando o novo par de tokens.
type Resolver = (token: string) => void;
type Rejecter = (err: unknown) => void;

let refreshing = false;
let queue: { resolve: Resolver; reject: Rejecter }[] = [];

function drainQueue(error: unknown, token?: string) {
  queue.forEach(({ resolve, reject }) => {
    if (token) resolve(token);
    else reject(error);
  });
  queue = [];
}

async function doRefresh(refreshToken: string): Promise<TokenPair> {
  const resp = await axios.post<TokenPair>(
    `${API_URL}/auth/refresh`,
    { refresh_token: refreshToken },
    { timeout: 10000 },
  );
  return resp.data;
}

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as
      | (AxiosRequestConfig & { _retry?: boolean })
      | undefined;

    if (
      !originalRequest ||
      error.response?.status !== 401 ||
      originalRequest._retry ||
      originalRequest.url?.includes("/auth/refresh") ||
      originalRequest.url?.includes("/auth/login")
    ) {
      return Promise.reject(error);
    }

    const store = useAuthStore.getState();
    if (!store.refreshToken) {
      return Promise.reject(error);
    }

    originalRequest._retry = true;

    if (refreshing) {
      return new Promise((resolve, reject) => {
        queue.push({
          resolve: (token) => {
            originalRequest.headers = originalRequest.headers ?? {};
            (originalRequest.headers as Record<string, string>).Authorization =
              `Bearer ${token}`;
            resolve(api(originalRequest));
          },
          reject,
        });
      });
    }

    refreshing = true;
    try {
      const tokens = await doRefresh(store.refreshToken);
      useAuthStore.getState().setTokens(tokens);
      drainQueue(null, tokens.access_token);
      originalRequest.headers = originalRequest.headers ?? {};
      (originalRequest.headers as Record<string, string>).Authorization =
        `Bearer ${tokens.access_token}`;
      return api(originalRequest);
    } catch (err) {
      drainQueue(err);
      useAuthStore.getState().logout();
      if (typeof window !== "undefined") {
        const here = window.location.pathname;
        if (!here.startsWith("/login") && !here.startsWith("/register")) {
          window.location.href = `/login?next=${encodeURIComponent(here)}`;
        }
      }
      return Promise.reject(err);
    } finally {
      refreshing = false;
    }
  },
);
