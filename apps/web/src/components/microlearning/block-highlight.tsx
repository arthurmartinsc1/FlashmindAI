import { Lightbulb } from "lucide-react";
import type { HighlightBlockContent } from "@/types/api";

const COLOR_MAP = {
  yellow: {
    wrapper: "border-yellow-400/40 bg-yellow-400/10",
    icon:    "text-yellow-500",
    text:    "text-yellow-900 dark:text-yellow-100",
  },
  blue: {
    wrapper: "border-blue-400/40 bg-blue-400/10",
    icon:    "text-blue-500",
    text:    "text-blue-900 dark:text-blue-100",
  },
  green: {
    wrapper: "border-emerald-400/40 bg-emerald-400/10",
    icon:    "text-emerald-500",
    text:    "text-emerald-900 dark:text-emerald-100",
  },
} as const;

export function BlockHighlight({ content }: { content: HighlightBlockContent }) {
  const { wrapper, icon, text } = COLOR_MAP[content.color ?? "yellow"];
  return (
    <div className={`flex gap-3 rounded-xl border p-4 ${wrapper}`}>
      <Lightbulb className={`mt-0.5 h-4 w-4 shrink-0 ${icon}`} />
      <p className={`text-sm leading-relaxed ${text}`}>{content.body}</p>
    </div>
  );
}
