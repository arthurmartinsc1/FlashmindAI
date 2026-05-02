"use client";

import { useRouter, usePathname } from "next/navigation";
import { useEffect } from "react";
import { Loader2 } from "lucide-react";

import { useAuthStore } from "@/stores/auth-store";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const hydrated = useAuthStore((s) => s.hydrated);
  const accessToken = useAuthStore((s) => s.accessToken);
  const user = useAuthStore((s) => s.user);

  useEffect(() => {
    if (!hydrated) return;
    if (!accessToken) {
      router.replace(
        `/login?next=${encodeURIComponent(pathname || "/dashboard")}`,
      );
      return;
    }
    // Bloqueia acesso ao app enquanto o email não é verificado.
    if (user && !user.is_email_verified) {
      router.replace("/verify-email");
    }
  }, [hydrated, accessToken, user, pathname, router]);

  const blocked =
    !hydrated || !accessToken || (user ? !user.is_email_verified : false);

  if (blocked) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return <>{children}</>;
}
