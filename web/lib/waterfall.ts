// Pasos del waterfall de margen (02_Prompt §5.3). PURO: recibe filas de v_ranking_ytd +
// v_costes_ytd y devuelve la secuencia bruto → −comisión aparente → ingreso Samavi →
// −costes directos por línea → margen directo → −overhead → margen neto.
// Para el modelo comisión (JACO) el primer escalón NO es la comisión de canal: su ingreso
// es el 30,25 % del bruto y la diferencia incluye el Pasivo Madre → se etiqueta aparte.
import type { Modelo } from "./simulador";

export type PasoWaterfall = {
  key: string;
  label: string;
  desde: number;   // valor acumulado antes del paso
  hasta: number;   // valor acumulado después del paso
  tipo: "entrada" | "salida" | "total";
};

export type WaterfallInput = {
  modelo: Modelo;
  bruto: number;
  ingreso_samavi: number;
  /** cobros retenidos de canceladas (009): entrada aparte — no salen del bruto por noche */
  ingreso_cancelaciones?: number;
  // costes en positivo (v_costes_ytd)
  renta: number;
  limpieza: number;
  suministros: number;
  comunidad: number;
  otros: number;
  overhead: number;
  margen_directo: number;
  margen_neto: number;
};

export function pasosWaterfall(d: WaterfallInput): PasoWaterfall[] {
  const pasos: PasoWaterfall[] = [];
  let acum = 0;

  const total = (key: string, label: string, valor: number) =>
    pasos.push({ key, label, desde: 0, hasta: valor, tipo: "total" });
  const salida = (key: string, label: string, importe: number) => {
    if (importe === 0) return;
    pasos.push({ key, label, desde: acum, hasta: acum - importe, tipo: "salida" });
    acum -= importe;
  };
  const entrada = (key: string, label: string, importe: number) => {
    if (importe === 0) return;
    pasos.push({ key, label, desde: acum, hasta: acum + importe, tipo: "entrada" });
    acum += importe;
  };

  const canceladas = d.ingreso_cancelaciones ?? 0;
  total("bruto", "Bruto", d.bruto);
  acum = d.bruto;
  salida(
    "comision",
    d.modelo === "comision" ? "Comisión + Pasivo Madre" : "Comisión de canal",
    d.bruto - (d.ingreso_samavi - canceladas),
  );
  entrada("cancelaciones", "Cobros de canceladas", canceladas);
  total("ingreso", "Ingreso Samavi", d.ingreso_samavi);
  acum = d.ingreso_samavi;
  salida("renta", "Renta", d.renta);
  salida("limpieza", "Limpieza", d.limpieza);
  salida("suministros", "Suministros", d.suministros);
  salida("comunidad", "Comunidad", d.comunidad);
  salida("otros", "Otros", d.otros);
  total("directo", "Margen directo", d.margen_directo);
  acum = d.margen_directo;
  salida("overhead", "Overhead", d.overhead);
  total("neto", "Margen neto", d.margen_neto);
  return pasos;
}
