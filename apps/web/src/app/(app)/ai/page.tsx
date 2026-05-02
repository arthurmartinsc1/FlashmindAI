"use client";

import { useState } from "react";
import Link from "next/link";
import {
  Sparkles,
  Loader2,
  CheckCircle2,
  AlertCircle,
  BookOpen,
  Plus,
  ArrowRight,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { CreateDeckModal } from "@/components/decks/create-deck-modal";
import { useDecks } from "@/hooks/use-decks";
import { useGenerateCards } from "@/hooks/use-generate-cards";

export default function AIPage() {
  const { query: decksQuery, create } = useDecks();
  const decks = decksQuery.data?.decks ?? [];

  const [deckId, setDeckId] = useState("");
  const [topic, setTopic] = useState("");
  const [count, setCount] = useState(8);
  const [language, setLanguage] = useState("pt-BR");
  const [sourceText, setSourceText] = useState("");
  const [newDeckModal, setNewDeckModal] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const { start, status, isRunning, job, error, reset, isStarting } =
    useGenerateCards(deckId);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!deckId || !topic.trim() || isRunning) return;
    setSubmitted(true);
    start({ topic: topic.trim(), count, language, source_text: sourceText.trim() || undefined });
  }

  function handleReset() {
    setSubmitted(false);
    setTopic("");
    setSourceText("");
    reset();
  }

  function handleCreateDeck(payload: Parameters<typeof create.mutate>[0]) {
    create.mutate(payload, {
      onSuccess: (deck) => {
        setDeckId(deck.id);
        setNewDeckModal(false);
      },
    });
  }

  const targetDeck = decks.find((d) => d.id === deckId);

  return (
    <div className="mx-auto max-w-2xl space-y-8">
      {/* Header */}
      <header>
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-500/15">
            <Sparkles className="h-5 w-5 text-violet-500" />
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Gerar com IA</h1>
            <p className="text-sm text-muted-foreground">
              Crie flashcards automaticamente a partir de um tópico ou texto.
            </p>
          </div>
        </div>
      </header>

      {/* Job result states — shown above the form when submitted */}
      {submitted && (
        <JobStatus
          status={status}
          isRunning={isRunning}
          job={job}
          error={error}
          deckId={deckId}
          deckTitle={targetDeck?.title}
          onReset={handleReset}
        />
      )}

      {/* Form — hidden while running or completed */}
      {(!submitted || status === "failed") && (
        <form
          onSubmit={handleSubmit}
          className="space-y-6 rounded-2xl border border-border bg-card p-6"
        >
          {/* Deck selector */}
          <div className="space-y-2">
            <Label htmlFor="ai-deck">Deck de destino</Label>
            {decksQuery.isLoading ? (
              <div className="h-11 animate-pulse rounded-lg bg-secondary" />
            ) : decks.length === 0 ? (
              <div className="flex items-center gap-3 rounded-xl border border-dashed border-border p-4">
                <BookOpen className="h-5 w-5 shrink-0 text-muted-foreground" />
                <div className="flex-1 text-sm text-muted-foreground">
                  Você não tem decks ainda.
                </div>
                <Button
                  type="button"
                  size="sm"
                  onClick={() => setNewDeckModal(true)}
                >
                  <Plus className="h-3.5 w-3.5" /> Criar deck
                </Button>
              </div>
            ) : (
              <div className="flex gap-2">
                <select
                  id="ai-deck"
                  value={deckId}
                  onChange={(e) => setDeckId(e.target.value)}
                  required
                  className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                >
                  <option value="" disabled>
                    Selecione um deck…
                  </option>
                  {decks.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.title} ({d.card_count} cards)
                    </option>
                  ))}
                </select>
                <Button
                  type="button"
                  variant="secondary"
                  size="icon"
                  onClick={() => setNewDeckModal(true)}
                  title="Criar novo deck"
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
            )}
          </div>

          {/* Topic */}
          <div className="space-y-1.5">
            <Label htmlFor="ai-topic">Tópico *</Label>
            <Input
              id="ai-topic"
              placeholder="Ex.: Verbos irregulares em inglês no passado simples"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              maxLength={500}
              required
            />
          </div>

          {/* Count + Language */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="ai-count">Quantidade de cards</Label>
              <Input
                id="ai-count"
                type="number"
                min={1}
                max={20}
                value={count}
                onChange={(e) =>
                  setCount(Math.max(1, Math.min(20, Number(e.target.value) || 1)))
                }
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="ai-lang">Idioma</Label>
              <Input
                id="ai-lang"
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                placeholder="pt-BR"
                maxLength={10}
              />
            </div>
          </div>

          {/* Source text */}
          <div className="space-y-1.5">
            <Label htmlFor="ai-source">
              Texto-fonte{" "}
              <span className="text-muted-foreground">(opcional)</span>
            </Label>
            <Textarea
              id="ai-source"
              rows={5}
              placeholder="Cole um trecho do seu material de estudo. A IA usará esse contexto para criar cards mais precisos."
              value={sourceText}
              onChange={(e) => setSourceText(e.target.value)}
              maxLength={8000}
            />
            <p className="text-xs text-muted-foreground">
              {sourceText.length}/8000 caracteres
            </p>
          </div>

          {/* Error inline */}
          {error && status === "failed" && (
            <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-600">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Submit */}
          <Button
            type="submit"
            className="w-full"
            disabled={!deckId || !topic.trim() || isStarting || decks.length === 0}
          >
            {isStarting ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Sparkles className="h-4 w-4" />
            )}
            {isStarting ? "Enviando…" : "Gerar flashcards"}
          </Button>
        </form>
      )}

      {/* Create deck modal */}
      <CreateDeckModal
        open={newDeckModal}
        onClose={() => setNewDeckModal(false)}
        onSubmit={handleCreateDeck}
        isLoading={create.isPending}
      />
    </div>
  );
}

