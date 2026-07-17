"use client";

// Waterfall de margen (02_Prompt §5.3): bruto → −comisión → ingreso Samavi → −costes
// directos → margen directo → −overhead → margen neto. Horizontal: en móvil las etiquetas
// de categoría quedan siempre legibles y los importes van como texto fijo (sin tooltip).
import {
  Bar, BarChart, CartesianGrid, Cell, LabelList, ResponsiveContainer, XAxis, YAxis,
} from "recharts";
import { eur } from "@/lib/format";
import type { PasoWaterfall } from "@/lib/waterfall";

const AXIS = "var(--muted)";
const GRID = "var(--gridline)";

export function WaterfallChart({ pasos, color }: { pasos: PasoWaterfall[]; color: string }) {
  const rows = pasos.map((p) => {
    const delta = p.hasta - p.desde;
    return {
      label: p.label,
      base: Math.min(p.desde, p.hasta),
      valor: Math.abs(delta),
      // el signo sale del delta real: una entrada o un abono SUMAN y lo dicen
      etiqueta: p.tipo === "total" ? eur(p.hasta) : `${delta < 0 ? "−" : "+"}${eur(Math.abs(delta))}`,
      tipo: p.tipo,
      esCredito: p.tipo !== "total" && delta > 0,
    };
  });
  const alto = rows.length * 34 + 30;
  // dominio explícito: sin él Recharts arranca en 0 y recorta los escalones negativos
  const minVal = Math.min(0, ...pasos.map((p) => Math.min(p.desde, p.hasta)));
  const maxVal = Math.max(0, ...pasos.map((p) => Math.max(p.desde, p.hasta)));

  return (
    <ResponsiveContainer width="100%" height={alto}>
      <BarChart data={rows} layout="vertical" margin={{ top: 4, right: 70, left: 0, bottom: 4 }}>
        <CartesianGrid horizontal={false} stroke={GRID} strokeWidth={1} />
        <XAxis type="number" domain={[minVal, maxVal]} tick={{ fill: AXIS, fontSize: 11 }}
          tickLine={false} axisLine={{ stroke: GRID }} tickFormatter={(v) => eur(Number(v))} />
        <YAxis type="category" dataKey="label" width={104}
          tick={{ fill: AXIS, fontSize: 11 }} tickLine={false} axisLine={false} />
        <Bar dataKey="base" stackId="w" fill="transparent" isAnimationActive={false} />
        <Bar dataKey="valor" stackId="w" isAnimationActive={false} radius={[2, 2, 2, 2]} maxBarSize={22}>
          {rows.map((r, i) => (
            <Cell key={i}
              fill={r.tipo === "total" ? color : r.esCredito ? "var(--good)" : "var(--critical)"}
              fillOpacity={r.tipo === "total" ? 1 : 0.75} />
          ))}
          <LabelList dataKey="etiqueta" position="right"
            style={{ fill: "var(--text-secondary)", fontSize: 11 }} />
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
