"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { AxiosError } from "axios";
import { useMutation } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { registerUser } from "@/lib/auth-api";
import { useAuthStore } from "@/stores/auth-store";
import type { ApiError, AuthResponse } from "@/types/api";

function validatePassword(pwd: string): string | null {
  if (pwd.length < 8) return "A senha precisa ter pelo menos 8 caracteres.";
  if (!/[A-Z]/.test(pwd)) return "A senha precisa ter ao menos 1 letra maiúscula.";
  if (!/\d/.test(pwd)) return "A senha precisa ter ao menos 1 número.";
  return null;
}

export function RegisterForm() {
  const router = useRouter();
  const loginWith = useAuthStore((s) => s.loginWith);

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [clientError, setClientError] = useState<string | null>(null);

  const mutation = useMutation<
    AuthResponse,
    AxiosError<ApiError>,
    { email: string; password: string; name: string }
  >({
    mutationFn: registerUser,
    onSuccess: (data) => {
      loginWith(data);
      router.replace(data.user.is_email_verified ? "/dashboard" : "/verify-email");
    },
    onError: (err) => {
      console.error("[register] error:", {
        message: err.message,
        status: err.response?.status,
        data: err.response?.data,
      });
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    const pwdError = validatePassword(password);
    if (pwdError) {
      setClientError(pwdError);
      return;
    }
    setClientError(null);
    mutation.mutate({ email: email.trim(), password, name: name.trim() });
  }

  const serverError = mutation.error?.response?.data?.detail ?? null;
  const networkError = mutation.error
    ? `${mutation.error.code ?? "ERR"}: ${mutation.error.message}`
    : null;
  const errorMessage =
    clientError ??
    serverError ??
    (mutation.error ? `Não foi possível criar a conta. (${networkError})` : null);

  return (
    <div className="w-full max-w-sm">
      <div className="mb-8 text-center">
        <h1 className="text-2xl font-bold tracking-tight">Crie sua conta</h1>
        <p className="mt-1.5 text-sm text-muted-foreground">
          Grátis. Sem cartão de crédito.
        </p>
      </div>

      <form onSubmit={onSubmit} className="rounded-2xl border border-border bg-card p-6">
        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="name">Nome</Label>
            <Input
              id="name"
              type="text"
              autoComplete="name"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Como devemos te chamar?"
              disabled={mutation.isPending}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="voce@email.com"
              disabled={mutation.isPending}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="password">Senha</Label>
            <Input
              id="password"
              type="password"
              autoComplete="new-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Mín. 8 caracteres, 1 maiúscula, 1 número"
              disabled={mutation.isPending}
            />
          </div>

          {errorMessage && (
            <p
              role="alert"
              className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700 dark:border-red-800/60 dark:bg-red-950/40 dark:text-red-400"
            >
              {errorMessage}
            </p>
          )}

          <Button type="submit" className="w-full" disabled={mutation.isPending}>
            {mutation.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            {mutation.isPending ? "Criando conta…" : "Criar conta grátis"}
          </Button>
        </div>

        <p className="mt-5 text-center text-sm text-muted-foreground">
          Já tem conta?{" "}
          <Link href="/login" className="font-medium text-primary hover:underline">
            Entrar
          </Link>
        </p>
      </form>
    </div>
  );
}
