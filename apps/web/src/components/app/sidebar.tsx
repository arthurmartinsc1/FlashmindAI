"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import Image from "next/image";
import {
  BookOpen,
  LayoutDashboard,
  GraduationCap,
} from "lucide-react";

import { cn } from "@/lib/utils";
import { UserMenu } from "./user-menu";

const NAV = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/decks", label: "Meus decks", icon: BookOpen },
  { href: "/review", label: "Revisar hoje", icon: GraduationCap },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="hidden w-60 shrink-0 flex-col border-r border-border bg-background lg:flex">
      <div className="flex h-16 items-center gap-2.5 border-b border-border px-5">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary p-1">
          <Image src="/bolt.png" alt="FlashMind" width={24} height={24} className="object-contain brightness-0 invert" />
        </div>
        <Link href="/dashboard" className="text-base font-semibold tracking-tight">
          FlashMind
        </Link>
      </div>

      <nav className="flex-1 px-3 py-4">
        <ul className="space-y-0.5">
          {NAV.map((item) => {
            const active =
              pathname === item.href || pathname?.startsWith(item.href + "/");
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={cn(
                    "group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    active
                      ? "bg-primary/8 text-primary"
                      : "text-muted-foreground hover:bg-secondary hover:text-foreground",
                  )}
                >
                  <span
                    className={cn(
                      "flex h-6 w-6 shrink-0 items-center justify-center rounded-md transition-colors",
                      active
                        ? "bg-primary text-white"
                        : "text-muted-foreground group-hover:text-foreground",
                    )}
                  >
                    <item.icon className="h-3.5 w-3.5" />
                  </span>
                  <span>{item.label}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="border-t border-border p-3">
        <UserMenu />
      </div>
    </aside>
  );
}
