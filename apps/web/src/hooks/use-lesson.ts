"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchLesson, completeLesson } from "@/lib/auth-api";

export function useLessonDetail(lessonId: string | null) {
  return useQuery({
    queryKey: ["lesson", lessonId],
    queryFn: () => fetchLesson(lessonId!),
    enabled: !!lessonId,
    staleTime: 60_000,
  });
}

export function useLessonComplete(deckId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (lessonId: string) => completeLesson(lessonId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["lessons", deckId] });
      qc.invalidateQueries({ queryKey: ["deck", deckId] });
      qc.invalidateQueries({ queryKey: ["cards", deckId] });
      qc.invalidateQueries({ queryKey: ["decks"] });
      qc.invalidateQueries({ queryKey: ["due-cards"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}
