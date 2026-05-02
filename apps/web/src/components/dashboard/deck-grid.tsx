"use client";

import Link from "next/link";
import { ArrowUpRight, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { Deck } from "@/types/api";

export function DeckGrid({ decks }: { decks: Deck[] }) {
  return (
    <section>
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h3 className="text-base font-semibold">Seus decks</h3>
          <p className="text-xs text-muted-foreground">Continue de onde parou</p>
        </div>
        <Button size="sm" asChild>
          <Link href="/decks">
            <Plus className="h-4 w-4" /> Novo deck
          </Link>
        </Button>
      </div>

      {decks.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {decks.map((deck) => (
            <DeckCard key={deck.id} deck={deck} />
          ))}
        </div>
      )}
    </section>
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
            aria-hidden
          />
<ArrowUpRight className="ml-auto h-4 w-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
        </div>

        <h4 className="truncate text-base font-semibold">{deck.title}</h4>
        {deck.description && (
          <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">
            {deck.description}
          </p>
        )}

        <div className="mt-4 flex items-center gap-4 text-xs text-muted-foreground">
          <span>
            <strong className="text-foreground">{deck.card_count}</strong> cards
          </span>
          {deck.due_count > 0 && (
            <span className="rounded-full bg-primary/10 px-2 py-0.5 text-primary">
              {deck.due_count} para revisar
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}

function EmptyState() {
  return (
    <div className="rounded-2xl border border-dashed border-border p-10 text-center">
      <h4 className="text-base font-semibold">Nenhum deck ainda</h4>
      <p className="mt-1 text-sm text-muted-foreground">
        Crie seu primeiro deck ou gere um com IA em segundos.
      </p>
      <div className="mt-4 flex justify-center gap-2">
        <Button asChild>
          <Link href="/decks/new">
            <Plus className="h-4 w-4" /> Criar deck
          </Link>
        </Button>
        <Button variant="outline" asChild>
          <Link href="/ai">Gerar com IA</Link>
        </Button>
      </div>
    </div>
  );
}
