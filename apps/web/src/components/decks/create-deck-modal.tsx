"use client";

import { useState } from "react";
import { Dialog, DialogHeader, DialogTitle, DialogClose } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import type { DeckIn } from "@/types/api";

const PRESET_COLORS = [
  "#6366F1", "#8B5CF6", "#EC4899", "#F43F5E",
  "#F97316", "#EAB308", "#22C55E", "#14B8A6",
  "#3B82F6", "#06B6D4", "#64748B", "#A78BFA",
];

interface CreateDeckModalProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (payload: DeckIn) => void;
  isLoading?: boolean;
}

export function CreateDeckModal({ open, onClose, onSubmit, isLoading }: CreateDeckModalProps) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [color, setColor] = useState("#6366F1");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    onSubmit({ title: title.trim(), description: description.trim(), color });
    setTitle("");
    setDescription("");
    setColor("#6366F1");
  }

  return (
    <Dialog open={open} onClose={onClose}>
      <DialogHeader>
        <DialogTitle>Novo deck</DialogTitle>
        <DialogClose onClose={onClose} />
      </DialogHeader>
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="space-y-1.5">
          <Label htmlFor="deck-title">Título *</Label>
          <Input
            id="deck-title"
            placeholder="Ex: Inglês B2, Anatomia…"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={100}
            required
            autoFocus
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="deck-desc">Descrição</Label>
          <Textarea
            id="deck-desc"
            placeholder="Opcional"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            maxLength={500}
            rows={3}
          />
        </div>

        <div className="space-y-2">
          <Label>Cor</Label>
          <div className="flex flex-wrap gap-2">
            {PRESET_COLORS.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setColor(c)}
                className="h-7 w-7 rounded-full transition-transform hover:scale-110 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
                style={{
                  backgroundColor: c,
                  outline: c === color ? `3px solid ${c}` : undefined,
                  outlineOffset: c === color ? "2px" : undefined,
                }}
                aria-label={c}
              />
            ))}
          </div>
        </div>

        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="secondary" onClick={onClose} disabled={isLoading}>
            Cancelar
          </Button>
          <Button type="submit" disabled={!title.trim() || isLoading}>
            {isLoading ? "Criando…" : "Criar deck"}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
