"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { GraduationCap, Loader2, ArrowLeft, ChevronRight, Lock, X, BookOpenText } from "lucide-react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { useStudy } from "@/hooks/use-study";
import { FlipCard } from "@/components/study/flip-card";
import { RatingButtons } from "@/components/study/rating-buttons";
import { StudyProgress } from "@/components/study/study-progress";
import { StudySummary } from "@/components/study/study-summary";
import { fetchDecks } from "@/lib/auth-api";
import type { Deck } from "@/types/api";

export default function ReviewPage() {
  const searchParams = useSearchParams();
  const deckId = searchParams.get("deck_id") ?? undefined;

  if (!deckId) {
    return <DeckSelectionScreen />;
  }

  return <ReviewSession deckId={deckId} />;
}

// ── Locked deck modal ─────────────────────────────────────────

function LockedDeckModal({ deck, onClose }: { deck: Deck; onClose: () => void }) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" />

      <motion.div
        className="relative w-full max-w-sm rounded-2xl border border-border bg-card p-6 shadow-xl"
        initial={{ opacity: 0, scale: 0.95, y: 8 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.2 }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          className="absolute right-4 top-4 rounded-lg p-1 text-muted-foreground hover:bg-secondary hover:text-foreground"
        >
          <X className="h-4 w-4" />
        </button>

        <div className="flex flex-col items-center gap-4 text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-amber-500/10">
            <Lock className="h-7 w-7 text-amber-500" />
          </div>

          <div className="space-y-1.5">
            <h3 className="text-base font-semibold">{deck.title}</h3>
            <p className="text-sm text-muted-foreground">
              {deck.lesson_locked_cards_count} flashcard
              {deck.lesson_locked_cards_count !== 1 ? "s" : ""}{" "}
              {deck.lesson_locked_cards_count !== 1 ? "estão bloqueados" : "está bloqueado"} até você concluir a
              micro-lição — assim você revisa com contexto.
            </p>
          </div>

          <div className="w-full rounded-xl border border-amber-500/20 bg-amber-500/5 px-4 py-3 text-xs text-muted-foreground">
            Conclua a micro-lição e os cards aparecem aqui hoje mesmo.
          </div>

          <Button className="w-full gap-2" asChild>
            <Link href={`/decks/${deck.id}`}>
              <BookOpenText className="h-4 w-4" />
              Ir para a micro-lição
            </Link>
          </Button>

          <button
            onClick={onClose}
            className="text-xs text-muted-foreground hover:text-foreground"
          >
            Fechar
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ── Deck selection ────────────────────────────────────────────

function DeckSelectionScreen() {
  const [lockedDeck, setLockedDeck] = useState<Deck | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["decks", ""],
    queryFn: () => fetchDecks({ limit: 100 }),
    staleTime: 30_000,
  });

  const allDecks = data?.decks ?? [];
  const decksWithDue = allDecks.filter((d: Deck) => d.due_count > 0);
  const decksLocked = allDecks.filter(
    (d: Deck) => d.due_count === 0 && d.lesson_locked_cards_count > 0 && d.has_pending_lesson_gate,
  );
  const totalDue = decksWithDue.reduce((acc: number, d: Deck) => acc + d.due_count, 0);
  const hasAnything = decksWithDue.length > 0 || decksLocked.length > 0;

  if (isLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!hasAnything) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
          <GraduationCap className="h-8 w-8 text-emerald-500" />
        </div>
        <div className="space-y-1.5">
          <h2 className="text-xl font-semibold">Tudo em dia!</h2>
          <p className="max-w-xs text-sm text-muted-foreground">
            Nenhum card vence hoje. O algoritmo já agendou suas próximas revisões
            — aparecem aqui quando chegar a hora certa.
          </p>
        </div>
        <div className="flex flex-wrap justify-center gap-3">
          <Button variant="secondary" asChild>
            <Link href="/decks">Ver meus decks</Link>
          </Button>
          <Button asChild>
            <Link href="/dashboard">Ir para o Dashboard</Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <>
      <div className="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 className="text-xl font-bold">Revisar hoje</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            {totalDue > 0
              ? `${totalDue} card${totalDue !== 1 ? "s" : ""} pendente${totalDue !== 1 ? "s" : ""}`
              : "Nenhum card disponível agora"}
            {decksLocked.length > 0 && ` · ${decksLocked.length} deck${decksLocked.length !== 1 ? "s" : ""} bloqueado${decksLocked.length !== 1 ? "s" : ""}`}
          </p>
        </div>

        <motion.div
          className="space-y-2.5"
          initial="hidden"
          animate="show"
          variants={{ show: { transition: { staggerChildren: 0.06 } } }}
        >
          {/* Decks disponíveis */}
          {decksWithDue.map((deck: Deck) => (
            <motion.div
              key={deck.id}
              variants={{ hidden: { opacity: 0, y: 10 }, show: { opacity: 1, y: 0 } }}
            >
              <Link
                href={`/review?deck_id=${deck.id}`}
                className="group flex w-full items-center gap-4 rounded-xl border border-border bg-card px-4 py-4 text-left transition-all hover:border-primary/40 hover:shadow-sm"
              >
                <span
                  className="h-4 w-4 shrink-0 rounded-full"
                  style={{ backgroundColor: deck.color }}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{deck.title}</p>
                  {deck.description && (
                    <p className="mt-0.5 truncate text-xs text-muted-foreground">{deck.description}</p>
                  )}
                </div>
                <span className="shrink-0 rounded-full bg-primary/10 px-2.5 py-0.5 text-xs font-semibold text-primary">
                  {deck.due_count} {deck.due_count === 1 ? "card" : "cards"}
                </span>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </Link>
            </motion.div>
          ))}

          {/* Separador se houver ambas as seções */}
          {decksWithDue.length > 0 && decksLocked.length > 0 && (
            <motion.p
              variants={{ hidden: { opacity: 0 }, show: { opacity: 1 } }}
              className="pt-1 text-xs font-medium text-muted-foreground"
            >
              Aguardando micro-lição
            </motion.p>
          )}

          {/* Decks bloqueados */}
          {decksLocked.map((deck: Deck) => (
            <motion.div
              key={deck.id}
              variants={{ hidden: { opacity: 0, y: 10 }, show: { opacity: 1, y: 0 } }}
            >
              <button
                onClick={() => setLockedDeck(deck)}
                className="group flex w-full items-center gap-4 rounded-xl border border-border bg-card px-4 py-4 text-left opacity-60 transition-all hover:border-amber-400/40 hover:opacity-80"
              >
                <span
                  className="h-4 w-4 shrink-0 rounded-full"
                  style={{ backgroundColor: deck.color }}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{deck.title}</p>
                  {deck.description && (
                    <p className="mt-0.5 truncate text-xs text-muted-foreground">{deck.description}</p>
                  )}
                </div>
                <span className="shrink-0 rounded-full bg-amber-500/10 px-2.5 py-0.5 text-xs font-semibold text-amber-600 dark:text-amber-400">
                  {deck.lesson_locked_cards_count} bloqueado{deck.lesson_locked_cards_count !== 1 ? "s" : ""}
                </span>
                <Lock className="h-4 w-4 shrink-0 text-amber-500" />
              </button>
            </motion.div>
          ))}
        </motion.div>
      </div>

      {/* Modal */}
      <AnimatePresence>
        {lockedDeck && (
          <LockedDeckModal deck={lockedDeck} onClose={() => setLockedDeck(null)} />
        )}
      </AnimatePresence>
    </>
  );
}

