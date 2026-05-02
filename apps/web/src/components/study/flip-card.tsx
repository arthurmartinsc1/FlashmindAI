"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { RotateCcw } from "lucide-react";

interface FlipCardProps {
  front: string;
  back: string;
  onFlip?: () => void;
}

export function FlipCard({ front, back, onFlip }: FlipCardProps) {
  const [flipped, setFlipped] = useState(false);

  useEffect(() => {
    setFlipped(false);
  }, [front, back]);

  const handleFlip = () => {
    if (!flipped) {
      setFlipped(true);
      onFlip?.();
    }
  };

  return (
    <div
      className="relative h-72 w-full cursor-pointer select-none sm:h-80"
      style={{ perspective: "1200px" }}
      onClick={handleFlip}
      role="button"
      aria-label={flipped ? "Card — resposta visível" : "Clique para revelar a resposta"}
    >
      <motion.div
        className="relative h-full w-full"
        style={{ transformStyle: "preserve-3d" }}
        animate={{ rotateY: flipped ? 180 : 0 }}
        transition={{ duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
      >
        {/* Frente */}
        <div
          className="absolute inset-0 flex flex-col items-center justify-center rounded-2xl border border-border bg-card p-8 shadow-sm"
          style={{ backfaceVisibility: "hidden", WebkitBackfaceVisibility: "hidden" }}
        >
          {/* Accent bar no topo */}
          <div className="absolute inset-x-0 top-0 h-1 rounded-t-2xl bg-primary" />
          <p className="text-center text-xl font-semibold leading-relaxed">{front}</p>
          <span className="mt-6 flex items-center gap-1.5 text-xs text-muted-foreground">
            <RotateCcw className="h-3.5 w-3.5" />
            Clique para revelar
          </span>
        </div>

        {/* Verso */}
        <div
          className="absolute inset-0 flex flex-col items-center justify-center rounded-2xl border border-border bg-card p-8 shadow-sm"
          style={{ backfaceVisibility: "hidden", WebkitBackfaceVisibility: "hidden", transform: "rotateY(180deg)" }}
        >
          <div className="absolute inset-x-0 top-0 h-1 rounded-t-2xl bg-amber-500" />
          <p className="text-center text-lg leading-relaxed">{back}</p>
        </div>
      </motion.div>
    </div>
  );
}