// ─── Job status panel ────────────────────────────────────────

type JobStatusProps = {
  status: string | null;
  isRunning: boolean;
  job: ReturnType<typeof useGenerateCards>["job"];
  error: string | null;
  deckId: string;
  deckTitle?: string;
  onReset: () => void;
};

function JobStatus({ status, isRunning, job, error, deckId, deckTitle, onReset }: JobStatusProps) {
  if (isRunning) {
    return (
      <div className="flex flex-col items-center gap-4 rounded-2xl border border-border bg-card p-8 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-violet-500/15">
          <Loader2 className="h-7 w-7 animate-spin text-violet-500" />
        </div>
        <div>
          <p className="font-semibold">
            {status === "running" ? "Gerando flashcards…" : "Enfileirando o pedido…"}
          </p>
          <p className="mt-1 text-sm text-muted-foreground">
            Costuma levar entre 5 e 30 segundos. Aguarde.
          </p>
        </div>
      </div>
    );
  }

  if (status === "completed" && job?.result) {
    return (
      <div className="flex flex-col items-center gap-4 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-8 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/20">
          <CheckCircle2 className="h-7 w-7 text-emerald-500" />
        </div>
        <div>
          <p className="text-lg font-bold">
            {job.result.created_count}{" "}
            {job.result.created_count === 1 ? "card criado" : "cards criados"}
          </p>
          {job.result.skipped_count > 0 && (
            <p className="mt-0.5 text-sm text-muted-foreground">
              {job.result.skipped_count} ignorados por limite do deck.
            </p>
          )}
          {deckTitle && (
            <p className="mt-0.5 text-sm text-muted-foreground">
              Adicionados ao deck <strong className="text-foreground">{deckTitle}</strong>.
            </p>
          )}
        </div>
        <div className="flex gap-3">
          <Button variant="secondary" onClick={onReset}>
            Gerar mais
          </Button>
          <Button asChild>
            <Link href={`/decks/${deckId}`}>
              Ver deck <ArrowRight className="h-4 w-4" />
            </Link>
          </Button>
        </div>
      </div>
    );
  }

  if (status === "failed") {
    return (
      <div className="flex flex-col items-center gap-3 rounded-2xl border border-red-500/30 bg-red-500/10 p-6 text-center">
        <AlertCircle className="h-8 w-8 text-red-500" />
        <div>
          <p className="font-semibold">A geração falhou</p>
          {error && (
            <p className="mt-1 max-w-sm text-sm text-muted-foreground break-words">{error}</p>
          )}
        </div>
        <Button variant="secondary" onClick={onReset}>
          Tentar de novo
        </Button>
      </div>
    );
  }

  return null;
}
