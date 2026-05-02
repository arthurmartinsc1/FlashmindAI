"use client";

import { motion } from "framer-motion";
import { cn } from "@/lib/utils";

const RATINGS = [
  {
    value: 1,
    label: "Não lembrei",
    sub: "Vejo amanhã",
    ring: "border-red-200 bg-red-50 text-red-700 hover:bg-red-100 dark:border-red-800/60 dark:bg-red-950/40 dark:text-red-400 dark:hover:bg-red-950/70",
  },
  {
    value: 3,
    label: "Difícil",
    sub: "Mas lembrei",
    ring: "border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100 dark:border-amber-800/60 dark:bg-amber-950/40 dark:text-amber-400 dark:hover:bg-amber-950/70",
  },
  {
    value: 4,
    label: "Bom",
    sub: "Lembrei bem",
    ring: "border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:border-emerald-800/60 dark:bg-emerald-950/40 dark:text-emerald-400 dark:hover:bg-emerald-950/70",
  },
  {
    value: 5,
    label: "Fácil",
    sub: "Sem esforço",
    ring: "border-emerald-300 bg-emerald-100 text-emerald-800 hover:bg-emerald-200 dark:border-emerald-700/60 dark:bg-emerald-900/40 dark:text-emerald-300 dark:hover:bg-emerald-900/70",
  },
] as const;

interface RatingButtonsProps {
  onRate: (quality: number) => void;
  disabled?: boolean;
}

export function RatingButtons({ onRate, disabled }: RatingButtonsProps) {
  return (
    <motion.div
      className="grid grid-cols-2 gap-2 sm:grid-cols-4"
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
    >
      {RATINGS.map((r) => (
        <button
          key={r.value}
          disabled={disabled}
          onClick={() => onRate(r.value)}
          className={cn(
            "flex flex-col items-center rounded-xl border px-3 py-3 transition-all active:scale-95 disabled:opacity-40",
            r.ring,
          )}
        >
          <span className="text-sm font-semibold">{r.label}</span>
          <span className="mt-0.5 text-xs opacity-70">{r.sub}</span>
        </button>
      ))}
    </motion.div>
  );
}
