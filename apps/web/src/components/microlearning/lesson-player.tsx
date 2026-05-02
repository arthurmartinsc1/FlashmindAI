"use client";

import { useState, useCallback } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import {
  ArrowLeft,
  GraduationCap,
  PartyPopper,
  Loader2,
  CheckCircle2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { BlockText } from "./block-text";
import { BlockHighlight } from "./block-highlight";
import { BlockQuiz } from "./block-quiz";
import type { LessonDetail, ContentBlock } from "@/types/api";

interface LessonPlayerProps {
  lesson: LessonDetail;
  deckId: string;
  onBack: () => void;
  onComplete: (lessonId: string) => Promise<{ unlocked_cards_count: number }>;
  isCompleting?: boolean;
}

export function LessonPlayer({
  lesson,
  deckId,
  onBack,
  onComplete,
  isCompleting,
}: LessonPlayerProps) {
  const blocks = lesson.blocks as ContentBlock[];
  const quizIds = blocks.filter((b) => b.type === "quiz").map((b) => b.id);

  const [answeredQuizzes, setAnsweredQuizzes] = useState<Set<string>>(new Set());
  const [completed, setCompleted] = useState(lesson.completed);
  const [unlockedCards, setUnlockedCards] = useState(0);

  const allAnswered = quizIds.every((id) => answeredQuizzes.has(id));
  const canComplete = allAnswered || quizIds.length === 0;

  const handleAnswer = useCallback((blockId: string) => {
    setAnsweredQuizzes((prev) => new Set([...prev, blockId]));
  }, []);

  async function handleComplete() {
    const result = await onComplete(lesson.id);
    setUnlockedCards(result.unlocked_cards_count);
    setCompleted(true);
  }

  const remainingQuizzes = quizIds.length - answeredQuizzes.size;

  if (completed) {
    return <CompletionScreen deckId={deckId} unlockedCards={unlockedCards} onBack={onBack} />;
  }

  return (
    <div className="space-y-6">
      {/* Back + progress */}
      <div className="flex items-center justify-between">
        <button
          onClick={onBack}
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Lições
        </button>
        {quizIds.length > 0 && (
          <span className="text-xs text-muted-foreground">
            {answeredQuizzes.size}/{quizIds.length} quizzes respondidos
          </span>
        )}
      </div>

      {/* Title */}
      <div>
        <h2 className="text-lg font-semibold">{lesson.title}</h2>
        <p className="mt-0.5 text-xs text-muted-foreground">
          {lesson.estimated_minutes} min · {blocks.length} bloco{blocks.length !== 1 ? "s" : ""}
        </p>
      </div>

      {/* Blocks — scroll contínuo (PRD F7) */}
      <div className="space-y-4">
        {blocks.map((block, idx) => (
          <motion.div
            key={block.id}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25, delay: idx * 0.06 }}
          >
            {block.type === "text" && <BlockText content={block.content} />}
            {block.type === "highlight" && <BlockHighlight content={block.content} />}
            {block.type === "quiz" && (
              <BlockQuiz
                content={block.content}
                onAnswer={() => handleAnswer(block.id)}
              />
            )}
          </motion.div>
        ))}
      </div>

      {/* Completion */}
      <div className="rounded-xl border border-border bg-card p-5">
        {!canComplete ? (
          <p className="text-center text-sm text-muted-foreground">
            Responda {remainingQuizzes > 1 ? `os ${remainingQuizzes} quizzes` : "o quiz"} acima
            para concluir a lição.
          </p>
        ) : (
          <div className="flex flex-col items-center gap-3 text-center">
            <CheckCircle2 className="h-6 w-6 text-emerald-500" />
            <p className="text-sm font-medium">Lição concluída — marque como feita.</p>
            <Button onClick={handleComplete} disabled={isCompleting} className="gap-2">
              {isCompleting ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <PartyPopper className="h-4 w-4" />
              )}
              Concluir lição
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}

function CompletionScreen({
  deckId,
  unlockedCards,
  onBack,
}: {
  deckId: string;
  unlockedCards: number;
  onBack: () => void;
}) {
  return (
    <motion.div
      className="flex flex-col items-center gap-6 py-10 text-center"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3 }}
    >
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/15">
        <PartyPopper className="h-8 w-8 text-emerald-500" />
      </div>
      <div className="space-y-1">
        <h3 className="text-xl font-bold">Lição concluída</h3>
        <p className="text-sm text-muted-foreground">
          {unlockedCards > 0
            ? `${unlockedCards} card${unlockedCards !== 1 ? "s" : ""} liberado${unlockedCards !== 1 ? "s" : ""} para revisão.`
            : "Seu esforço está virando domínio."}
        </p>
      </div>
      <div className="flex flex-wrap justify-center gap-3">
        <Button variant="secondary" onClick={onBack}>
          <ArrowLeft className="h-4 w-4" />
          Outras lições
        </Button>
        <Button asChild>
          <Link href={`/review?deck_id=${deckId}`}>
            <GraduationCap className="h-4 w-4" />
            Revisar flashcards agora
          </Link>
        </Button>
      </div>
    </motion.div>
  );
}
