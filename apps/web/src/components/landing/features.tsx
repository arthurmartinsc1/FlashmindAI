import {
  Brain,
  Sparkles,
  Timer,
  Smartphone,
  LineChart,
  CalendarCheck,
} from "lucide-react";

const FEATURES = [
  {
    icon: Brain,
    title: "Repetição Espaçada (SM-2)",
    description:
      "O algoritmo que o Anki popularizou, afinado. A cada revisão, o sistema reagenda o card no intervalo ótimo entre esforço e retenção.",
  },
  {
    icon: Sparkles,
    title: "Geração de cards com IA",
    description:
      "Llama 3.3 70B + workflows durables do Temporal. Diga o tema, receba 10 cards de alta qualidade em ~30 segundos.",
  },
  {
    icon: Timer,
    title: "Microlearning de 5 minutos",
    description:
      "Sessões curtas que respeitam o pico de atenção. Cada lição mistura texto, quiz e destaques antes dos flashcards.",
  },
  {
    icon: Smartphone,
    title: "Offline no celular",
    description:
      "App Flutter com SQLite local (Drift). Estude no ônibus, sincronize quando voltar à rede. Zero fricção.",
  },
  {
    icon: LineChart,
    title: "Dashboard de verdade",
    description:
      "Streak diário, taxa de retenção, heatmap de atividade, distribuição entre cards novos / aprendendo / maduros.",
  },
  {
    icon: CalendarCheck,
    title: "Revisões no momento certo",
    description:
      "O algoritmo agenda cada card exatamente quando você está prestes a esquecer. Sem adivinhar, sem desperdício de tempo.",
  },
];

export function Features() {
  return (
    <section
      id="features"
      className="relative border-t border-border/60 bg-secondary/30 py-20 lg:py-28"
    >
      <div className="container">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
            Tudo que um estudante sério precisa
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Nenhuma feature supérflua. Cada uma resolve um problema real de quem
            estuda todo dia.
          </p>
        </div>

        <div className="mt-14 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="group rounded-2xl border border-border bg-card p-6 transition-all hover:border-primary/40 hover:shadow-lg"
            >
              <div className="mb-4 inline-flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                <f.icon className="h-5 w-5" />
              </div>
              <h3 className="mb-2 text-lg font-semibold">{f.title}</h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {f.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
