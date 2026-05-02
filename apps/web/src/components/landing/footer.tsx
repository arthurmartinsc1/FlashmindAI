import Link from "next/link";
import { Brain, Github } from "lucide-react";

const LINKS = {
  produto: [
    { label: "Como funciona", href: "#how" },
    { label: "Features", href: "#features" },
    { label: "Planos", href: "#pricing" },
  ],
};

export function Footer() {
  return (
    <footer className="border-t border-border/60 bg-secondary/20">
      <div className="container grid gap-10 py-14 md:grid-cols-[1.5fr_1fr]">
        <div className="max-w-sm">
          <Link href="/" className="flex items-center gap-2 font-semibold">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
              <Brain className="h-4 w-4 text-white" />
            </div>
            <span className="text-lg tracking-tight">FlashMind</span>
          </Link>
          <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
            Flashcards inteligentes com repetição espaçada, microlearning e IA.
            Feito pra quem estuda todo dia.
          </p>
          <div className="mt-5 flex gap-3">
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="GitHub"
              className="flex h-9 w-9 items-center justify-center rounded-lg border border-border text-muted-foreground transition-colors hover:bg-accent/20 hover:text-foreground"
            >
              <Github className="h-4 w-4" />
            </a>
          </div>
        </div>

        <FooterColumn title="Produto" links={LINKS.produto} />
      </div>

      <div className="border-t border-border/60">
        <div className="container flex flex-col items-center justify-between gap-3 py-6 text-xs text-muted-foreground sm:flex-row">
          <p>© {new Date().getFullYear()} FlashMind. Todos os direitos reservados.</p>
          
        </div>
      </div>
    </footer>
  );
}

function FooterColumn({
  title,
  links,
}: {
  title: string;
  links: { label: string; href: string }[];
}) {
  return (
    <div>
      <h4 className="mb-4 text-sm font-semibold">{title}</h4>
      <ul className="space-y-2.5">
        {links.map((link) => (
          <li key={link.href}>
            <Link
              href={link.href}
              className="text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
