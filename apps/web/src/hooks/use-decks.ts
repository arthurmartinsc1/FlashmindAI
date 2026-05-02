"use client";

import { useQueryClient, useQuery, useMutation } from "@tanstack/react-query";
import { fetchDecks, createDeck, deleteDeck } from "@/lib/auth-api";
import type { DeckIn } from "@/types/api";

export function useDecks() {
  const qc = useQueryClient();

  const query = useQuery({
    queryKey: ["decks", ""],
    queryFn: () => fetchDecks({ limit: 100 }),
    staleTime: 30_000,
  });

  const create = useMutation({
    mutationFn: (payload: DeckIn) => createDeck(payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["decks"] }),
  });

  const remove = useMutation({
    mutationFn: (id: string) => deleteDeck(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["decks"] }),
  });

  return { query, create, remove };
}
