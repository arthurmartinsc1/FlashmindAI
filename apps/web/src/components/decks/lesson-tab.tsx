"use client";

import { Clock, CheckCircle2, BookOpen } from "lucide-react";
import type { LessonSummary } from "@/types/api";

interface LessonTabProps {
  lessons: LessonSummary[];
  isLoading: boolean;
}

export function LessonTab({ lessons, isLoading }: LessonTabProps) {
  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 2 }).map((_, i) => (
          <div key={i} className="h-16 animate-pulse rounded-xl bg-secondary" />
        ))}
      </div>
    );
  }

  if (lessons.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 py-16 text-center">
        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-secondary">
          <BookOpen className="h-6 w-6 text-muted-foreground" />
        </div>
        <p className="text-sm text-muted-foreground">
          Nenhuma micro-lição neste deck ainda.
          <br />
          Gere com IA na seção correspondente.
        </p>
      </div>
    );
  }

  const done = lessons.filter((l) => l.completed).length;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between text-sm">
        <span className="text-muted-foreground">
          {done}/{lessons.length} lições concluídas
        </span>
        <div className="h-1.5 w-32 overflow-hidden rounded-full bg-secondary">
          <div
            className="h-full rounded-full bg-primary transition-all"
            style={{ width: `${(done / lessons.length) * 100}%` }}
          />
        </div>
      </div>

      <ol className="space-y-2.5">
        {lessons.map((lesson, idx) => (
          <li
            key={lesson.id}
            className="flex items-center gap-4 rounded-xl border border-border bg-card px-4 py-3.5"
          >
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold text-muted-foreground">
              {idx + 1}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{lesson.title}</p>
              <div className="mt-0.5 flex items-center gap-2 text-xs text-muted-foreground">
                <Clock className="h-3 w-3" />
                <span>{lesson.estimated_minutes} min</span>
              </div>
            </div>
            {lesson.completed && (
              <CheckCircle2 className="h-5 w-5 shrink-0 text-emerald-500" />
            )}
          </li>
        ))}
      </ol>
    </div>
  );
}
