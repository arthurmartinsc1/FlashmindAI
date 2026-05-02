"use client";

import { useState } from "react";
import { Pencil, Trash2, Check, X, Tag } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { AddCardForm } from "./add-card-form";
import { AIGenerate } from "./ai-generate";
import type { Card } from "@/types/api";

interface CardListProps {
  cards: Card[];
  deckId: string;
  isLoading: boolean;
  onAdd: (front: string, back: string, tags: string[]) => void;
  onEdit: (id: string, front: string, back: string) => void;
  onDelete: (id: string) => void;
  addLoading?: boolean;
}

export function CardList({
  cards,
  deckId,
  isLoading,
  onAdd,
  onEdit,
  onDelete,
  addLoading,
}: CardListProps) {
  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-20 animate-pulse rounded-xl bg-secondary" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-5">
      <AddCardForm onAdd={onAdd} isLoading={addLoading} />

      <div className="flex flex-wrap items-center gap-3">
        <AIGenerate deckId={deckId} />
        <span className="text-xs text-muted-foreground">
          Cria flashcards automaticamente a partir de um tópico ou texto.
        </span>
      </div>

      {cards.length === 0 ? (
        <p className="py-8 text-center text-sm text-muted-foreground">
          Nenhum card ainda. Adicione um acima ou gere com IA.
        </p>
      ) : (
        <ul className="space-y-2.5">
          {cards.map((card) => (
            <CardRow key={card.id} card={card} onEdit={onEdit} onDelete={onDelete} />
          ))}
        </ul>
      )}
    </div>
  );
}

function CardRow({
  card,
  onEdit,
  onDelete,
}: {
  card: Card;
  onEdit: (id: string, front: string, back: string) => void;
  onDelete: (id: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [front, setFront] = useState(card.front);
  const [back, setBack] = useState(card.back);

  function save() {
    if (front.trim() && back.trim()) {
      onEdit(card.id, front.trim(), back.trim());
    }
    setEditing(false);
  }

  function cancel() {
    setFront(card.front);
    setBack(card.back);
    setEditing(false);
  }

  if (editing) {
    return (
      <li className="rounded-xl border border-primary/40 bg-card p-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <Textarea value={front} onChange={(e) => setFront(e.target.value)} rows={2} autoFocus />
          <Textarea value={back} onChange={(e) => setBack(e.target.value)} rows={2} />
        </div>
        <div className="mt-3 flex justify-end gap-2">
          <Button size="sm" variant="secondary" onClick={cancel}>
            <X className="h-3.5 w-3.5" /> Cancelar
          </Button>
          <Button size="sm" onClick={save}>
            <Check className="h-3.5 w-3.5" /> Salvar
          </Button>
        </div>
      </li>
    );
  }

  return (
    <li className="group flex items-start gap-4 rounded-xl border border-border bg-card p-4 transition-colors hover:border-border/80">
      <div className="min-w-0 flex-1 grid gap-2 sm:grid-cols-2">
        <p className="text-sm font-medium leading-snug">{card.front}</p>
        <p className="text-sm text-muted-foreground leading-snug">{card.back}</p>
      </div>

      {card.tags.length > 0 && (
        <div className="hidden items-center gap-1 sm:flex">
          <Tag className="h-3 w-3 text-muted-foreground" />
          {card.tags.slice(0, 3).map((t) => (
            <span key={t} className="rounded-full bg-secondary px-2 py-0.5 text-[10px] text-muted-foreground">
              {t}
            </span>
          ))}
        </div>
      )}

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={() => setEditing(true)}
          className="rounded-lg p-1.5 text-muted-foreground hover:bg-secondary hover:text-foreground"
          aria-label="Editar"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={() => onDelete(card.id)}
          className="rounded-lg p-1.5 text-muted-foreground hover:bg-red-500/10 hover:text-red-500"
          aria-label="Excluir"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </li>
  );
}
