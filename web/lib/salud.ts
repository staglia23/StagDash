// Salud operativa por propiedad — PURA y testeable. Doctrina del prompt CEO: el único
// umbral objetivo es el punto de equilibrio (no se inventan targets), y todo estado lleva
// su "¿y qué?" (motivo). Ventanas: 7 días = casi definitivo (poco pickup restante),
// 30 días = tendencia (todavía entra venta).

export type SaludInput = {
  margenMes: number | null;      // margen neto del mes en curso con lo YA vendido (v_pnl_neto)
  ocup7: number;                 // 0..1 vendida próximos 7 días
  ocup30: number;                // 0..1 vendida próximos 30 días
  ocupBreakeven: number | null;  // ocupación de equilibrio YTD (v_breakeven)
  revparFwd30: number;           // bruto próximos 30 / 30
  revparEq: number | null;       // RevPAR de equilibrio (ver revparEquilibrio)
  diasSinVender: number | null;  // días desde la última reserva creada
};

export type Salud = {
  cls: "good" | "warning" | "critical";
  icon: string;
  label: string;
  motivo: string; // la razón concreta del estado, en una línea
};

export function estadoSalud(x: SaludInput): Salud {
  const sinVender = x.diasSinVender ?? 0;

  if (x.margenMes != null && x.margenMes < 0) {
    return { cls: "critical", icon: "⛔", label: "en riesgo",
      motivo: "el mes cierra en negativo con lo vendido hasta hoy" };
  }
  if (x.ocupBreakeven != null && x.ocup7 < x.ocupBreakeven - 0.10) {
    return { cls: "critical", icon: "⛔", label: "en riesgo",
      motivo: "la semana entrante está muy por debajo del equilibrio" };
  }
  if (sinVender > 14) {
    return { cls: "critical", icon: "⛔", label: "en riesgo",
      motivo: `${sinVender} días sin una reserva nueva` };
  }
  if (x.revparEq != null && x.revparFwd30 < x.revparEq) {
    return { cls: "warning", icon: "⚠", label: "vigilar",
      motivo: "lo vendido a 30 días rinde por debajo del equilibrio" };
  }
  if (sinVender > 7) {
    return { cls: "warning", icon: "⚠", label: "vigilar",
      motivo: `${sinVender} días sin una reserva nueva` };
  }
  if (x.ocupBreakeven != null && x.ocup30 < x.ocupBreakeven) {
    return { cls: "warning", icon: "⚠", label: "vigilar",
      motivo: "los próximos 30 días aún no cubren la ocupación de equilibrio" };
  }
  return { cls: "good", icon: "▲", label: "saludable", motivo: "vende al ritmo y precio necesarios" };
}

/** RevPAR de equilibrio en base bruta (comparable con bruto/noche disponible):
 *  costes totales YTD repartidos por noche disponible, convertidos a precio de venta. */
export function revparEquilibrio(x: {
  modelo: string;
  costesTotalesYtd: number;   // directos + cuota overhead, en positivo
  diasDisponiblesYtd: number;
  feeAparente: number;        // 1 − ingreso_noches/bruto (no aplica a modelo comisión)
  comisionModeloPct: number;  // JACO 0,3025
}): number | null {
  if (x.diasDisponiblesYtd <= 0) return null;
  const netoPorDia = x.costesTotalesYtd / x.diasDisponiblesYtd;
  const factor = x.modelo === "comision" ? x.comisionModeloPct : 1 - x.feeAparente;
  return factor > 0 ? netoPorDia / factor : null;
}
