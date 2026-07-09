"use client";

import {
  Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer,
  Tooltip, XAxis, YAxis,
} from "recharts";
import { eur, MESES } from "@/lib/format";

export type TrendPoint = { mes: number; margen_neto: number };

const AXIS = "#898781";
const GRID = "#e1e0d9";

export function TrendChart({ data }: { data: TrendPoint[] }) {
  const rows = data.map((d) => ({ label: MESES[d.mes] ?? String(d.mes), margen_neto: d.margen_neto }));

  return (
    <ResponsiveContainer width="100%" height={280}>
      <BarChart data={rows} margin={{ top: 12, right: 8, left: 4, bottom: 4 }}>
        <CartesianGrid vertical={false} stroke={GRID} strokeWidth={1} />
        <XAxis dataKey="label" tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={{ stroke: GRID }} />
        <YAxis
          tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={false} width={64}
          tickFormatter={(v) => eur(Number(v))}
        />
        <Tooltip
          cursor={{ fill: "rgba(137,135,129,0.12)" }}
          formatter={(v: number) => [eur(v), "Margen Neto"]}
          contentStyle={{
            background: "var(--surface-1)", border: "1px solid var(--border)",
            borderRadius: 8, color: "var(--text-primary)", fontSize: 13,
          }}
          labelStyle={{ color: "var(--text-secondary)" }}
        />
        <Bar dataKey="margen_neto" radius={[4, 4, 0, 0]} maxBarSize={44}>
          {rows.map((r, i) => (
            <Cell key={i} fill={r.margen_neto >= 0 ? "var(--series-1)" : "var(--critical)"} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
