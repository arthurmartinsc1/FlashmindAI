import { AuthGuard } from "@/components/app/auth-guard";
import { Sidebar } from "@/components/app/sidebar";
import { Topbar } from "@/components/app/topbar";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGuard>
      <div className="flex min-h-dvh">
        <Sidebar />
        <div className="flex min-h-dvh flex-1 flex-col">
          <Topbar />
          <main className="flex-1 overflow-x-hidden px-4 py-6 lg:px-10 lg:py-8">
            {children}
          </main>
        </div>
      </div>
    </AuthGuard>
  );
}
