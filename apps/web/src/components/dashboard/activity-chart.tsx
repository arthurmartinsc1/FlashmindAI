"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { ActivityPoint } from "@/types/api";

function formatDate(dateStr: string) {
  const d = new Date(dateStr);
  return `${String(d.getUTCDate()).padStart(2, "0")}/${String(
    d.getUTCMonth() + 1,
  ).padStart(2, "0")}`;
}

export function ActivityChart({ data }: { data: ActivityPoint[] }) {
  const chartData = data.map((p) => ({
    date: formatDate(p.date),
    full: p.date,
    reviews: p.count,
  }));

  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-base font-semibold">Atividade</h3>
          <p className="text-xs text-muted-foreground">
            Revisões por dia — últimos 30 dias
          </p>
        </div>
      </div>

      <div className="mt-4 h-64 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="barGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(263 72% 50%)" stopOpacity={0.9} />
                <stop offset="100%" stopColor="hsl(263 72% 65%)" stopOpacity={0.55} />
              </linearGradient>
            </defs>
            <CartesianGrid
              strokeDasharray="3 3"
              vertical={false}
              stroke="hsl(240 5.9% 90%)"
              className="dark:stroke-zinc-800"
            />
            <XAxis
              dataKey="date"
              tickLine={false}
              axisLine={false}
              interval={4}
              tick={{ fontSize: 11, fill: "hsl(240 3.8% 46.1%)" }}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              allowDecimals={false}
              tick={{ fontSize: 11, fill: "hsl(240 3.8% 46.1%)" }}
              width={30}
            />
            <Tooltip
              cursor={{ fill: "hsl(263 72% 50% / 0.07)" }}
              contentStyle={{
                background: "hsl(0 0% 100%)",
                border: "1px solid hsl(240 5.9% 90%)",
                borderRadius: 12,
                fontSize: 12,
                boxShadow: "0 10px 30px rgb(0 0 0 / 0.08)",
              }}
              labelStyle={{ fontWeight: 600 }}
              formatter={(value: number) => [`${value} revisões`, ""]}
            />
            <Bar
              dataKey="reviews"
              fill="url(#barGrad)"
              radius={[6, 6, 2, 2]}
              maxBarSize={18}
            />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
