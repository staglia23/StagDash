// Año contra año (migración 094) — la lógica calculable sobre v_yoy_mensual,
// v_pace_yoy y v_pricelabs_mercado. Funciones puras testeadas; los numeric de
// Supabase llegan como string y acá se convierten UNA vez.
//
// Doctrina §5.5: YoY solo like-for-like y por piso. `comparable=false` = "el piso no
// existía": se dice, nunca se grafica como caída. El mes de alta del año previo
// (arranque_ly) se EXCLUYE de los agregados (Jacobine jun-2025: 6 noches de rampa que
// inflarían el delta) pero sí se dibuja, con su aviso.
// Todas las funciones esperan filas de UN solo piso: el caller filtra por codigo.
import { MESES } from "./format";

export type YoyRow = {
  codigo: string; anio: number; mes: number;
  noches: number | string; ocupacion: number | string;
  adr: number | string; revpar: number | string;
  noches_ly: number | string | null; ocupacion_ly: number | string | null;
  adr_ly: number | string | null; revpar_ly: number | string | null;
  comparable: boolean; arranque_ly: boolean;
};

export type PaceRow = {
  codigo: string; anio: number; mes: number; dias: number | string;
  noches_otb: number | string; adr_otb: number | string | null;
  noches_ly: number | string; adr_ly: number | string | null;
  stly_valido: boolean;
};

export type MercadoRow = {
  codigo: string; mes: string; // ISO "2026-04-01"
  adr_mercado: number | string | null; ocupacion_mercado: number | string | null;
  adr_mercado_ly: number | string | null; ocupacion_mercado_ly: number | string | null;
  n_listings: number | string | null; categoria: string; muestra_chica: boolean;
};

const diasDelMes = (anio: number, mes: number) => new Date(anio, mes, 0).getDate();

// ── El agregado YTD contra su año previo ────────────────────────────────────────
export type ResumenYoy = {
  adr: number; adrLy: number; deltaAdrPct: number;
  ocup: number; ocupLy: number; deltaOcupPp: number; // fracción (0,03 = 3 pp)
  revpar: number; revparLy: number; deltaRevparPct: number;
  noches: number; nochesLy: number;
  meses: number;          // meses comparables agregados
  mesesExcluidos: number; // meses de arranque del año previo, fuera del agregado
};

export function resumenYoy(rows: YoyRow[], anio: number): ResumenYoy | null {
  const comp = rows.filter((r) => r.anio === anio && r.comparable && !r.arranque_ly);
  const excluidos = rows.filter((r) => r.anio === anio && r.comparable && r.arranque_ly).length;
  if (!comp.length) return null;
  let noches = 0, aloj = 0, dias = 0, nochesLy = 0, alojLy = 0, diasLy = 0;
  for (const r of comp) {
    const n = Number(r.noches), nLy = Number(r.noches_ly ?? 0);
    noches += n; aloj += n * Number(r.adr);
    nochesLy += nLy; alojLy += nLy * Number(r.adr_ly ?? 0);
    dias += diasDelMes(r.anio, r.mes);
    diasLy += diasDelMes(r.anio - 1, r.mes);
  }
  if (nochesLy === 0) return null; // sin noches del año previo no hay delta honesto
  const adr = noches > 0 ? aloj / noches : 0;
  const adrLy = alojLy / nochesLy;
  return {
    adr, adrLy, deltaAdrPct: adrLy > 0 ? adr / adrLy - 1 : 0,
    ocup: noches / dias, ocupLy: nochesLy / diasLy,
    deltaOcupPp: noches / dias - nochesLy / diasLy,
    revpar: aloj / dias, revparLy: alojLy / diasLy,
    deltaRevparPct: alojLy > 0 ? (aloj / dias) / (alojLy / diasLy) - 1 : 0,
    noches, nochesLy, meses: comp.length, mesesExcluidos: excluidos,
  };
}

const signoPct = (d: number) => `${d >= 0 ? "+" : "−"}${Math.abs(Math.round(d * 100))} %`;

