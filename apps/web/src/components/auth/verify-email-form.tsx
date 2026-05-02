"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AxiosError } from "axios";
import { useMutation } from "@tanstack/react-query";
import { CheckCircle2, Mail } from "lucide-react";

import { Button } from "@/components/ui/button";
import { PinInput } from "@/components/auth/pin-input";
import { resendEmailVerification, verifyEmailPin } from "@/lib/auth-api";
import { useAuthStore } from "@/stores/auth-store";
import type { ApiError, User } from "@/types/api";

export function VerifyEmailForm() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);

  const [pin, setPin] = useState("");
  const [cooldown, setCooldown] = useState(0);
  const [resentMsg, setResentMsg] = useState<string | null>(null);

  // Decremento do cooldown de reenvio.
  useEffect(() => {
    if (cooldown <= 0) return;
    const id = setInterval(() => setCooldown((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(id);
  }, [cooldown]);

  const verifyMutation = useMutation<User, AxiosError<ApiError>, string>({
    mutationFn: verifyEmailPin,
    onSuccess: (updated) => {
      setUser(updated);
      router.replace("/dashboard");
    },
    onError: () => setPin(""),
  });

  const resendMutation = useMutation<
    Awaited<ReturnType<typeof resendEmailVerification>>,
    AxiosError<ApiError>
  >({
    mutationFn: resendEmailVerification,
    onSuccess: (data) => {
      setCooldown(data.cooldown_seconds);
      setResentMsg("Novo código enviado. Confira seu email.");
      setTimeout(() => setResentMsg(null), 4000);
    },
  });

  // Já está verificado? manda direto pro dashboard.
  useEffect(() => {
    if (user?.is_email_verified) router.replace("/dashboard");
  }, [user?.is_email_verified, router]);

  const verifyError =
    verifyMutation.error?.response?.data?.detail ??
    (verifyMutation.error ? "Não foi possível validar o código." : null);

  const resendError =
    resendMutation.error?.response?.data?.detail ?? null;

  const canResend = cooldown === 0 && !resendMutation.isPending;

  return (
    <div className="w-full max-w-md">
      <div className="mb-8 text-center">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <Mail className="h-7 w-7" />
        </div>
        <h1 className="text-3xl font-bold tracking-tight">Confirme seu email</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Enviamos um código de 6 dígitos para
          <br />
          <strong className="text-foreground">{user?.email ?? "seu email"}</strong>.
        </p>
      </div>

      <div className="rounded-2xl border border-border bg-card p-6 shadow-xl">
        <div className="space-y-5">
          <PinInput
            value={pin}
            onChange={setPin}
            onComplete={(code) => verifyMutation.mutate(code)}
            disabled={verifyMutation.isPending}
            autoFocus
          />

          {verifyError && (
            <p
              role="alert"
              className="rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-center text-sm font-medium text-red-600 dark:text-red-400"
            >
              {verifyError}
            </p>
          )}

          {resentMsg && (
            <p
              role="status"
              className="flex items-center justify-center gap-2 rounded-lg border border-emerald-500/40 bg-emerald-500/10 px-3 py-2 text-center text-sm font-medium text-emerald-600 dark:text-emerald-400"
            >
              <CheckCircle2 className="h-4 w-4" />
              {resentMsg}
            </p>
          )}

          {resendError && !resentMsg && (
            <p
              role="alert"
              className="rounded-lg border border-amber-500/40 bg-amber-500/10 px-3 py-2 text-center text-sm font-medium text-amber-600 dark:text-amber-400"
            >
              {resendError}
            </p>
          )}

          <Button
            className="w-full"
            disabled={pin.length < 6 || verifyMutation.isPending}
            onClick={() => verifyMutation.mutate(pin)}
          >
            {verifyMutation.isPending ? "Verificando..." : "Confirmar"}
          </Button>
        </div>

        <div className="mt-6 text-center text-sm text-muted-foreground">
          Não recebeu o código?{" "}
          <button
            type="button"
            onClick={() => resendMutation.mutate()}
            disabled={!canResend}
            className="font-medium text-primary hover:underline disabled:cursor-not-allowed disabled:text-muted-foreground disabled:no-underline"
          >
            {cooldown > 0
              ? `Reenviar em ${cooldown}s`
              : resendMutation.isPending
                ? "Reenviando..."
                : "Reenviar"}
          </button>
        </div>
      </div>
    </div>
  );
}
