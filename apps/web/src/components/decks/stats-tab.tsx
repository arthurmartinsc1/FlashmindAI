"use client";

import { Layers, CalendarClock, BarChart3 } from "lucide-react";
import type { Card, Deck } from "@/types/api";

interface StatsTabProps {
  deck: Deck;
  cards: Card[];
  isLoading: boolean;
}

export function StatsTab({ deck, cards, isLoading }: StatsTabProps) {
  const newCards = cards.filter((c) => c.repetitions === 0).length;
  const learning = cards.filter((c) => c.repetitions > 0 && c.interval < 21).length;
  const mature = cards.filter((c) => c.interval >= 21).length;
  const total = cards.length || 1;

  const dist = [
    { label: "Novos", value: newCards, color: "bg-primary" },
    { label: "Aprendendo", value: learning, color: "bg-amber-500" },
    { label: "Maduros", value: mature, color: "bg-emerald-500" },
  ];

  const avgEase =
    cards.length > 0
      ? (cards.reduce((s, c) => s + c.ease_factor, 0) / cards.length).toFixed(2)
      : "—";

  if (isLoading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-24 animate-pulse rounded-xl bg-secondary" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Counters */}
      <div className="grid gap-3 sm:grid-cols-3">
        <StatBox icon={Layers} label="Total de cards" value={deck.card_count} />
        <StatBox icon={CalendarClock} label="Para revisar hoje" value={deck.due_count} accent />
        <StatBox icon={BarChart3} label="Ease médio" value={avgEase} />
      </div>

      {/* Distribution */}
      <div className="rounded-xl border border-border bg-card p-5">
        <p className="mb-4 text-sm font-semibold">Distribuição de maturidade</p>
        <div className="flex h-3 overflow-hidden rounded-full bg-secondary">
          {dist.map((d) => (
            <div
              key={d.label}
              className={d.color}
              style={{ width: `${(d.value / total) * 100}%` }}
            />
          ))}
        </div>
        <ul className="mt-4 space-y-2.5">
          {dist.map((d) => (
            <li key={d.label} className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2">
                <span className={`h-2.5 w-2.5 rounded-full ${d.color}`} />
                <span className="text-muted-foreground">{d.label}</span>
              </div>
              <span className="font-semibold">{d.value}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function StatBox({
  icon: Icon,
  label,
  value,
  accent,
}: {
  icon: React.FC<{ className?: string }>;
  label: string;
  value: string | number;
  accent?: boolean;
}) {
  return (
    <div className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4">
      <Icon className={`h-4 w-4 ${accent ? "text-primary" : "text-muted-foreground"}`} />
      <span className={`text-2xl font-bold ${accent ? "text-primary" : ""}`}>{value}</span>
      <span className="text-xs text-muted-foreground">{label}</span>
    </div>
  );
}