export function titularYoy(r: ResumenYoy | null): string {
  if (!r) return "Sin año previo comparable todavía.";
  const adrPlano = Math.abs(r.deltaAdrPct) < 0.005;
  const ocupPts = r.deltaOcupPp * 100;
  const ocup = Math.abs(ocupPts) < 0.5
    ? "igual ocupación"
    : `${ocupPts >= 0 ? "+" : "−"}${Math.abs(Math.round(ocupPts))} pp de ocupación`;
  if (adrPlano) return `Vende al precio del año pasado, con ${ocup}.`;
  const verbo = r.deltaAdrPct >= 0 ? "más caro" : "más barato";
  return `Vende un ${signoPct(r.deltaAdrPct)} ${verbo} que el año pasado, con ${ocup}.`;
}

// ── Serie mensual para el gráfico "este año vs el pasado" ───────────────────────
export type PuntoAdrYoy = { mes: number; adr: number | null; adrLy: number | null; arranqueLy: boolean };

export function serieAdrYoy(rows: YoyRow[], anio: number): PuntoAdrYoy[] {
  return rows
    .filter((r) => r.anio === anio)
    .sort((a, b) => a.mes - b.mes)
    .map((r) => ({
      mes: r.mes,
      adr: Number(r.noches) > 0 ? Number(r.adr) : null,
      adrLy: r.comparable && r.adr_ly != null && Number(r.noches_ly) > 0 ? Number(r.adr_ly) : null,
      arranqueLy: r.comparable && r.arranque_ly,
    }));
}

// ── Vos contra el barrio ────────────────────────────────────────────────────────
export type PuntoMercado = { label: string; propio: number | null; mercado: number | null };

/** mesLimite (ISO "2026-09-01"): el mes en curso del mercado llega a medio contar y se excluye. */
export function serieMercado(yoyRows: YoyRow[], mercadoRows: MercadoRow[], mesLimite: string): PuntoMercado[] {
  const propio = new Map(yoyRows.map((r) => [`${r.anio}-${r.mes}`, r]));
  return mercadoRows
    .filter((m) => !m.muestra_chica && m.mes < mesLimite)
    .sort((a, b) => (a.mes < b.mes ? -1 : 1))
    .map((m) => {
      const [a, mm] = m.mes.split("-").map(Number);
      const p = propio.get(`${a}-${mm}`);
      return {
        label: `${MESES[mm]} ${String(a).slice(2)}`,
        propio: p && Number(p.noches) > 0 ? Number(p.adr) : null,
        mercado: m.adr_mercado != null ? Number(m.adr_mercado) : null,
      };
    });
}

export type ResumenMercado = {
  mercadoYoyPct: number | null; // media de los YoY mensuales del barrio, meses del año
  premiumPct: number | null;    // ADR propio vs el del barrio, ponderado por noches propias
  meses: number;
};

export function resumenMercado(yoyRows: YoyRow[], mercadoRows: MercadoRow[], anio: number): ResumenMercado {
  const deltas: number[] = [];
  let aloj = 0, alojMercado = 0, noches = 0;
  for (const r of yoyRows) {
    if (r.anio !== anio) continue;
    const iso = `${anio}-${String(r.mes).padStart(2, "0")}-01`;
    const m = mercadoRows.find((x) => x.mes === iso);
    if (!m || m.muestra_chica) continue;
    const am = m.adr_mercado != null ? Number(m.adr_mercado) : null;
    const amLy = m.adr_mercado_ly != null ? Number(m.adr_mercado_ly) : null;
    if (am != null && amLy != null && amLy > 0) deltas.push(am / amLy - 1);
    const n = Number(r.noches);
    if (n > 0 && am != null) { aloj += n * Number(r.adr); alojMercado += n * am; noches += n; }
  }
  return {
    mercadoYoyPct: deltas.length ? deltas.reduce((s, d) => s + d, 0) / deltas.length : null,
    premiumPct: noches > 0 && alojMercado > 0 ? aloj / alojMercado - 1 : null,
    meses: deltas.length,
  };
}

