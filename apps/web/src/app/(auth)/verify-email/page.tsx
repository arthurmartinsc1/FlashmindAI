"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";

import { VerifyEmailForm } from "@/components/auth/verify-email-form";
import { useAuthStore } from "@/stores/auth-store";

export default function VerifyEmailPage() {
  const router = useRouter();
  const hydrated = useAuthStore((s) => s.hydrated);
  const accessToken = useAuthStore((s) => s.accessToken);
  const [, setReady] = useState(false);

  useEffect(() => {
    if (!hydrated) return;
    if (!accessToken) {
      router.replace("/login?next=/verify-email");
      return;
    }
    setReady(true);
  }, [hydrated, accessToken, router]);

  if (!hydrated || !accessToken) {
    return (
      <div className="flex w-full items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return <VerifyEmailForm />;
}
