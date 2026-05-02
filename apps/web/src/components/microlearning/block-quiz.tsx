"use client";

import { useState } from "react";
import { CheckCircle2, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import type { QuizBlockContent } from "@/types/api";

const LETTERS = ["A", "B", "C", "D", "E", "F"] as const;

interface BlockQuizProps {
  content: QuizBlockContent;
  onAnswer?: (correct: boolean) => void;
}

export function BlockQuiz({ content, onAnswer }: BlockQuizProps) {
  const [selected, setSelected] = useState<number | null>(null);
  const answered = selected !== null;
  const isCorrect = selected === content.correct;

  function pick(idx: number) {
    if (answered) return;
    setSelected(idx);
    onAnswer?.(idx === content.correct);
  }

  return (
    <div className="space-y-4 rounded-xl border border-border bg-card p-5">
      <p className="text-sm font-semibold leading-snug">{content.question}</p>

      <ul className="space-y-2">
        {content.options.map((option, idx) => {
          const isSelected  = selected === idx;
          const isRight     = idx === content.correct;

          let stateClass = "border-border bg-background hover:border-primary/50 hover:bg-primary/5";
          if (answered) {
            if (isRight)                         stateClass = "border-emerald-500 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300";
            else if (isSelected && !isCorrect)   stateClass = "border-red-500 bg-red-500/10 text-red-700 dark:text-red-300";
            else                                 stateClass = "border-border/50 opacity-50";
          }

          return (
            <li key={idx}>
              <button
                onClick={() => pick(idx)}
                disabled={answered}
                className={cn(
                  "flex w-full items-center gap-3 rounded-lg border px-4 py-3 text-left text-sm transition-colors",
                  stateClass,
                )}
              >
                <span className={cn(
                  "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                  answered && isRight     ? "bg-emerald-500 text-white"
                  : answered && isSelected ? "bg-red-500 text-white"
                  : "bg-secondary text-muted-foreground",
                )}>
                  {LETTERS[idx]}
                </span>
                <span className="flex-1">{option}</span>
                {answered && isRight     && <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-500" />}
                {answered && isSelected && !isCorrect && <XCircle className="h-4 w-4 shrink-0 text-red-500" />}
              </button>
            </li>
          );
        })}
      </ul>

      {answered && (
        <div className={cn(
          "flex items-start gap-2 rounded-lg px-4 py-3 text-sm",
          isCorrect
            ? "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
            : "bg-red-500/10 text-red-700 dark:text-red-300",
        )}>
          {isCorrect
            ? <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            : <XCircle className="mt-0.5 h-4 w-4 shrink-0" />
          }
          <span>
            <strong>{isCorrect ? "Correto!" : "Incorreto."}</strong>
            {content.explanation && <span className="ml-1">{content.explanation}</span>}
          </span>
        </div>
      )}
    </div>
  );
}
