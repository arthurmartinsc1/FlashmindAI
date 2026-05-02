import Link from "next/link";
import { Brain } from "lucide-react";
import { Button } from "@/components/ui/button";

const NAV_LINKS = [
  { href: "#how", label: "Como funciona" },
  { href: "#features", label: "Features" },
  { href: "#pricing", label: "Planos" },
];

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/70 backdrop-blur-xl">
      <div className="container flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <Brain className="h-4 w-4 text-white" />
          </div>
          <span className="text-lg tracking-tight">FlashMind</span>
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" className="hidden sm:inline-flex" asChild>
            <Link href="/login">Entrar</Link>
          </Button>
          <Button size="sm" asChild>
            <Link href="/register">Começar grátis</Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