/** La tendencia del barrio sola (para la vista de portfolio, sin línea propia). */
export function resumenMercadoSolo(mercadoRows: MercadoRow[], anio: number): {
  adrYoyPct: number | null; ocupYoyPp: number | null; meses: number;
} {
  const dAdr: number[] = [], dOcup: number[] = [];
  for (const m of mercadoRows) {
    if (m.muestra_chica || !m.mes.startsWith(String(anio))) continue;
    const am = m.adr_mercado != null ? Number(m.adr_mercado) : null;
    const amLy = m.adr_mercado_ly != null ? Number(m.adr_mercado_ly) : null;
    if (am != null && amLy != null && amLy > 0) dAdr.push(am / amLy - 1);
    const o = m.ocupacion_mercado != null ? Number(m.ocupacion_mercado) : null;
    const oLy = m.ocupacion_mercado_ly != null ? Number(m.ocupacion_mercado_ly) : null;
    if (o != null && oLy != null) dOcup.push(o - oLy);
  }
  const media = (xs: number[]) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : null);
  return { adrYoyPct: media(dAdr), ocupYoyPp: media(dOcup), meses: dAdr.length };
}

// ── El embudo pace: lo ya vendido vs cómo cerró el año pasado ───────────────────
export type FilaPace = {
  anio: number; mes: number; dias: number;
  otb: number;
  ly: number | null;           // null = el piso no existía (nunca "0")
  adrDeltaPct: number | null;  // null si la muestra es chica (<5 noches) o falta ADR
};

export function filasPace(rows: PaceRow[]): FilaPace[] {
  return [...rows]
    .sort((a, b) => a.anio - b.anio || a.mes - b.mes)
    .map((r) => {
      const otb = Number(r.noches_otb);
      const adrOtb = r.adr_otb != null ? Number(r.adr_otb) : null;
      const adrLy = r.adr_ly != null ? Number(r.adr_ly) : null;
      return {
        anio: r.anio, mes: r.mes, dias: Number(r.dias), otb,
        ly: r.stly_valido ? Number(r.noches_ly) : null,
        adrDeltaPct: r.stly_valido && otb >= 5 && adrOtb != null && adrLy != null && adrLy > 0
          ? adrOtb / adrLy - 1 : null,
      };
    });
}

/** Titular del embudo a nivel portfolio: rango de deltas de ADR de los 2 meses más cercanos. */
export function titularPace(porPiso: { filas: FilaPace[] }[]): string | null {
  const claves = [...new Set(porPiso.flatMap((p) => p.filas.map((f) => f.anio * 100 + f.mes)))]
    .sort((a, b) => a - b).slice(0, 2);
  if (!claves.length) return null;
  const deltas = porPiso
    .flatMap((p) => p.filas.filter((f) => claves.includes(f.anio * 100 + f.mes)))
    .map((f) => f.adrDeltaPct)
    .filter((d): d is number => d != null);
  if (!deltas.length) return null;
  const nombres = claves.map((c) => MESES[c % 100].toLowerCase()).join(" y ");
  const lo = Math.min(...deltas), hi = Math.max(...deltas);
  const rango = lo >= 0
    ? `entre ${signoPct(lo)} y ${signoPct(hi)} más caro`
    : hi < 0
      ? `entre ${signoPct(hi)} y ${signoPct(lo)} más barato`
      : `entre ${signoPct(lo)} y ${signoPct(hi)}`;
  return `Lo ya vendido para ${nombres} va ${rango} que como cerró el año pasado.`;
}

/** "octubre 2026" — cuándo estrena comparación un piso sin base: un año después del alta. */
export function estrenoYoy(fechaInicio: string | null): string | null {
  if (!fechaInicio) return null;
  const [a, m] = fechaInicio.split("-").map(Number);
  if (!a || !m) return null;
  return `${MESES[m].toLowerCase()} ${a + 1}`;
}
