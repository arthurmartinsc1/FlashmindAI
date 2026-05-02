import Link from "next/link";
import { Check, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

type Plan = {
  name: string;
  price: string;
  priceSuffix: string;
  tagline: string;
  features: string[];
  cta: string;
  href: string;
  highlighted?: boolean;
};

const PLANS: Plan[] = [
  {
    name: "Free",
    price: "R$ 0",
    priceSuffix: "/mês",
    tagline: "Perfeito pra começar e manter o hábito.",
    features: [
      "Até 5 decks e 1.000 cards",
      "Geração com IA: 10/dia",
      "Repetição espaçada completa",
      "Dashboard com streak e retenção",
      "Sincronização com app mobile",
    ],
    cta: "Criar conta grátis",
    href: "/register",
  },
  {
    name: "Pro",
    price: "R$ 29",
    priceSuffix: "/mês",
    tagline: "Pra quem estuda sério todo dia.",
    features: [
      "Decks e cards ilimitados",
      "Geração com IA ilimitada",
      "Análises avançadas de performance",
      "Prioridade na fila da IA",
      "Sem anúncios",
      "Suporte dedicado",
    ],
    cta: "Assinar Pro",
    href: "/register?plan=pro",
    highlighted: true,
  },
];

export function Pricing() {
  return (
    <section id="pricing" className="border-t border-border/60 py-20 lg:py-28">
      <div className="container">
        <div className="mx-auto max-w-2xl text-center">
          <Badge variant="default" className="mb-4 mx-auto w-fit">
            Preços simples
          </Badge>
          <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
            Comece grátis. Upgrade quando precisar.
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Sem pegadinhas, sem cobrança surpresa. Cancele quando quiser.
          </p>
        </div>

        <div className="mx-auto mt-14 grid max-w-4xl gap-6 md:grid-cols-2">
          {PLANS.map((plan) => (
            <div
              key={plan.name}
              className={cn(
                "relative flex flex-col rounded-2xl border bg-card p-8 transition-all",
                plan.highlighted
                  ? "border-primary shadow-2xl shadow-primary/20"
                  : "border-border hover:border-primary/40",
              )}
            >
              {plan.highlighted && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <Badge variant="default" className="gap-1.5 shadow-lg">
                    <Sparkles className="h-3 w-3" />
                    Mais popular
                  </Badge>
                </div>
              )}

              <div>
                <h3 className="text-xl font-semibold">{plan.name}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{plan.tagline}</p>
                <div className="mt-6 flex items-baseline gap-1">
                  <span className="text-4xl font-bold tracking-tight">{plan.price}</span>
                  <span className="text-sm text-muted-foreground">
                    {plan.priceSuffix}
                  </span>
                </div>
              </div>

              <ul className="mt-8 flex-1 space-y-3">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-3 text-sm">
                    <Check
                      className={cn(
                        "mt-0.5 h-4 w-4 shrink-0",
                        plan.highlighted ? "text-primary" : "text-emerald-500",
                      )}
                    />
                    <span className="text-muted-foreground">{f}</span>
                  </li>
                ))}
              </ul>

              <Button
                className="mt-8 w-full"
                size="lg"
                variant={plan.highlighted ? "default" : "outline"}
                asChild
              >
                <Link href={plan.href}>{plan.cta}</Link>
              </Button>
            </div>
          ))}
        </div>

        <p className="mt-10 text-center text-xs text-muted-foreground">
          Precisa de plano para escolas ou turmas?{" "}
          <a href="mailto:ola@flashmind.app" className="text-primary hover:underline">
            Fale com a gente
          </a>
          .
        </p>
      </div>
    </section>
  );
}
