"use client";

import { useState } from "react";
import { Clock, CheckCircle2, BookOpen, ChevronRight, Loader2, GraduationCap } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { LessonPlayer } from "./lesson-player";
import { useLessonDetail, useLessonComplete } from "@/hooks/use-lesson";
import type { LessonSummary } from "@/types/api";

interface MicrolearningTabProps {
  deckId: string;
  lessons: LessonSummary[];
  isLoading: boolean;
}

export function MicrolearningTab({ deckId, lessons, isLoading }: MicrolearningTabProps) {
  const [openLessonId, setOpenLessonId] = useState<string | null>(null);

  const lessonDetail = useLessonDetail(openLessonId);
  const complete = useLessonComplete(deckId);

  async function handleComplete(lessonId: string) {
    const result = await complete.mutateAsync(lessonId);
    return { unlocked_cards_count: result.unlocked_cards_count };
  }

  // ── Loading skeleton ──────────────────────────────────────
  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-16 animate-pulse rounded-xl bg-secondary" />
        ))}
      </div>
    );
  }

  // ── Empty state ───────────────────────────────────────────
  if (lessons.length === 0) {
    return (
      <div className="flex flex-col items-center gap-6 py-14 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-violet-500/10">
          <BookOpen className="h-7 w-7 text-violet-500" />
        </div>
        <div className="max-w-sm space-y-1.5">
          <h3 className="font-semibold">Ainda não há micro-lições</h3>
          <p className="text-sm text-muted-foreground">
            Micro-lições são conteúdos curtos (texto, quizzes e destaques) que ensinam
            o tema do deck antes de você revisar os flashcards. Cada lição leva
            cerca de 5 minutos.
          </p>
        </div>
        <p className="max-w-xs text-xs text-muted-foreground">
          As micro-lições são criadas automaticamente quando você gera cards
          com IA. Use o botão{" "}
          <span className="font-medium text-foreground">Gerar com IA</span>{" "}
          na aba <span className="font-medium text-foreground">Cards</span> para começar.
        </p>
      </div>
    );
  }

  // ── Player ────────────────────────────────────────────────
  if (openLessonId) {
    return (
      <AnimatePresence mode="wait">
        {lessonDetail.isLoading ? (
          <motion.div
            key="loading"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="flex min-h-[200px] items-center justify-center"
          >
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </motion.div>
        ) : lessonDetail.data ? (
          <motion.div
            key="player"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
          >
            <LessonPlayer
              lesson={lessonDetail.data}
              deckId={deckId}
              onBack={() => setOpenLessonId(null)}
              onComplete={handleComplete}
              isCompleting={complete.isPending}
            />
          </motion.div>
        ) : null}
      </AnimatePresence>
    );
  }

  // ── Lesson list ───────────────────────────────────────────
  const MAX_LESSONS = 3;
  const done = lessons.filter((l) => l.completed).length;
  const allDone = done === lessons.length;
  const atLimit = lessons.length >= MAX_LESSONS;

  return (
    <motion.div
      key="list"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="space-y-5"
    >
      {/* Header */}
      <div className="flex items-center justify-between gap-4">
        <div>
          <h3 className="text-sm font-semibold">
            {allDone ? "Todas as lições concluídas!" : "Sua trilha de lições"}
          </h3>
          <p className="text-xs text-muted-foreground">
            {done} de {lessons.length} concluída{done !== 1 ? "s" : ""}
          </p>
        </div>
        {/* Progress bar */}
        <div className="h-1.5 w-28 shrink-0 overflow-hidden rounded-full bg-secondary">
          <div
            className="h-full rounded-full bg-primary transition-all duration-500"
            style={{ width: `${(done / lessons.length) * 100}%` }}
          />
        </div>
      </div>

      {/* Limite atingido */}
      {atLimit && !allDone && (
        <div className="rounded-xl border border-amber-500/20 bg-amber-500/5 px-4 py-3 text-sm text-muted-foreground">
          <span className="font-medium text-foreground">Limite de {MAX_LESSONS} lições atingido.</span>{" "}
          Conclua as lições abaixo antes de gerar mais conteúdo com IA.
        </div>
      )}

      {/* What are micro-lições — compact callout for first-timers */}
      {done === 0 && !atLimit && (
        <div className="rounded-xl border border-violet-500/20 bg-violet-500/5 px-4 py-3 text-sm text-muted-foreground">
          <span className="font-medium text-foreground">O que são micro-lições?</span>{" "}
          Conteúdos de 5 minutos com texto, quizzes e destaques que preparam você
          para revisar os flashcards com mais eficiência.
        </div>
      )}

      {/* CTA after all done */}
      {allDone && (
        <div className="flex items-center justify-between gap-4 rounded-xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3">
          <p className="text-sm text-emerald-700 dark:text-emerald-400">
            Ótimo trabalho! Hora de revisar os flashcards.
          </p>
          <Button size="sm" asChild>
            <Link href={`/review?deck_id=${deckId}`}>
              <GraduationCap className="h-3.5 w-3.5" />
              Revisar
            </Link>
          </Button>
        </div>
      )}

      {/* List */}
      <ol className="space-y-2.5">
        {lessons.map((lesson, idx) => {
          const isNext = !lesson.completed && lessons.slice(0, idx).every((l) => l.completed);
          return (
            <li key={lesson.id}>
              <button
                onClick={() => setOpenLessonId(lesson.id)}
                className="group flex w-full items-center gap-4 rounded-xl border border-border bg-card px-4 py-3.5 text-left transition-all hover:border-primary/40 hover:shadow-sm"
              >
                {/* Status icon */}
                {lesson.completed ? (
                  <CheckCircle2 className="h-6 w-6 shrink-0 text-emerald-500" />
                ) : (
                  <span
                    className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${
                      isNext
                        ? "bg-primary text-primary-foreground"
                        : "bg-secondary text-muted-foreground"
                    }`}
                  >
                    {idx + 1}
                  </span>
                )}

                {/* Meta */}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{lesson.title}</p>
                  <div className="mt-0.5 flex items-center gap-2 text-xs text-muted-foreground">
                    <Clock className="h-3 w-3" />
                    <span>{lesson.estimated_minutes} min</span>
                    {lesson.completed && (
                      <span className="text-emerald-600 dark:text-emerald-400">· Concluída</span>
                    )}
                    {isNext && !lesson.completed && (
                      <span className="text-primary">· Próxima</span>
                    )}
                  </div>
                </div>

                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </button>
            </li>
          );
        })}
      </ol>
    </motion.div>
  );
}
