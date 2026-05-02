"use client";

import { useState } from "react";
import { Plus } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

interface AddCardFormProps {
  onAdd: (front: string, back: string, tags: string[]) => void;
  isLoading?: boolean;
}

export function AddCardForm({ onAdd, isLoading }: AddCardFormProps) {
  const [open, setOpen] = useState(false);
  const [front, setFront] = useState("");
  const [back, setBack] = useState("");
  const [tagsRaw, setTagsRaw] = useState("");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!front.trim() || !back.trim()) return;
    const tags = tagsRaw
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
    onAdd(front.trim(), back.trim(), tags);
    setFront("");
    setBack("");
    setTagsRaw("");
    setOpen(false);
  }

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-border py-4 text-sm font-medium text-muted-foreground transition-colors hover:border-primary/50 hover:text-primary"
      >
        <Plus className="h-4 w-4" />
        Adicionar card manualmente
      </button>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="rounded-xl border border-border bg-card p-5"
    >
      <p className="mb-4 text-sm font-semibold">Novo card</p>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label htmlFor="card-front">Frente *</Label>
          <Textarea
            id="card-front"
            placeholder="Pergunta ou conceito"
            value={front}
            onChange={(e) => setFront(e.target.value)}
            rows={3}
            autoFocus
            required
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="card-back">Verso *</Label>
          <Textarea
            id="card-back"
            placeholder="Resposta ou definição"
            value={back}
            onChange={(e) => setBack(e.target.value)}
            rows={3}
            required
          />
        </div>
      </div>
      <div className="mt-3 space-y-1.5">
        <Label htmlFor="card-tags">Tags (separadas por vírgula)</Label>
        <Input
          id="card-tags"
          placeholder="Ex: verbo, irregular, presente"
          value={tagsRaw}
          onChange={(e) => setTagsRaw(e.target.value)}
        />
      </div>
      <div className="mt-4 flex justify-end gap-2">
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => setOpen(false)}
          disabled={isLoading}
        >
          Cancelar
        </Button>
        <Button type="submit" size="sm" disabled={!front.trim() || !back.trim() || isLoading}>
          {isLoading ? "Salvando…" : "Salvar card"}
        </Button>
      </div>
    </form>
  );
}
