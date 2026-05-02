"use client";

import {
  ChangeEvent,
  ClipboardEvent,
  KeyboardEvent,
  useEffect,
  useRef,
  useState,
} from "react";
import { cn } from "@/lib/utils";

interface PinInputProps {
  length?: number;
  value: string;
  onChange: (value: string) => void;
  onComplete?: (value: string) => void;
  disabled?: boolean;
  autoFocus?: boolean;
}

/**
 * Input de PIN com `length` caixinhas (default 6). Aceita digitação,
 * backspace que volta foco, paste de 6 dígitos de uma vez, e dispara
 * `onComplete(pin)` quando o usuário preenche todas.
 */
export function PinInput({
  length = 6,
  value,
  onChange,
  onComplete,
  disabled,
  autoFocus,
}: PinInputProps) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const [internal, setInternal] = useState<string[]>(() =>
    Array.from({ length }, (_, i) => value[i] ?? ""),
  );

  // Mantém o estado interno sincronizado se o pai trocar o value externamente
  // (ex: clear after error).
  useEffect(() => {
    setInternal(Array.from({ length }, (_, i) => value[i] ?? ""));
  }, [value, length]);

  useEffect(() => {
    if (autoFocus) refs.current[0]?.focus();
  }, [autoFocus]);

  function setDigit(idx: number, digit: string) {
    const next = [...internal];
    next[idx] = digit;
    setInternal(next);
    const joined = next.join("");
    onChange(joined);
    if (joined.length === length && !next.includes("") && onComplete) {
      onComplete(joined);
    }
  }

  function handleChange(e: ChangeEvent<HTMLInputElement>, idx: number) {
    const raw = e.target.value;
    const digit = raw.replace(/\D/g, "").slice(-1);
    if (!digit) return;
    setDigit(idx, digit);
    if (idx < length - 1) refs.current[idx + 1]?.focus();
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>, idx: number) {
    if (e.key === "Backspace") {
      if (internal[idx]) {
        setDigit(idx, "");
      } else if (idx > 0) {
        refs.current[idx - 1]?.focus();
        setDigit(idx - 1, "");
      }
      e.preventDefault();
    } else if (e.key === "ArrowLeft" && idx > 0) {
      refs.current[idx - 1]?.focus();
    } else if (e.key === "ArrowRight" && idx < length - 1) {
      refs.current[idx + 1]?.focus();
    }
  }

  function handlePaste(e: ClipboardEvent<HTMLInputElement>) {
    const text = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
    if (!text) return;
    e.preventDefault();
    const arr = Array.from({ length }, (_, i) => text[i] ?? "");
    setInternal(arr);
    onChange(arr.join(""));
    const focusIdx = Math.min(text.length, length - 1);
    refs.current[focusIdx]?.focus();
    if (text.length === length && onComplete) onComplete(text);
  }

  return (
    <div className="flex justify-center gap-2 sm:gap-3">
      {internal.map((digit, i) => (
        <input
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={1}
          pattern="\d{1}"
          value={digit}
          disabled={disabled}
          onChange={(e) => handleChange(e, i)}
          onKeyDown={(e) => handleKeyDown(e, i)}
          onPaste={handlePaste}
          aria-label={`Dígito ${i + 1} de ${length}`}
          className={cn(
            "h-14 w-12 rounded-lg border border-input bg-background text-center text-2xl font-semibold tabular-nums shadow-sm transition-all sm:h-16 sm:w-14 sm:text-3xl",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
            "disabled:cursor-not-allowed disabled:opacity-50",
            digit && "border-primary/60 bg-primary/5",
          )}
        />
      ))}
    </div>
  );
}
