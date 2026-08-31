"use client";

// El piso contra su barrio, mes a mes (serie larga de v_pricelabs_mercado). La línea de
// color es el piso; la neutra punteada, el compset de PriceLabs. En la vista de
// portfolio la línea propia puede venir vacía y el gráfico queda solo con el barrio
// (una serie → sin leyenda redundante, el título la nombra).
import {
  CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { eur } from "@/lib/format";
import type { PuntoMercado } from "@/lib/yoy";

const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

export function MercadoChart({ data, color, nombrePropio, nombreMercado }: {
  data: PuntoMercado[]; color: string; nombrePropio?: string; nombreMercado: string;
}) {
  const tienePropio = data.some((d) => d.propio != null);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 16, right: 12, left: 4, bottom: 4 }}>
        <CartesianGrid vertical={false} stroke={GRID} strokeWidth={1} />
        <XAxis dataKey="label" tick={{ fill: AXIS, fontSize: 11 }} tickLine={false}
          axisLine={{ stroke: GRID }} interval="preserveStartEnd" minTickGap={28} />
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
        {tienePropio && <Legend wrapperStyle={{ fontSize: 12, color: "var(--text-secondary)" }} />}
        {tienePropio && (
          <Line name={nombrePropio ?? "Propio"} dataKey="propio" stroke={color} strokeWidth={2.2}
            dot={{ r: 2.5, fill: color }} isAnimationActive={false} connectNulls />
        )}
        <Line name={nombreMercado} dataKey="mercado" stroke="var(--muted)"
          strokeWidth={tienePropio ? 1.8 : 2.2} strokeDasharray={tienePropio ? "6 4" : undefined}
          dot={false} isAnimationActive={false} connectNulls />
      </LineChart>
    </ResponsiveContainer>
  );
}
