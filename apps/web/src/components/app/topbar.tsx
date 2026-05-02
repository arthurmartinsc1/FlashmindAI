"use client";

import { Brain } from "lucide-react";
import Link from "next/link";
import { UserMenu } from "./user-menu";

export function Topbar() {
  return (
    <header className="flex h-14 items-center justify-between border-b border-border bg-background px-4 lg:hidden">
      <Link href="/dashboard" className="flex items-center gap-2 font-semibold">
        <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary">
          <Brain className="h-3.5 w-3.5 text-white" />
        </div>
        <span className="tracking-tight">FlashMind</span>
      </Link>
      <div className="flex items-center">
        <UserMenu />
      </div>
    </header>
  );
}
