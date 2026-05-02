"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchDeck,
  updateDeck,
  fetchCards,
  createCard,
  updateCard,
  deleteCard,
  fetchLessons,
} from "@/lib/auth-api";

export function useDeck(id: string) {
  return useQuery({
    queryKey: ["deck", id],
    queryFn: () => fetchDeck(id),
    staleTime: 30_000,
    enabled: !!id,
  });
}

export function useDeckUpdate(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: Parameters<typeof updateDeck>[1]) => updateDeck(id, payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["deck", id] });
      qc.invalidateQueries({ queryKey: ["decks"] });
    },
  });
}

export function useCards(deckId: string, search?: string) {
  return useQuery({
    queryKey: ["cards", deckId, search],
    queryFn: () => fetchCards(deckId, { search: search || undefined, limit: 200 }),
    staleTime: 30_000,
    enabled: !!deckId,
  });
}

export function useCardMutations(deckId: string) {
  const qc = useQueryClient();
  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["cards", deckId] });
    qc.invalidateQueries({ queryKey: ["deck", deckId] });
    qc.invalidateQueries({ queryKey: ["decks"] });
  };

  const add = useMutation({
    mutationFn: (payload: { front: string; back: string; tags?: string[] }) =>
      createCard(deckId, payload),
    onSuccess: invalidate,
  });

  const edit = useMutation({
    mutationFn: ({ id, ...p }: { id: string; front?: string; back?: string }) =>
      updateCard(id, p),
    onSuccess: invalidate,
  });

  const remove = useMutation({
    mutationFn: (cardId: string) => deleteCard(cardId),
    onSuccess: invalidate,
  });

  return { add, edit, remove };
}

export function useLessons(deckId: string) {
  return useQuery({
    queryKey: ["lessons", deckId],
    queryFn: () => fetchLessons(deckId),
    staleTime: 60_000,
    enabled: !!deckId,
  });
}
