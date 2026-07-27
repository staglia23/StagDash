// Motor del simulador de escenarios — PURO y client-safe: cero red, cero escrituras.
// (02_Prompt_Dashboard_CEO §5.4)
//
// Convención de anualización: año calendario 2026 extrapolando el run-rate YTD.
//   · Magnitudes por noche (ingreso, bruto, limpieza) escalan por 365/noches_disponibles_ytd.
//   · Costes fijos mensuales (renta, suministros, comunidad, otros) escalan por 12/meses.
//   · Overhead anual = overhead YTD total × 12/meses, repartido por DÍAS bajo gestión,
//     la MISMA regla que el motor (decisión Stag 27/07/2026; antes iba por peso en el
//     ingreso simulado y el baseline no cuadraba con la ficha). Cada piso conserva su
//     parte YTD del pool (hoy, un cuarto cada uno): las palancas no mueven la cuota.
// Con las palancas en su valor base, la proyección coincide con el run-rate real YTD
// también en margen NETO, no solo en directo.
import { eur, pp } from "./format";
import { nombreCorto } from "./headline";

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
  /** Modelo comisión (JACO): ingreso = % del bruto. NETO de IVA (0,25), no el 30,25 %
   *  facturado — esos 5,25 puntos son IVA repercutido y nunca fueron ingreso (migración 021). */
  comisionModeloPct: number;
  /** Comisión de canal que SOPORTA Samavi, YTD (migración 033). Es la que desaparece al vender
   *  por directo. Distinta de la "aparente" de las palancas: esa incluye además los residuos
   *  (fees de mascota, reembolsos, Booking que no descuenta) y es la que hace cuadrar el
   *  baseline con el YTD real. En modelo comisión es 0: la paga la dueña, no Samavi. */
  comisionCanalYtd: number;
};

export type Palancas = {
  rentaMes: number;          // €/mes — solo subarriendo
  adr: number;               // € por noche vendida (sobre bruto)
  ocup: number;              // 0..1
  comisionCanalPct: number;  // 0..1, comisión aparente — no aplica a modelo comisión
  /** 0..1 — porción de las noches que se PASA a canal directo respecto de hoy. Base 0: el mix
   *  actual ya está dentro de comisionCanalPct, así que esta palanca es un delta, no un nivel. */
  directoPct: number;
};

/** Baseline de las palancas: derivado del YTD real, nunca valores inventados. */
export function palancasBase(b: PropBaseline): Palancas {
  return {
    rentaMes: b.meses > 0 ? b.rentaYtd / b.meses : 0,
    adr: b.nochesYtd > 0 ? b.brutoYtd / b.nochesYtd : 0,
    ocup: b.disponiblesYtd > 0 ? b.nochesYtd / b.disponiblesYtd : 0,
    comisionCanalPct: b.modelo === "comision" ? 0
      : b.brutoYtd > 0 ? 1 - b.ingresoYtd / b.brutoYtd : 0,
    directoPct: 0,
  };
}

