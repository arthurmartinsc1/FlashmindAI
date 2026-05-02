"use client";

import { motion } from "framer-motion";
import { CheckCircle2, XCircle, Clock, RotateCcw, BookOpen } from "lucide-react";
import Link from "next/link";
import type { SessionResult } from "@/hooks/use-study";

interface StudySummaryProps {
  results: SessionResult[];
  onRestart: () => void;
}

export function StudySummary({ results, onRestart }: StudySummaryProps) {
  const total = results.length;
  const correct = results.filter((r) => r.quality >= 3).length;
  const incorrect = total - correct;
  const totalMs = results.reduce((acc, r) => acc + r.timeMs, 0);
  const avgSec = total > 0 ? Math.round(totalMs / total / 1000) : 0;
  const pct = total > 0 ? Math.round((correct / total) * 100) : 0;

  const ratingCounts = Array.from({ length: 6 }, (_, i) => ({
    value: i,
    count: results.filter((r) => r.quality === i).length,
  }));
  const maxCount = Math.max(...ratingCounts.map((r) => r.count), 1);

  const COLORS = [
    "bg-red-500",
    "bg-red-400",
    "bg-orange-400",
    "bg-amber-400",
    "bg-emerald-500",
    "bg-emerald-600",
  ];

  const message =
    pct >= 90
      ? "Excelente domínio. Continue assim."
      : pct >= 70
      ? "Bom resultado. A repetição vai consolidar."
      : "Cada revisão fortalece sua memória.";

  return (
    <motion.div
      className="mx-auto flex max-w-lg flex-col gap-5"
      initial={{ opacity: 0, scale: 0.96 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3 }}
    >
      {/* Header */}
      <div className="text-center">
        <div className="mx-auto mb-3 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
          <CheckCircle2 className="h-8 w-8 text-primary" />
        </div>
        <h2 className="text-2xl font-bold">Sessão concluída</h2>
        <p className="mt-1 text-sm text-muted-foreground">{message}</p>
      </div>

      {/* Métricas */}
      <div className="grid grid-cols-3 gap-3">
        <div className="flex flex-col items-center gap-1 rounded-xl border border-border bg-card p-4">
          <CheckCircle2 className="h-4 w-4 text-emerald-500" />
          <span className="text-2xl font-bold">{correct}</span>
          <span className="text-xs text-muted-foreground">Acertos</span>
        </div>
        <div className="flex flex-col items-center gap-1 rounded-xl border border-border bg-card p-4">
          <XCircle className="h-4 w-4 text-red-400" />
          <span className="text-2xl font-bold">{incorrect}</span>
          <span className="text-xs text-muted-foreground">Erros</span>
        </div>
        <div className="flex flex-col items-center gap-1 rounded-xl border border-border bg-card p-4">
          <Clock className="h-4 w-4 text-muted-foreground" />
          <span className="text-2xl font-bold">{avgSec}s</span>
          <span className="text-xs text-muted-foreground">Média/card</span>
        </div>
      </div>

      {/* Taxa de acerto */}
      <div className="rounded-xl border border-border bg-card p-5">
        <div className="mb-2 flex items-center justify-between text-sm">
          <span className="font-medium">Taxa de acerto</span>
          <span className="font-bold text-primary">{pct}%</span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-secondary">
          <motion.div
            className="h-full rounded-full bg-primary"
            initial={{ width: 0 }}
            animate={{ width: `${pct}%` }}
            transition={{ duration: 0.6, ease: "easeOut", delay: 0.2 }}
          />
        </div>
      </div>

      {/* Distribuição */}
      <div className="rounded-xl border border-border bg-card p-5">
        <p className="mb-4 text-sm font-medium text-muted-foreground">Distribuição de notas</p>
        <div className="flex items-end justify-between gap-1.5">
          {ratingCounts.map(({ value, count }) => (
            <div key={value} className="flex flex-1 flex-col items-center gap-1">
              {count > 0 && (
                <span className="text-xs font-semibold text-muted-foreground">{count}</span>
              )}
              <motion.div
                className={`w-full rounded-t ${COLORS[value]}`}
                style={{ minHeight: 4 }}
                initial={{ height: 0 }}
                animate={{ height: `${(count / maxCount) * 72}px` }}
                transition={{ duration: 0.45, ease: "easeOut", delay: value * 0.05 }}
              />
              <span className="text-xs font-bold text-muted-foreground">{value}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Ações */}
      <div className="flex gap-3">
        <button
          onClick={onRestart}
          className="flex flex-1 items-center justify-center gap-2 rounded-xl border border-border bg-card px-4 py-3 text-sm font-medium transition-colors hover:bg-secondary"
        >
          <RotateCcw className="h-4 w-4" />
          Nova sessão
        </button>
        <Link
          href="/review"
          className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <BookOpen className="h-4 w-4" />
          Outros decks
        </Link>
      </div>
    </motion.div>
  );
}
