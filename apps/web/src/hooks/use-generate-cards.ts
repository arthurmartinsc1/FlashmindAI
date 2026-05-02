"use client";

import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { fetchJob, generateCards } from "@/lib/auth-api";
import { formatApiError } from "@/lib/api";
import type { AsyncJob, GenerateCardsIn } from "@/types/api";

/**
 * Dispara a geração de cards via IA e faz polling do AsyncJob até
 * `completed`/`failed`. Quando concluir, invalida os caches do deck.
 */
export function useGenerateCards(deckId: string) {
  const qc = useQueryClient();
  const [jobId, setJobId] = useState<string | null>(null);

  const start = useMutation({
    mutationFn: (payload: GenerateCardsIn) => generateCards(deckId, payload),
    onSuccess: (createdJob) => {
      qc.setQueryData(["job", createdJob.id], createdJob);
      setJobId(createdJob.id);
    },
  });

  const job = useQuery<AsyncJob>({
    queryKey: ["job", jobId],
    queryFn: () => fetchJob(jobId as string),
    enabled: !!jobId,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === "completed" || status === "failed") return false;
      return 1500;
    },
    refetchIntervalInBackground: true,
  });

  useEffect(() => {
    if (job.data?.status === "completed") {
      qc.invalidateQueries({ queryKey: ["cards", deckId] });
      qc.invalidateQueries({ queryKey: ["deck", deckId] });
      qc.invalidateQueries({ queryKey: ["decks"] });
      qc.invalidateQueries({ queryKey: ["lessons", deckId] });
    }
  }, [job.data?.status, deckId, qc]);

  function reset() {
    setJobId(null);
    start.reset();
  }

  const status =
    job.data?.status ?? (start.isPending ? "pending" : null);
  const isRunning = status === "pending" || status === "running";

  return {
    start: start.mutate,
    startAsync: start.mutateAsync,
    reset,
    job: job.data,
    status,
    isRunning,
    isStarting: start.isPending,
    error:
      job.data?.status === "failed"
        ? job.data.error || "Falha na geração."
        : job.isError
          ? formatApiError(job.error)
          : start.error
            ? formatApiError(start.error)
            : null,
  };
}
