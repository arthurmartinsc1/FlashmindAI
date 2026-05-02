import Link from "next/link";
import { Brain } from "lucide-react";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative min-h-dvh">
      <div className="pointer-events-none absolute inset-0 bg-radial-fade" />
      <header className="relative z-10 container flex h-16 items-center">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <Brain className="h-4 w-4 text-white" />
          </div>
          <span className="text-lg tracking-tight">FlashMind</span>
        </Link>
      </header>

      <main className="relative z-10 container flex min-h-[calc(100dvh-4rem)] items-center justify-center py-10">
        {children}
      </main>
    </div>
  );
}
