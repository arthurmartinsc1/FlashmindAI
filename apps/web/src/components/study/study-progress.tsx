"use client";

import { motion } from "framer-motion";

interface StudyProgressProps {
  current: number;
  total: number;
}

export function StudyProgress({ current, total }: StudyProgressProps) {
  const pct = total > 0 ? (current / total) * 100 : 0;

  return (
    <div className="space-y-1.5">
      <div className="h-1.5 w-full overflow-hidden rounded-full bg-secondary">
        <motion.div
          className="h-full rounded-full bg-primary"
          initial={{ width: 0 }}
          animate={{ width: `${pct}%` }}
          transition={{ ease: "easeOut", duration: 0.4 }}
        />
      </div>
    </div>
  );
}
