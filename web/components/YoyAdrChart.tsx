"use client";

// ADR vendido este año contra el mismo mes del año pasado — clon del molde RevparChart:
// dos líneas, una escala, colores por token, etiquetas solo en el endpoint. El "año
// pasado" va punteado y en tinta neutra: el color siempre es "este año, este piso".
import {
  CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { eur, MESES } from "@/lib/format";
import type { PuntoAdrYoy } from "@/lib/yoy";

const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

type LabelProps = { x?: number; y?: number; value?: number | null; index?: number };

const endLabel = (lastIdx: number, dy: number, fill: string, peso: number) =>
  function EndLabel({ x, y, value, index }: LabelProps) {
    if (index !== lastIdx || value == null || x == null || y == null) return <g />;
    return (
      <text x={x} y={y + dy} textAnchor="end" fill={fill} fontSize={11} fontWeight={peso}>
        {eur(Number(value))}
      </text>
    );
  };

export function YoyAdrChart({ data, color, anio }: { data: PuntoAdrYoy[]; color: string; anio: number }) {
  const rows = data.map((d) => ({ label: MESES[d.mes] ?? String(d.mes), ...d }));
  const lastActual = rows.reduce((last, d, i) => (d.adr != null ? i : last), -1);
  const lastLy = rows.reduce((last, d, i) => (d.adrLy != null ? i : last), -1);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={rows} margin={{ top: 16, right: 12, left: 4, bottom: 4 }}>
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
        <Line name={`ADR ${anio}`} dataKey="adr" stroke={color} strokeWidth={2.2}
          dot={{ r: 3, fill: color }} isAnimationActive={false} connectNulls
          label={endLabel(lastActual, -9, "var(--text-primary)", 700)} />
        <Line name={`ADR ${anio - 1}`} dataKey="adrLy" stroke="var(--muted)"
          strokeWidth={1.8} strokeDasharray="6 4" dot={false} isAnimationActive={false} connectNulls
          label={endLabel(lastLy, 16, "var(--text-secondary)", 600)} />
      </LineChart>
    </ResponsiveContainer>
  );
}
