"use client";

import { useState } from "react";
import Link from "next/link";
import { Plus, ArrowUpRight, GraduationCap } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CreateDeckModal } from "@/components/decks/create-deck-modal";
import { useDecks } from "@/hooks/use-decks";
import type { Deck } from "@/types/api";

export default function DecksPage() {
  const { query, create } = useDecks();
  const [modalOpen, setModalOpen] = useState(false);

  const decks = query.data?.decks ?? [];

  function handleCreate(payload: Parameters<typeof create.mutate>[0]) {
    create.mutate(payload, { onSuccess: () => setModalOpen(false) });
  }

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Meus decks</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            {query.isLoading ? "Carregando…" : `${query.data?.count ?? 0} decks`}
          </p>
        </div>
        <Button onClick={() => setModalOpen(true)}>
          <Plus className="h-4 w-4" />
          Novo deck
        </Button>
      </div>

      {query.isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-40 animate-pulse rounded-2xl bg-secondary" />
          ))}
        </div>
      ) : decks.length === 0 ? (
        <EmptyState onNew={() => setModalOpen(true)} />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {decks.map((deck) => (
            <DeckCard key={deck.id} deck={deck} />
          ))}
        </div>
      )}

      <CreateDeckModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        onSubmit={handleCreate}
        isLoading={create.isPending}
      />
    </div>
  );
}

function DeckCard({ deck }: { deck: Deck }) {
  return (
    <Link
      href={`/decks/${deck.id}`}
      className="group relative overflow-hidden rounded-2xl border border-border bg-card p-5 transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lg"
    >
      <div className="relative">
        <div className="mb-3 flex items-center gap-2">
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ backgroundColor: deck.color }}
          />
          <ArrowUpRight className="ml-auto h-4 w-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
        </div>

        <h3 className="truncate text-base font-semibold">{deck.title}</h3>
        {deck.description && (
          <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{deck.description}</p>
        )}

        <div className="mt-4 flex items-center gap-4 text-xs text-muted-foreground">
          <span>
            <strong className="text-foreground">{deck.card_count}</strong> cards
          </span>
          {deck.due_count > 0 && (
            <span className="flex items-center gap-1 rounded-full bg-primary/10 px-2 py-0.5 text-primary">
              <GraduationCap className="h-3 w-3" />
              {deck.due_count} para revisar
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}

function EmptyState({ onNew }: { onNew: () => void }) {
  return (
    <div className="rounded-2xl border border-dashed border-border p-10 text-center">
      <p className="text-base font-semibold">Nenhum deck ainda</p>
      <p className="mt-1 text-sm text-muted-foreground">Crie seu primeiro deck agora.</p>
      <Button className="mt-4" onClick={onNew}>
        <Plus className="h-4 w-4" /> Criar deck
      </Button>
    </div>
  );
}
