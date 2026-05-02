"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, GraduationCap, Pencil, Trash2, Check, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { CardList } from "@/components/decks/card-list";
import { MicrolearningTab } from "@/components/microlearning/microlearning-tab";
import { StatsTab } from "@/components/decks/stats-tab";
import { useDeck, useDeckUpdate, useCards, useCardMutations, useLessons } from "@/hooks/use-deck";
import { useDecks } from "@/hooks/use-decks";

export default function DeckDetailPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const router = useRouter();

  const deckQuery = useDeck(id);
  const deckUpdate = useDeckUpdate(id);
  const { remove: removeDeck } = useDecks();
  const cardsQuery = useCards(id);
  const { add, edit, remove: removeCard } = useCardMutations(id);
  const lessonsQuery = useLessons(id);

  const [editingTitle, setEditingTitle] = useState(false);
  const [titleDraft, setTitleDraft] = useState("");

  const deck = deckQuery.data;
  const cards = cardsQuery.data?.cards ?? [];

  function startEditTitle() {
    setTitleDraft(deck?.title ?? "");
    setEditingTitle(true);
  }

  function saveTitle() {
    if (titleDraft.trim() && titleDraft !== deck?.title) {
      deckUpdate.mutate({ title: titleDraft.trim() });
    }
    setEditingTitle(false);
  }

  function handleDelete() {
    if (!deck) return;
    if (!window.confirm(`Arquivar o deck "${deck.title}"?`)) return;
    removeDeck.mutate(id, { onSuccess: () => router.push("/decks") });
  }

  if (deckQuery.isLoading) {
    return (
      <div className="mx-auto max-w-4xl space-y-6">
        <div className="h-8 w-48 animate-pulse rounded-lg bg-secondary" />
        <div className="h-32 animate-pulse rounded-2xl bg-secondary" />
      </div>
    );
  }

  if (!deck) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-3">
        <p className="text-muted-foreground">Deck não encontrado.</p>
        <Button variant="secondary" asChild>
          <Link href="/decks">Voltar</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      {/* Back */}
      <Link
        href="/decks"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Meus decks
      </Link>

      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex min-w-0 flex-1 items-start gap-3">
          <span
            className="mt-1 h-4 w-4 shrink-0 rounded-full"
            style={{ backgroundColor: deck.color }}
          />
          <div className="min-w-0">
            {editingTitle ? (
              <div className="flex items-center gap-2">
                <Input
                  value={titleDraft}
                  onChange={(e) => setTitleDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") saveTitle();
                    if (e.key === "Escape") setEditingTitle(false);
                  }}
                  className="h-8 text-xl font-bold"
                  autoFocus
                />
                <button onClick={saveTitle} className="text-emerald-500 hover:text-emerald-400">
                  <Check className="h-4 w-4" />
                </button>
                <button onClick={() => setEditingTitle(false)} className="text-muted-foreground hover:text-foreground">
                  <X className="h-4 w-4" />
                </button>
              </div>
            ) : (
              <h1 className="truncate text-xl font-bold">{deck.title}</h1>
            )}
            {deck.description && (
              <p className="mt-0.5 text-sm text-muted-foreground">{deck.description}</p>
            )}
            <div className="mt-1.5 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
              <span><strong className="text-foreground">{deck.card_count}</strong> cards</span>
              {deck.due_count > 0 ? (
                <span className="rounded-full bg-primary/10 px-2 py-0.5 text-primary">
                  {deck.due_count} para revisar
                </span>
              ) : deck.lesson_locked_cards_count > 0 ? (
                <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-amber-600 dark:text-amber-400">
                  Disponível após micro-lição
                </span>
              ) : null}
            </div>
          </div>
        </div>

        <div className="flex shrink-0 gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={startEditTitle}
            disabled={editingTitle}
          >
            <Pencil className="h-3.5 w-3.5" />
            Editar
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="text-red-500 hover:bg-red-500/10 hover:text-red-500"
            onClick={handleDelete}
            disabled={removeDeck.isPending}
          >
            <Trash2 className="h-3.5 w-3.5" />
            Arquivar
          </Button>
          <Button asChild size="sm">
            <Link href={`/review?deck_id=${deck.id}`}>
              <GraduationCap className="h-3.5 w-3.5" />
              Revisar
            </Link>
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <Tabs defaultValue="cards">
        <TabsList className="w-full sm:w-auto">
          <TabsTrigger value="cards">Cards</TabsTrigger>
          <TabsTrigger value="lessons">Micro-lição</TabsTrigger>
          <TabsTrigger value="stats">Estatísticas</TabsTrigger>
        </TabsList>

        <div className="mt-5">
          <TabsContent value="cards">
            <CardList
              cards={cards}
              deckId={id}
              isLoading={cardsQuery.isLoading}
              onAdd={(front, back, tags) => add.mutate({ front, back, tags })}
              onEdit={(cardId, front, back) => edit.mutate({ id: cardId, front, back })}
              onDelete={(cardId) => removeCard.mutate(cardId)}
addLoading={add.isPending}
            />
          </TabsContent>

          <TabsContent value="lessons">
            <MicrolearningTab
              deckId={id}
              lessons={lessonsQuery.data?.lessons ?? []}
              isLoading={lessonsQuery.isLoading}
            />
          </TabsContent>

          <TabsContent value="stats">
            <StatsTab
              deck={deck}
              cards={cards}
              isLoading={cardsQuery.isLoading}
            />
          </TabsContent>
        </div>
      </Tabs>
    </div>
  );
}
