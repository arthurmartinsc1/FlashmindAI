import Link from "next/link";
import { ArrowRight, Sparkles, PlayCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-0 bg-radial-fade" />

      <div className="container relative grid gap-12 py-20 lg:grid-cols-[1.1fr_1fr] lg:gap-16 lg:py-28">
        {/* Copy */}
        <div className="flex flex-col items-start gap-6 animate-fade-up">
          <Badge variant="default" className="gap-1.5">
            <Sparkles className="h-3.5 w-3.5" />
            Potencializado por IA (Llama 3.3)
          </Badge>

          <h1 className="text-balance text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
            Aprenda qualquer coisa em{" "}
            <span className="text-primary">5 minutos por dia</span>
          </h1>

          <p className="max-w-xl text-pretty text-lg text-muted-foreground">
            Flashcards inteligentes que sabem exatamente o que você está prestes a
            esquecer. Repetição espaçada (SM-2) + microlearning + geração automática
            com IA, no navegador e no celular.
          </p>

          <div className="flex flex-col gap-3 sm:flex-row">
            <Button size="lg" asChild>
              <Link href="/register">
                Começar grátis
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
            <Button variant="outline" size="lg" asChild>
              <a href="#how">
                <PlayCircle className="h-4 w-4" />
                Ver como funciona
              </a>
            </Button>
          </div>

          <div className="flex items-center gap-5 pt-2 text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              Sem cartão de crédito
            </div>
            <div className="hidden items-center gap-2 sm:flex">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              Funciona offline(mobile)
            </div>
          </div>
        </div>

        {/* Card stack ilustrativo */}
        <HeroVisual />
      </div>
    </section>
  );
}

function HeroVisual() {
  return (
    <div className="relative mx-auto h-[420px] w-full max-w-md lg:max-w-none">
      {/* Card 1 (fundo) */}
      <div className="absolute left-6 top-10 h-56 w-72 rotate-[-8deg] animate-float-slow rounded-2xl border border-border bg-card p-5 shadow-xl backdrop-blur sm:left-8">
        <div className="mb-3 flex items-center justify-between text-xs text-muted-foreground">
          <span className="rounded-full bg-violet-500/10 px-2 py-0.5 font-medium text-violet-600 dark:text-violet-400">
            Biologia
          </span>
          <span>1/12</span>
        </div>
        <p className="text-sm font-medium leading-snug">
          Qual organela realiza a respiração celular?
        </p>
        <div className="mt-6 h-24 rounded-lg bg-secondary/50" />
      </div>

      {/* Card 2 (meio) */}
      <div className="absolute right-6 top-4 h-56 w-72 rotate-[5deg] animate-float rounded-2xl border border-border bg-card p-5 shadow-xl sm:right-8">
        <div className="mb-3 flex items-center justify-between text-xs text-muted-foreground">
          <span className="rounded-full bg-indigo-500/10 px-2 py-0.5 font-medium text-indigo-600 dark:text-indigo-400">
            Direito
          </span>
          <span>próxima revisão: hoje</span>
        </div>
        <p className="text-sm font-medium leading-snug">
          Princípio da legalidade segundo a CF/88
        </p>
        <div className="mt-2 flex gap-1.5">
          {[0, 1, 2, 3, 4, 5].map((q) => (
            <div
              key={q}
              className="h-1.5 flex-1 rounded-full"
              style={{
                background:
                  q <= 3
                    ? `hsl(${12 + q * 20} 85% 58% / 0.85)`
                    : `hsl(${135 + (q - 4) * 10} 60% 50% / 0.85)`,
              }}
            />
          ))}
        </div>
      </div>

      {/* Card 3 (frente) */}
      <div className="absolute left-1/2 top-40 h-56 w-80 -translate-x-1/2 rotate-[2deg] rounded-2xl border border-indigo-700 bg-indigo-600 p-5 text-white shadow-xl">
        <div className="mb-3 flex items-center justify-between text-xs text-white/80">
          <span className="rounded-full bg-white/20 px-2 py-0.5 font-medium">
            🔥 Streak: 7 dias
          </span>
          <span>due: 12</span>
        </div>
        <p className="text-lg font-semibold leading-snug">
          Clique para mostrar a resposta
        </p>
        <div className="mt-4 rounded-lg bg-white/10 p-3 text-sm">
          A mitocôndria, através do ciclo de Krebs e da cadeia respiratória,
          produz ATP a partir de glicose e oxigênio.
        </div>
      </div>
    </div>
  );
}
