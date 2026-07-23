"use client";

// RevPAR real mensual vs RevPAR de equilibrio — la historia "¿este piso mejora o empeora?"
// en un solo gráfico. Dos líneas, una escala (nunca doble eje), colores por token.
// Etiquetas selectivas (doctrina dataviz): solo el último punto de cada línea, en tinta
// de texto (nunca el color de la serie); el resto lo llevan el eje y el tooltip.
import {
  CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { eur, MESES } from "@/lib/format";

export type RevparPoint = { mes: number; revpar: number; revparEq: number | null };

const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

type LabelProps = { x?: number; y?: number; value?: number | null; index?: number };

/** Etiqueta solo en el punto final de la línea (endpoint), desplazada para no pisar el dot. */
const endLabel = (lastIdx: number, dy: number, fill: string, peso: number) =>
  function EndLabel({ x, y, value, index }: LabelProps) {
    // recharts exige un elemento SVG siempre: <g/> vacío en los puntos sin etiqueta
    if (index !== lastIdx || value == null || x == null || y == null) return <g />;
    return (
      <text x={x} y={y + dy} textAnchor="end" fill={fill} fontSize={11} fontWeight={peso}>
        {eur(Number(value))}
      </text>
    );
  };

export function RevparChart({ data, color }: { data: RevparPoint[]; color: string }) {
  const rows = data.map((d) => ({ label: MESES[d.mes] ?? String(d.mes), ...d }));
  const lastReal = rows.reduce((last, d, i) => (d.revpar != null ? i : last), -1);
  const lastEq = rows.reduce((last, d, i) => (d.revparEq != null ? i : last), -1);
  // Si los dos endpoints caen cerca, el real va arriba y el equilibrio abajo: no chocan.
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
        <Line name="RevPAR real" dataKey="revpar" stroke={color} strokeWidth={2.2}
          dot={{ r: 3, fill: color }} isAnimationActive={false}
          label={endLabel(lastReal, -9, "var(--text-primary)", 700)} />
        <Line name="RevPAR de equilibrio" dataKey="revparEq" stroke="var(--muted)"
          strokeWidth={1.8} strokeDasharray="6 4" dot={false} isAnimationActive={false}
          label={endLabel(lastEq, 16, "var(--text-secondary)", 600)} />
      </LineChart>
    </ResponsiveContainer>
  );
}
