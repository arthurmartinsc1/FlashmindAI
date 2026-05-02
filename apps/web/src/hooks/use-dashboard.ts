"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchDashboard, fetchDecks } from "@/lib/auth-api";

export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: fetchDashboard,
    staleTime: 60 * 1000,
  });
}

export function useDecks() {
  return useQuery({
    queryKey: ["decks"],
    queryFn: () => fetchDecks({ limit: 12 }),
    staleTime: 60 * 1000,
  });
}
