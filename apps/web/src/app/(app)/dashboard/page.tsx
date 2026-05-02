"use client";

import Link from "next/link";
import { Flame, Target, TrendingUp, GraduationCap, BookOpen } from "lucide-react";

import { Button } from "@/components/ui/button";
import { ActivityChart } from "@/components/dashboard/activity-chart";
import { DeckGrid } from "@/components/dashboard/deck-grid";
import { StatCard } from "@/components/dashboard/stat-card";
import { useDashboard, useDecks } from "@/hooks/use-dashboard";
import { useAuthStore } from "@/stores/auth-store";

export default function DashboardPage() {
  const user = useAuthStore((s) => s.user);
  const dashboard = useDashboard();
  const decks = useDecks();

  const firstName = user?.name.split(" ")[0] ?? "";

  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-8">
      <header>
        <h1 className="text-3xl font-bold tracking-tight">
          {firstName ? `Olá, ${firstName}` : "Dashboard"}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Continue construindo consistência.
        </p>
      </header>

      {/* Review CTA — always visible, state changes based on due count */}
      {!dashboard.isLoading && (
        <ReviewBanner
          due={dashboard.data?.due_today ?? 0}
          reviewedToday={dashboard.data?.reviewed_today ?? 0}
        />
      )}

      {/* 4 stats principais (PRD F5) */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Para revisar hoje"
          value={dashboard.isLoading ? "—" : dashboard.data?.due_today ?? 0}
          icon={Target}
          tone="primary"
          hint={dashboard.data ? `${dashboard.data.reviewed_today} feitas hoje` : undefined}
        />
        <StatCard
          label="Streak atual"
          value={
            dashboard.isLoading
              ? "—"
              : `${dashboard.data?.current_streak ?? 0} dias`
          }
          icon={Flame}
          tone="primary"
          hint={
            dashboard.data
              ? `recorde: ${dashboard.data.longest_streak} dias`
              : undefined
          }
        />
        <StatCard
          label="Taxa de retenção"
          value={
            dashboard.isLoading
              ? "—"
              : `${Math.round(dashboard.data?.retention_rate ?? 0)}%`
          }
          icon={TrendingUp}
          tone="primary"
          hint="últimos 30 dias"
        />
        <StatCard
          label="Revisões no mês"
          value={dashboard.isLoading ? "—" : dashboard.data?.reviewed_month ?? 0}
          icon={GraduationCap}
          tone="primary"
          hint={
            dashboard.data
              ? `${dashboard.data.reviewed_week} na última semana`
              : undefined
          }
        />
      </div>

      {/* Chart + distribuição */}
      <div className="grid gap-4 lg:grid-cols-[2fr_1fr]">
        {dashboard.data && <ActivityChart data={dashboard.data.activity_last_30_days} />}
        {dashboard.data && <DistributionCard data={dashboard.data.card_distribution} />}
      </div>

      {/* Decks */}
      {decks.data && <DeckGrid decks={decks.data.decks} />}
    </div>
  );
}

function ReviewBanner({ due, reviewedToday }: { due: number; reviewedToday: number }) {
  if (due > 0) {
    return (
      <div className="flex items-center justify-between gap-4 rounded-2xl border border-primary/20 bg-primary/5 px-5 py-4">
        <div>
          <p className="font-semibold">
            {due} card{due !== 1 ? "s" : ""} para revisar hoje
          </p>
          <p className="text-sm text-muted-foreground">Mantenha sua sequência em dia.</p>
        </div>
        <Button asChild>
          <Link href="/review">
            <GraduationCap className="h-4 w-4" />
            Revisar agora
          </Link>
        </Button>
      </div>
    );
  }

  if (reviewedToday > 0) {
    return (
      <div className="flex items-center justify-between gap-4 rounded-2xl border border-emerald-500/20 bg-emerald-500/5 px-5 py-4">
        <div>
          <p className="font-semibold text-emerald-700 dark:text-emerald-400">
            Em dia! Você revisou {reviewedToday} card{reviewedToday !== 1 ? "s" : ""} hoje.
          </p>
          <p className="text-sm text-muted-foreground">
            Os próximos cards serão agendados para os próximos dias.
          </p>
        </div>
        <Button variant="secondary" asChild>
          <Link href="/decks">
            <BookOpen className="h-4 w-4" />
            Meus decks
          </Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border bg-card px-5 py-4">
      <div>
        <p className="font-semibold">Nenhum card vence hoje</p>
        <p className="text-sm text-muted-foreground">
          Adicione cards a um deck ou aguarde os próximos agendamentos.
        </p>
      </div>
      <Button variant="secondary" asChild>
        <Link href="/decks">
          <BookOpen className="h-4 w-4" />
          Meus decks
        </Link>
      </Button>
    </div>
  );
}

function DistributionCard({
  data,
}: {
  data: { new: number; learning: number; mature: number };
}) {
  const total = data.new + data.learning + data.mature || 1;
  const rows = [
    { label: "Novos", value: data.new, color: "bg-primary" },
    { label: "Aprendendo", value: data.learning, color: "bg-amber-500" },
    { label: "Maduros", value: data.mature, color: "bg-emerald-500" },
  ];

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <h3 className="text-base font-semibold">Seus cards</h3>
      <p className="text-xs text-muted-foreground">Distribuição por maturidade</p>

      <div className="mt-5 flex h-2.5 overflow-hidden rounded-full bg-secondary">
        {rows.map((r) => (
          <div
            key={r.label}
            className={r.color}
            style={{ width: `${(r.value / total) * 100}%` }}
          />
        ))}
      </div>

      <ul className="mt-5 space-y-3">
        {rows.map((r) => (
          <li key={r.label} className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-2.5">
              <span className={`h-2.5 w-2.5 rounded-full ${r.color}`} />
              <span>{r.label}</span>
            </div>
            <span className="font-semibold">{r.value}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
