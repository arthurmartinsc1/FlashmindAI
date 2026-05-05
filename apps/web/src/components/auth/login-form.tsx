"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";
import { AxiosError } from "axios";
import { useMutation } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { loginUser } from "@/lib/auth-api";
import { useAuthStore } from "@/stores/auth-store";
import type { ApiError, AuthResponse } from "@/types/api";

export function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/dashboard";
  const loginWith = useAuthStore((s) => s.loginWith);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const mutation = useMutation<
    AuthResponse,
    AxiosError<ApiError>,
    { email: string; password: string }
  >({
    mutationFn: loginUser,
    onSuccess: (data) => {
      loginWith(data);
      if (!data.user.is_email_verified) {
        router.replace("/verify-email");
        return;
      }
      router.replace(next);
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    mutation.mutate({ email: email.trim(), password });
  }

  const errorMessage =
    mutation.error?.response?.data?.detail ??
    (mutation.error ? "Não foi possível entrar. Tente novamente." : null);

  return (
    <div className="w-full max-w-sm">
      <div className="mb-8 text-center">
        <h1 className="text-2xl font-bold tracking-tight">Bem-vindo de volta</h1>
        <p className="mt-1.5 text-sm text-muted-foreground">
          Entre para continuar estudando.
        </p>
      </div>

      <form onSubmit={onSubmit} className="rounded-2xl border border-border bg-card p-6">
        <div className="space-y-4">
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
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
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

          <Button type="submit" className="w-full gap-2" disabled={mutation.isPending}>
            {mutation.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            {mutation.isPending ? "Entrando…" : "Entrar"}
          </Button>
        </div>

        <p className="mt-5 text-center text-sm text-muted-foreground">
          Não tem conta?{" "}
          <Link href="/register" className="font-medium text-primary hover:underline">
            Cadastre-se grátis
          </Link>
        </p>
      </form>
    </div>
  );
}
