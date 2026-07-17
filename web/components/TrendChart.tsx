"use client";

import {
  Bar, BarChart, CartesianGrid, Cell, LabelList, ResponsiveContainer,
  Tooltip, XAxis, YAxis,
} from "recharts";
import { eur, MESES } from "@/lib/format";

export type TrendPoint = { mes: number; valor: number };

// colores por token → el gráfico respeta dark/light como el resto del sistema
const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

export function TrendChart({ data, nombre = "Margen neto" }: { data: TrendPoint[]; nombre?: string }) {
  const rows = data.map((d) => ({ label: MESES[d.mes] ?? String(d.mes), valor: d.valor }));

  return (
    <ResponsiveContainer width="100%" height={280}>
      <BarChart data={rows} margin={{ top: 18, right: 8, left: 4, bottom: 4 }}>
        <CartesianGrid vertical={false} stroke={GRID} strokeWidth={1} />
        <XAxis dataKey="label" tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={{ stroke: GRID }} />
        <YAxis
          tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={false} width={64}
          tickFormatter={(v) => eur(Number(v))}
        />
        <Tooltip
          cursor={{ fill: "rgba(137,135,129,0.12)" }}
          formatter={(v: number) => [eur(v), nombre]}
          contentStyle={{
            background: "var(--surface-1)", border: "1px solid var(--border)",
            borderRadius: 8, color: "var(--text-primary)", fontSize: 13,
          }}
          labelStyle={{ color: "var(--text-secondary)" }}
        />
        <Bar dataKey="valor" radius={[4, 4, 0, 0]} maxBarSize={44}>
          {rows.map((r, i) => (
            <Cell key={i} fill={r.valor >= 0 ? "var(--series-1)" : "var(--critical)"} />
          ))}
          {/* valores siempre visibles: el tooltip no existe en el móvil del CEO */}
          <LabelList dataKey="valor" position="top" formatter={(v: number) => eur(v)}
            style={{ fill: "var(--text-secondary)", fontSize: 10 }} />
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