/** Comisión de canal real, como fracción del bruto. Es lo que se recupera por noche directa. */
export function comisionRealPct(b: PropBaseline): number {
  if (b.modelo === "comision" || b.brutoYtd <= 0) return 0;
  return b.comisionCanalYtd / b.brutoYtd;
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
    /** Lo que aporta al año pasar `directoPct` de las noches a canal directo. 0 si no se movió
     *  la palanca, y 0 SIEMPRE en modelo comisión: ahí la comisión del canal la paga la dueña,
     *  así que vender por directo no le cambia nada a Samavi. */
    ahorroDirectoAnual: number;
    /** Punto de equilibrio de la captación: lo máximo que puede costar traer una noche directa
     *  antes de que salga igual que pagarle al canal. */
    costeMaxDirectoNoche: number;
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
  // Vender por directo no sube el precio: ahorra la comisión del canal, y nada más. Por eso el
  // ahorro por noche directa ES el coste del canal por noche — que es también, exactamente, lo
  // máximo que se puede gastar en captarla antes de que deje de convenir. Umbral derivado, no
  // inventado (doctrina: el único umbral objetivo es el punto de equilibrio).
  const ahorroNocheDirecta = p.adr * comisionRealPct(b);
  const ingresoNoche = (b.modelo === "comision"
    ? p.adr * b.comisionModeloPct
    : p.adr * (1 - p.comisionCanalPct)) + p.directoPct * ahorroNocheDirecta;
  const ingreso = ingresoNoche * noches;
  const limpiezaNoche = b.nochesYtd > 0 ? b.limpiezaYtd / b.nochesYtd : 0;
  const renta = b.modelo === "subarriendo" ? p.rentaMes * 12 : b.rentaYtd * fMeses(b);
  const fijosMensuales = (b.suministrosYtd + b.comunidadYtd + b.otrosYtd) * fMeses(b);
  const limpieza = limpiezaNoche * noches;
  const margenDirecto = ingreso - renta - limpieza - fijosMensuales;
  const contribNoche = ingresoNoche - limpiezaNoche;
  return {
    noches, bruto, ingreso, margenDirecto, renta, fijosMensuales, contribNoche,
    ahorroDirectoAnual: p.directoPct * ahorroNocheDirecta * noches,
    costeMaxDirectoNoche: ahorroNocheDirecta,
  };
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

  // ingreso anual de las 4 con la simulada reemplazada (solo display: la cuota no depende de él)
  const ingresos = baselines.map((b) =>
    b.codigo === codigo ? sim.ingreso : anualRunRate(b).ingreso);

  // Cuota por DÍAS bajo gestión, igual que v_pnl_neto_propiedad: cada piso conserva su
  // parte YTD del pool (con los 4 activos todo el año, un cuarto cada uno). Las palancas
  // NO mueven la cuota de nadie.
  const totalOverheadYtd = baselines.reduce((s, b) => s + b.overheadYtd, 0);

  const props: SimProp[] = baselines.map((b, idx) => {
    const directo = b.codigo === codigo ? sim.margenDirecto : anualRunRate(b).margenDirecto;
    const parte = totalOverheadYtd > 0 ? b.overheadYtd / totalOverheadYtd : 1 / baselines.length;
    const cuota = overheadAnual * parte;
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
      ahorroDirectoAnual: sim.ahorroDirectoAnual,
      costeMaxDirectoNoche: sim.costeMaxDirectoNoche,
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
  const prop = nombreCorto(b.codigo);
  const palancas = b.modelo === "subarriendo"
    ? `Con renta ${eur(p.rentaMes)}/mes y ADR ${eur(p.adr)}`
    : `Con ADR ${eur(p.adr)} y ocupación ${Math.round(p.ocup * 100)} %`;
  const margen = conOverhead ? r.target.margenNetoAnual : r.target.margenDirectoAnual;
  const verbo = margen >= 0 ? "deja" : "pierde";
  const tipoMargen = conOverhead ? "margen neto" : "margen directo (sin overhead)";
  const colchon = r.target.colchon != null ? ` (colchón ${pp(r.target.colchon)})` : "";
  return `${palancas}, ${prop} ${verbo} ${eur(Math.abs(margen))}/año de ${tipoMargen}${colchon}`;
}

/** La palanca de directo lleva SIEMPRE su condición: el ahorro solo es real si captar la noche
 *  cuesta menos que la comisión que se evita. Sin esa frase, el simulador diría "pasá todo a
 *  directo y ganás 32.000 €", que es falso — el canal directo no es gratis, solo es otro coste.
 *  Devuelve null si la palanca está en 0 (nada que decir). */
export function fraseDirecto(b: PropBaseline, p: Palancas, r: SimResultado): string | null {
  if (p.directoPct <= 0) return null;
  const prop = nombreCorto(b.codigo);
  if (b.modelo === "comision") {
    return `En ${prop} el directo no le cambia nada a Samavi: la comisión del canal la paga la dueña.`;
  }
  const pct = Math.round(p.directoPct * 100);
  return `Pasar ${pct} % de las noches a directo suma ${eur(r.target.ahorroDirectoAnual)}/año, `
    + `siempre que captar cada una cueste menos de ${eur(r.target.costeMaxDirectoNoche)}.`;
}