// ── Review session ────────────────────────────────────────────

function ReviewSession({ deckId }: { deckId: string }) {
  const { isLoading, current, index, total, results, done, rate, restart, onCardStart } =
    useStudy(deckId);
  const [revealed, setRevealed] = useState(false);

  function handleFlip() {
    setRevealed(true);
    onCardStart();
  }

  function handleRate(quality: number) {
    setRevealed(false);
    rate(quality);
  }

  if (isLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (done) {
    return (
      <div className="mx-auto max-w-6xl">
        <StudySummary results={results} onRestart={restart} />
      </div>
    );
  }

  if (total === 0) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
          <GraduationCap className="h-8 w-8 text-emerald-500" />
        </div>
        <div className="space-y-1.5">
          <h2 className="text-xl font-semibold">Tudo em dia!</h2>
          <p className="max-w-xs text-sm text-muted-foreground">
            Nenhum card vence hoje neste deck.
          </p>
        </div>
        <Button variant="secondary" asChild>
          <Link href="/review">
            <ArrowLeft className="h-4 w-4" />
            Outros decks
          </Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6">
      <header className="flex items-center justify-between">
        <Link
          href="/review"
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Decks
        </Link>
        <span className="text-sm text-muted-foreground">
          {index + 1} / {total}
        </span>
      </header>

      <StudyProgress current={index} total={total} />

      <AnimatePresence mode="wait">
        {current && (
          <motion.div
            key={current.id}
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -40 }}
            transition={{ duration: 0.22 }}
          >
            <FlipCard front={current.front} back={current.back} onFlip={handleFlip} />
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {revealed ? (
          <div className="space-y-3">
            <p className="text-center text-xs text-muted-foreground">
              Como foi sua lembrança?
            </p>
            <RatingButtons onRate={handleRate} />
          </div>
        ) : (
          <p className="text-center text-xs text-muted-foreground">
            Pense na resposta e clique no card para revelar
          </p>
        )}
      </AnimatePresence>
    </div>
  );
}
