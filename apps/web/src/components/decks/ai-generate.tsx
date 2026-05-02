"use client";

import { useState } from "react";
import { Sparkles, Loader2, CheckCircle2, AlertCircle } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Dialog, DialogClose, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useGenerateCards } from "@/hooks/use-generate-cards";

interface AIGenerateProps {
  deckId: string;
}

export function AIGenerate({ deckId }: AIGenerateProps) {
  const [open, setOpen] = useState(false);
  const [topic, setTopic] = useState("");
  const [count, setCount] = useState(8);
  const [language, setLanguage] = useState("pt-BR");
  const [sourceText, setSourceText] = useState("");

  const { start, status, isRunning, job, error, reset, isStarting } =
    useGenerateCards(deckId);

  function close() {
    if (isRunning) return;
    setOpen(false);
    setTimeout(() => {
      setTopic("");
      setSourceText("");
      reset();
    }, 200);
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!topic.trim() || isRunning) return;
    start({
      topic: topic.trim(),
      count,
      language,
      source_text: sourceText.trim() || undefined,
    });
  }

  return (
    <>
      <Button
        type="button"
        variant="secondary"
        onClick={() => setOpen(true)}
        className="bg-violet-500/10 text-violet-600 hover:bg-violet-500/15 dark:text-violet-300"
      >
        <Sparkles className="h-3.5 w-3.5" />
        Gerar com IA
      </Button>

      <Dialog open={open} onClose={close} className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Gerar flashcards com IA</DialogTitle>
          <DialogClose onClose={close} />
        </DialogHeader>

        {status === "completed" && job?.result ? (
          <CompletedState
            created={job.result.created_count}
            skipped={job.result.skipped_count}
            onClose={close}
          />
        ) : status === "failed" ? (
          <FailedState error={error || "Falha desconhecida."} onRetry={reset} />
        ) : isRunning ? (
          <RunningState status={status} />
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="ai-topic">Tópico</Label>
              <Input
                id="ai-topic"
                placeholder="Ex.: Verbos irregulares em inglês — passado simples"
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                maxLength={500}
                required
                autoFocus
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="ai-count">Quantidade</Label>
                <Input
                  id="ai-count"
                  type="number"
                  min={1}
                  max={20}
                  value={count}
                  onChange={(e) => setCount(Math.max(1, Math.min(20, Number(e.target.value) || 1)))}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ai-lang">Idioma</Label>
                <Input
                  id="ai-lang"
                  value={language}
                  onChange={(e) => setLanguage(e.target.value)}
                  maxLength={10}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="ai-source">
                Texto-fonte <span className="text-muted-foreground">(opcional)</span>
              </Label>
              <Textarea
                id="ai-source"
                rows={4}
                placeholder="Cole aqui um trecho do material — ajuda a IA a aderir ao seu conteúdo."
                value={sourceText}
                onChange={(e) => setSourceText(e.target.value)}
                maxLength={8000}
              />
            </div>

            {error && (
              <p className="flex items-center gap-1.5 text-sm text-red-500">
                <AlertCircle className="h-3.5 w-3.5" /> {error}
              </p>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="secondary" onClick={close}>
                Cancelar
              </Button>
              <Button type="submit" disabled={!topic.trim() || isStarting}>
                {isStarting ? (
                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                ) : (
                  <Sparkles className="h-3.5 w-3.5" />
                )}
                Gerar
              </Button>
            </div>
          </form>
        )}
      </Dialog>
    </>
  );
}

function RunningState({ status }: { status: string | null }) {
  const label =
    status === "running" ? "Gerando flashcards…" : "Enfileirando o pedido…";
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-8 text-center">
      <Loader2 className="h-8 w-8 animate-spin text-violet-500" />
      <p className="text-sm font-medium">{label}</p>
      <p className="text-xs text-muted-foreground">
        Isso costuma levar de 5 a 30 segundos. Você pode fechar — os cards
        aparecem aqui assim que estiverem prontos.
      </p>
    </div>
  );
}

function CompletedState({
  created,
  skipped,
  onClose,
}: {
  created: number;
  skipped: number;
  onClose: () => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-6 text-center">
      <CheckCircle2 className="h-9 w-9 text-emerald-500" />
      <p className="text-base font-semibold">
        {created} {created === 1 ? "card criado" : "cards criados"}
      </p>
      {skipped > 0 && (
        <p className="text-xs text-muted-foreground">
          {skipped} {skipped === 1 ? "card foi descartado" : "cards foram descartados"} por
          atingir o limite do deck.
        </p>
      )}
      <div className="rounded-lg border border-amber-500/20 bg-amber-500/5 px-4 py-2.5 text-xs text-muted-foreground">
        📖 Faça a <span className="font-medium text-foreground">Micro-lição</span> para liberar
        os cards para revisão hoje. Caso contrário, eles aparecem automaticamente{" "}
        <span className="font-medium text-foreground">amanhã</span>.
      </div>
      <Button onClick={onClose} className="mt-1">
        Ver micro-lição
      </Button>
    </div>
  );
}

function FailedState({ error, onRetry }: { error: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center gap-3 py-6 text-center">
      <AlertCircle className="h-9 w-9 text-red-500" />
      <p className="text-sm font-semibold">A geração falhou.</p>
      <p className="max-w-sm text-xs text-muted-foreground break-words">{error}</p>
      <Button variant="secondary" onClick={onRetry} className="mt-2">
        Tentar de novo
      </Button>
    </div>
  );
}
