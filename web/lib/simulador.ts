// Motor del simulador de escenarios — PURO y client-safe: cero red, cero escrituras.
// (02_Prompt_Dashboard_CEO §5.4)
//
// Convención de anualización: año calendario 2026 extrapolando el run-rate YTD.
//   · Magnitudes por noche (ingreso, bruto, limpieza) escalan por 365/noches_disponibles_ytd.
//   · Costes fijos mensuales (renta, suministros, comunidad, otros) escalan por 12/meses.
//   · Overhead anual = overhead YTD total × 12/meses, prorrateado por peso en el Ingreso
//     Samavi SIMULADO de las 4 → los pesos se recalculan y el efecto colateral sobre las
//     otras 3 se muestra, no se oculta.
// Con las palancas en su valor base, la proyección coincide con el run-rate real YTD.
import { eur, pp } from "./format";

export const DIAS_ANIO = 365; // 2026 no es bisiesto

export type Modelo = "titular" | "subarriendo" | "comision";

export type PropBaseline = {
  codigo: string;
  modelo: Modelo;
  meses: number;             // meses transcurridos del año con actividad (spine)
  ingresoYtd: number;
  brutoYtd: number;
  nochesYtd: number;
  disponiblesYtd: number;
  // costes YTD en positivo (= cuánto cuesta, como v_costes_ytd)
  rentaYtd: number;
  limpiezaYtd: number;
  suministrosYtd: number;
  comunidadYtd: number;
  otrosYtd: number;
  overheadYtd: number;       // cuota de overhead prorrateada YTD
  rentaBaseMes: number;      // renta contractual vigente (v_propiedades) — referencia en UI
  comisionModeloPct: number; // modelo comisión (JACO): ingreso = % del bruto
};

export type Palancas = {
  rentaMes: number;          // €/mes — solo subarriendo
  adr: number;               // € por noche vendida (sobre bruto)
  ocup: number;              // 0..1
  comisionCanalPct: number;  // 0..1, comisión aparente — no aplica a modelo comisión
};

/** Baseline de las palancas: derivado del YTD real, nunca valores inventados. */
export function palancasBase(b: PropBaseline): Palancas {
  return {
    rentaMes: b.meses > 0 ? b.rentaYtd / b.meses : 0,
    adr: b.nochesYtd > 0 ? b.brutoYtd / b.nochesYtd : 0,
    ocup: b.disponiblesYtd > 0 ? b.nochesYtd / b.disponiblesYtd : 0,
    comisionCanalPct: b.modelo === "comision" ? 0
      : b.brutoYtd > 0 ? 1 - b.ingresoYtd / b.brutoYtd : 0,
  };
}

export type SimProp = {
  codigo: string;
  ingresoAnual: number;
  margenDirectoAnual: number;
  cuotaOverheadAnual: number;
  margenNetoAnual: number;
};

export type SimResultado = {
  props: SimProp[];          // las 4 (la simulada incluida), mismo orden que baselines
  target: SimProp & {
    brutoAnual: number;
    nochesAnual: number;
    ocup: number;
    ocupNecesaria: number | null; // según margen elegido (con/sin overhead); puede superar 1
    colchon: number | null;
  };
  overheadAnual: number;
};

const fNoches = (b: PropBaseline) => (b.disponiblesYtd > 0 ? DIAS_ANIO / b.disponiblesYtd : 0);
const fMeses = (b: PropBaseline) => (b.meses > 0 ? 12 / b.meses : 0);

/** Run-rate anual 2026 de una propiedad SIN tocar palancas (las otras 3 del prorrateo). */
function anualRunRate(b: PropBaseline) {
  const ingreso = b.ingresoYtd * fNoches(b);
  const costes = b.limpiezaYtd * fNoches(b)
    + (b.rentaYtd + b.suministrosYtd + b.comunidadYtd + b.otrosYtd) * fMeses(b);
  return { ingreso, margenDirecto: ingreso - costes };
}

