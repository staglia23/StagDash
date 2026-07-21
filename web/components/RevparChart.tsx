"use client";

// RevPAR real mensual vs RevPAR de equilibrio — la historia "¿este piso mejora o empeora?"
// en un solo gráfico. Dos líneas, una escala (nunca doble eje), colores por token.
import {
  CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { eur, MESES } from "@/lib/format";

export type RevparPoint = { mes: number; revpar: number; revparEq: number | null };

const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

export function RevparChart({ data, color }: { data: RevparPoint[]; color: string }) {
  const rows = data.map((d) => ({ label: MESES[d.mes] ?? String(d.mes), ...d }));
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={rows} margin={{ top: 8, right: 12, left: 4, bottom: 4 }}>
        <CartesianGrid vertical={false} stroke={GRID} strokeWidth={1} />
        <XAxis dataKey="label" tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={{ stroke: GRID }} />
        <YAxis tick={{ fill: AXIS, fontSize: 12 }} tickLine={false} axisLine={false} width={56}
          tickFormatter={(v) => eur(Number(v))} />
        <Tooltip
          formatter={(v: number, name: string) => [eur(v), name]}
          contentStyle={{
            background: "var(--surface-1)", border: "1px solid var(--border)",
            borderRadius: 8, color: "var(--text-primary)", fontSize: 13,
          }}
          labelStyle={{ color: "var(--text-secondary)" }}
        />
        <Legend wrapperStyle={{ fontSize: 12, color: "var(--text-secondary)" }} />
        <Line name="RevPAR real" dataKey="revpar" stroke={color} strokeWidth={2.2}
          dot={{ r: 3, fill: color }} isAnimationActive={false} />
        <Line name="RevPAR de equilibrio" dataKey="revparEq" stroke="var(--muted)"
          strokeWidth={1.8} strokeDasharray="6 4" dot={false} isAnimationActive={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}
