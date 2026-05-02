import { Sparkles, BookOpenText, Repeat2 } from "lucide-react";

const STEPS = [
  {
    icon: Sparkles,
    title: "Gere cards com IA",
    description:
      "Informe um tópico (“Ciclo de Krebs”, “Fotossíntese”) e a IA cria um deck completo em segundos. Ou importe seus próprios.",
    badge: "Passo 1",
  },
  {
    icon: BookOpenText,
    title: "Aprenda em 5 minutos",
    description:
      "Microlições curtas com texto, highlights e quiz ensinam antes de testar. Zero sobrecarga, máxima retenção.",
    badge: "Passo 2",
  },
  {
    icon: Repeat2,
    title: "Revise na hora certa",
    description:
      "O algoritmo SM-2 agenda cada card no momento exato em que você está prestes a esquecer. Streak diário opcional.",
    badge: "Passo 3",
  },
];

export function HowItWorks() {
  return (
    <section id="how" className="border-t border-border/60 py-20 lg:py-28">
      <div className="container">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
            Do zero ao domínio em <span className="text-primary">3 passos</span>
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Sem montar planilha, sem decorar ritmo de revisão. A gente cuida.
          </p>
        </div>

        <div className="mt-14 grid gap-6 md:grid-cols-3">
          {STEPS.map((step, idx) => (
            <div
              key={step.title}
              className="group relative overflow-hidden rounded-2xl border border-border bg-card p-6 transition-all hover:-translate-y-1 hover:border-primary/40 hover:shadow-lg"
            >
              <div className="mb-4 flex items-center justify-between">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary">
                  <step.icon className="h-5 w-5 text-white" />
                </div>
                <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                  {step.badge}
                </span>
              </div>

              <h3 className="mb-2 text-xl font-semibold">{step.title}</h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {step.description}
              </p>

            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