/** Proyección anual de la propiedad simulada según las palancas. */
function anualSimulada(b: PropBaseline, p: Palancas) {
  const noches = p.ocup * DIAS_ANIO;
  const bruto = p.adr * noches;
  const ingresoNoche = b.modelo === "comision"
    ? p.adr * b.comisionModeloPct
    : p.adr * (1 - p.comisionCanalPct);
  const ingreso = ingresoNoche * noches;
  const limpiezaNoche = b.nochesYtd > 0 ? b.limpiezaYtd / b.nochesYtd : 0;
  const renta = b.modelo === "subarriendo" ? p.rentaMes * 12 : b.rentaYtd * fMeses(b);
  const fijosMensuales = (b.suministrosYtd + b.comunidadYtd + b.otrosYtd) * fMeses(b);
  const limpieza = limpiezaNoche * noches;
  const margenDirecto = ingreso - renta - limpieza - fijosMensuales;
  const contribNoche = ingresoNoche - limpiezaNoche;
  return { noches, bruto, ingreso, margenDirecto, renta, fijosMensuales, contribNoche };
}

export function simular(
  baselines: PropBaseline[],
  codigo: string,
  p: Palancas,
  opts: { conOverhead?: boolean } = {},
): SimResultado {
  const conOverhead = opts.conOverhead ?? true;
  const target = baselines.find((b) => b.codigo === codigo);
  if (!target) throw new Error(`Propiedad desconocida: ${codigo}`);

  const sim = anualSimulada(target, p);
  // El overhead es un pool de empresa: se anualiza por los meses transcurridos del AÑO
  // (max entre propiedades), no por los meses de cada propiedad — una alta a mitad de año
  // tiene menos meses de cuota YTD, pero el pool mensual de la empresa es el mismo.
  const mesesAnio = Math.max(...baselines.map((b) => b.meses), 1);
  const overheadAnual = baselines.reduce((s, b) => s + b.overheadYtd, 0) * (12 / mesesAnio);

  // ingreso anual de las 4 con la simulada reemplazada → pesos del prorrateo recalculados
  const ingresos = baselines.map((b) =>
    b.codigo === codigo ? sim.ingreso : anualRunRate(b).ingreso);
  const totalIngreso = ingresos.reduce((s, v) => s + v, 0);

  const props: SimProp[] = baselines.map((b, idx) => {
    const directo = b.codigo === codigo ? sim.margenDirecto : anualRunRate(b).margenDirecto;
    const peso = totalIngreso > 0 ? ingresos[idx] / totalIngreso : 0;
    const cuota = overheadAnual * peso;
    return {
      codigo: b.codigo,
      ingresoAnual: ingresos[idx],
      margenDirectoAnual: directo,
      cuotaOverheadAnual: cuota,
      margenNetoAnual: directo - cuota,
    };
  });

  const t = props.find((x) => x.codigo === codigo)!;
  const fijos = sim.renta + sim.fijosMensuales + (conOverhead ? t.cuotaOverheadAnual : 0);
  const nochesNecesarias = sim.contribNoche > 0 ? fijos / sim.contribNoche : null;
  const ocupNecesaria = nochesNecesarias != null ? nochesNecesarias / DIAS_ANIO : null;

  return {
    props,
    target: {
      ...t,
      brutoAnual: sim.bruto,
      nochesAnual: sim.noches,
      ocup: p.ocup,
      ocupNecesaria,
      colchon: ocupNecesaria != null ? p.ocup - ocupNecesaria : null,
    },
    overheadAnual,
  };
}

/** La respuesta es UNA frase, con la gramática del titular. Todo sale del cálculo. */
export function fraseSimulada(
  b: PropBaseline,
  p: Palancas,
  r: SimResultado,
  conOverhead: boolean,
): string {
  const prop = b.codigo.split("_").pop() ?? b.codigo;
  const palancas = b.modelo === "subarriendo"
    ? `Con renta ${eur(p.rentaMes)}/mes y ADR ${eur(p.adr)}`
    : `Con ADR ${eur(p.adr)} y ocupación ${Math.round(p.ocup * 100)} %`;
  const margen = conOverhead ? r.target.margenNetoAnual : r.target.margenDirectoAnual;
  const verbo = margen >= 0 ? "deja" : "pierde";
  const tipoMargen = conOverhead ? "margen neto" : "margen directo (sin overhead)";
  const colchon = r.target.colchon != null ? ` (colchón ${pp(r.target.colchon)})` : "";
  return `${palancas}, ${prop} ${verbo} ${eur(Math.abs(margen))}/año de ${tipoMargen}${colchon}`;
}
