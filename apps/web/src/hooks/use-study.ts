"use client";

import { useCallback, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchDueCards, submitReview } from "@/lib/auth-api";
import type { Card } from "@/types/api";

export type SessionResult = {
  card: Card;
  quality: number;
  timeMs: number;
};

export function useStudy(deckId?: string) {
  const qc = useQueryClient();

  const dueQuery = useQuery({
    queryKey: ["due-cards", deckId ?? "all"],
    queryFn: () => fetchDueCards(deckId ? { deck_id: deckId, limit: 200 } : { limit: 200 }),
  });

  const [index, setIndex] = useState(0);
  const [results, setResults] = useState<SessionResult[]>([]);
  const [done, setDone] = useState(false);
  const cardStartRef = useRef<number>(Date.now());

  const cards = dueQuery.data?.cards ?? [];
  const current = cards[index] ?? null;

  const reviewMutation = useMutation({
    mutationFn: ({ cardId, quality, timeMs }: { cardId: string; quality: number; timeMs: number }) =>
      submitReview(cardId, { quality, time_spent_ms: timeMs }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });

  const onCardStart = useCallback(() => {
    cardStartRef.current = Date.now();
  }, []);

  const rate = useCallback(
    (quality: number) => {
      if (!current) return;
      const timeMs = Date.now() - cardStartRef.current;
      reviewMutation.mutate({ cardId: current.id, quality, timeMs });
      setResults((prev) => [...prev, { card: current, quality, timeMs }]);
      const next = index + 1;
      if (next >= cards.length) {
        setDone(true);
      } else {
        setIndex(next);
        cardStartRef.current = Date.now();
      }
    },
    [current, index, cards.length, reviewMutation],
  );

  const restart = useCallback(() => {
    setIndex(0);
    setResults([]);
    setDone(false);
    qc.invalidateQueries({ queryKey: ["due-cards", deckId ?? "all"] });
  }, [qc, deckId]);

  return {
    isLoading: dueQuery.isLoading,
    cards,
    current,
    index,
    total: cards.length,
    results,
    done,
    rate,
    restart,
    onCardStart,
  };
}
