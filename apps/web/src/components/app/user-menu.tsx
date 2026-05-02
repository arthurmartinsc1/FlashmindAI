"use client";

import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";

import { Button } from "@/components/ui/button";
import { logoutRemote } from "@/lib/auth-api";
import { useAuthStore } from "@/stores/auth-store";

export function UserMenu() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);

  async function handleLogout() {
    try {
      await logoutRemote();
    } catch {
      /* mesmo se a API falhar, fazemos logout local */
    } finally {
      logout();
      router.replace("/login");
    }
  }

  if (!user) return null;

  const initials = user.name
    .split(" ")
    .map((w) => w[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  return (
    <div className="flex items-center gap-3">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-white">
        {initials || "?"}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium leading-tight">{user.name}</p>
        <p className="truncate text-xs text-muted-foreground">{user.email}</p>
      </div>
      <Button
        variant="ghost"
        size="icon"
        onClick={handleLogout}
        aria-label="Sair"
        className="h-8 w-8"
      >
        <LogOut className="h-4 w-4" />
      </Button>
    </div>
  );
}
