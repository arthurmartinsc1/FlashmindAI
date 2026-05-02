import { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface StatCardProps {
  label: string;
  value: string | number;
  hint?: string;
  icon: LucideIcon;
  tone?: "primary" | "success" | "amber" | "info";
}

const toneStyles: Record<NonNullable<StatCardProps["tone"]>, string> = {
  primary: "bg-primary/10 text-primary",
  success: "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400",
  amber: "bg-amber-500/10 text-amber-600 dark:text-amber-400",
  info: "bg-cyan-500/10 text-cyan-600 dark:text-cyan-400",
};

export function StatCard({
  label,
  value,
  hint,
  icon: Icon,
  tone = "primary",
}: StatCardProps) {
  return (
    <div className="rounded-2xl border border-border bg-card p-5 transition-shadow hover:shadow-md">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            {label}
          </p>
          <p className="mt-2 text-3xl font-bold tracking-tight">{value}</p>
          {hint && <p className="mt-1 text-xs text-muted-foreground">{hint}</p>}
        </div>
        <div
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-xl",
            toneStyles[tone],
          )}
        >
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </div>
  );
}
