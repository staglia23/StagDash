// Titular generado de la portada (Morning Check). Función PURA y testeable.
// Especificación (02_Prompt_Dashboard_CEO §5.1/§9.2):
//   · ≤ 90 caracteres, formato "[dato] — [causa o consecuencia]", verbo activo, cero adjetivos.
//   · Cascada: (1) alerta con fecha límite ≤ 60 días → el titular ES la alerta;
//     (2) desvío de ingreso MTD vs mes anterior a igual día ≥ ±10 % → el titular es la causa;
//     (3) sin nada crítico → estado + dato fuerte.
//   · Casos 1 y 2 nombran la propiedad causante. Compara solo dentro del año; nunca YoY.
import { eur, pct } from "./format";

export const UMBRAL_DIAS_LIMITE = 60;
export const UMBRAL_DESVIO_MTD = 0.10;
export const MAX_CHARS = 90;

export type AlertaHead = {
  codigo: string;
  tipo: string;
  clase: string; // 'alerta' (con fecha) | 'senal'
  dias_restantes: number | null;
};

export type MtdPropiedad = { codigo: string; actual: number; previo: number };

export type HeadlineInput = {
  alertas: AlertaHead[];
  /** pct_sobre_ingreso de v_costes_ytd (0,9447 → consume el 94,5 % de lo que ingresa) */
  costesPct: Record<string, number>;
  /** ingreso devengado del mes en curso (días completos) vs mes anterior a igual día */
  mtd: { mesActual: number; mesPrevio: number; porPropiedad: MtdPropiedad[] } | null;
  kpis: { margen_neto_ytd: number; margen_neto_pct_ytd: number };
  breakeven: { codigo: string; colchon: number | null }[];
};

const MES_LARGO = ["", "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const MES_CORTO = ["", "ene", "feb", "mar", "abr", "may", "jun",
  "jul", "ago", "sep", "oct", "nov", "dic"];

/** "4B_ALEX" → "ALEX" (nombre corto para el titular) */
export const nombreCorto = (codigo: string) => codigo.split("_").pop() ?? codigo;

const VERBO_POR_TIPO: Record<string, string> = { contrato: "avisar a" };

const dentroDeLimite = (frase: string, compacta: string) =>
  frase.length <= MAX_CHARS ? frase : compacta;

export function buildHeadline(i: HeadlineInput): string {
  // ── Caso 1: alerta con fecha límite ≤ 60 días ──────────────────────────────
  const conFecha = i.alertas
    .filter((a) => a.clase === "alerta" && a.dias_restantes != null
      && a.dias_restantes >= 0 && a.dias_restantes <= UMBRAL_DIAS_LIMITE)
    .sort((a, b) => (a.dias_restantes ?? 0) - (b.dias_restantes ?? 0));

  if (conFecha.length > 0) {
    const a = conFecha[0];
    const n = a.dias_restantes ?? 0;
    const prop = nombreCorto(a.codigo);
    const verbo = VERBO_POR_TIPO[a.tipo] ?? "decidir sobre";
    const dato = n === 0 ? `Hoy vence el plazo para ${verbo} ${prop}`
      : n === 1 ? `Queda 1 día para ${verbo} ${prop}`
      : `Quedan ${n} días para ${verbo} ${prop}`;
    const costes = i.costesPct[a.codigo];
    const colchon = i.breakeven.find((b) => b.codigo === a.codigo)?.colchon;
    const causa = costes != null
      ? `hoy consume el ${pct(costes)} de lo que ingresa`
      : colchon != null
        ? `opera a ${pp1(colchon)} pp de su punto de equilibrio`
        : `revisá su ficha antes de la fecha`;
    const compacta = costes != null
      ? `${dato} — consume el ${pct(costes)} del ingreso`
      : `${dato} — revisá su ficha`;
    return dentroDeLimite(`${dato} — ${causa}`, compacta);
  }

  // ── Caso 2: desvío de ingreso MTD ≥ ±10 % vs mes anterior a igual día ──────
  if (i.mtd && i.mtd.porPropiedad.length > 0) {
    const actual = i.mtd.porPropiedad.reduce((s, p) => s + p.actual, 0);
    const previo = i.mtd.porPropiedad.reduce((s, p) => s + p.previo, 0);
    if (previo > 0) {
      const desvio = (actual - previo) / previo;
      if (Math.abs(desvio) >= UMBRAL_DESVIO_MTD) {
        // la causante va en la MISMA dirección que el desvío: en una caída, la que más
        // resta; en una subida, la que más suma (nunca atribuir la caída a la que subió)
        const causante = [...i.mtd.porPropiedad].sort((a, b) =>
          desvio < 0
            ? (a.actual - a.previo) - (b.actual - b.previo)
            : (b.actual - b.previo) - (a.actual - a.previo))[0];
        const delta = causante.actual - causante.previo;
        const verbo = desvio < 0 ? "cae" : "sube";
        const verboProp = delta < 0 ? "resta" : "suma";
        const larga = `Ingreso de ${MES_LARGO[i.mtd.mesActual]} ${verbo} ${pct(Math.abs(desvio), 0)} ` +
          `vs ${MES_LARGO[i.mtd.mesPrevio]} a igual día — ${nombreCorto(causante.codigo)} ${verboProp} ${eur(Math.abs(delta))}`;
        const compacta = `Ingreso ${MES_CORTO[i.mtd.mesActual]} ${verbo} ${pct(Math.abs(desvio), 0)} ` +
          `vs ${MES_CORTO[i.mtd.mesPrevio]} — ${nombreCorto(causante.codigo)} ${verboProp} ${eur(Math.abs(delta))}`;
        return dentroDeLimite(larga, compacta);
      }
    }
  }

  // ── Caso 3: estado + dato fuerte ────────────────────────────────────────────
  const dato = `Margen neto ${eur(i.kpis.margen_neto_ytd)} (${pct(i.kpis.margen_neto_pct_ytd)})`;
  const negativas = i.breakeven
    .filter((b) => b.colchon != null && (b.colchon as number) < 0)
    .sort((a, b) => (a.colchon ?? 0) - (b.colchon ?? 0));
  if (negativas.length > 0) {
    const peor = negativas[0];
    return dentroDeLimite(
      `${dato} — ${nombreCorto(peor.codigo)} opera bajo su punto de equilibrio`,
      `${dato} — ${nombreCorto(peor.codigo)} bajo el equilibrio`,
    );
  }
  const n = i.breakeven.length;
  return dentroDeLimite(
    `${dato} — las ${n} propiedades cubren su punto de equilibrio`,
    `${dato} — las ${n} propiedades cubren el equilibrio`,
  );
}

/** colchón 0,056 → "5,6" (puntos porcentuales, sin unidad) */
const pp1 = (v: number) =>
  (v * 100).toLocaleString("es-ES", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
