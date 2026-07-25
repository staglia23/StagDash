// Observaciones de rentabilidad de la portada — PURAS y testeables.
//
// Desde la migración 025 el motor tiene tres capas y estas funciones miran la que decide:
// la CONTRIBUCIÓN (ingreso − costes directos). Es la que dice si vale la pena tener una
// propiedad, porque el overhead no desaparece cuando se va un piso: se reparte entre los
// demás. Compararlas por margen operativo mezclaría el rendimiento del piso con una regla
// de reparto que es igual para todos.
//
// Doctrina: son comparaciones, no vanity metrics. Cada una se emite SOLO si el cruce existe
// de verdad; si no, devuelven null y la portada no muestra nada.
import { eur, pct } from "./format";
import { nombreCorto } from "./headline";

export type RentRow = {
  codigo: string;
  ingreso_samavi: number;
  /** Ingreso − costes directos. La capa que decide quedarse o no con la propiedad. */
  contribucion: number;
  /** Contribución / ingreso: cuánto de cada euro que entra sobrevive a los costes del piso. */
  contribucion_pct: number;
  /** Contribución − overhead de gestión prorrateado. */
  margen_neto: number;
};

/** El margen del más eficiente tiene que ser comparable (≥80 %) al del que más aporta. */
const COMPARABLE = 0.8;

/**
 * "X aporta casi lo mismo que Y con mucho menos ingreso." Solo se emite cuando de verdad
 * hay una propiedad chica que rinde como la grande.
 */
export function cruceRentabilidad(rows: RentRow[]): string | null {
  if (rows.length < 2) return null;

  const porContribucion = [...rows].sort((a, b) => b.contribucion - a.contribucion);
  const top = porContribucion[0];
  if (top.contribucion <= 0) return null;

  const eficiente = [...rows]
    .filter((r) => r.codigo !== top.codigo)
    .sort((a, b) => b.contribucion_pct - a.contribucion_pct)[0];

  if (!eficiente) return null;
  if (eficiente.contribucion_pct <= top.contribucion_pct) return null;
  if (eficiente.ingreso_samavi >= top.ingreso_samavi) return null;
  if (eficiente.contribucion < top.contribucion * COMPARABLE) return null;

  const ratio = eficiente.ingreso_samavi / top.ingreso_samavi;
  const cuanto = ratio <= 0.55 ? "menos de la mitad del ingreso"
    : `${pct(1 - ratio, 0)} menos de ingreso`;

  return `${nombreCorto(eficiente.codigo)} aporta casi lo mismo que ${nombreCorto(top.codigo)} `
    + `(${eur(eficiente.contribucion)} vs ${eur(top.contribucion)}) con ${cuanto}: `
    + `${pct(eficiente.contribucion_pct, 0)} de contribución contra ${pct(top.contribucion_pct, 0)}.`;
}

/**
 * La horquilla de eficiencia: cuánto de cada euro sobrevive a los costes del piso, en la
 * mejor y en la peor. Es la comparación que más dice cuando ninguna propiedad chica rinde
 * como la grande — y la que señala dónde hay que renegociar.
 * Se calla si la horquilla es estrecha (<15 pp): ahí no hay nada que decidir.
 */
export function spreadContribucion(rows: RentRow[], minSpread = 0.15): string | null {
  if (rows.length < 2) return null;
  const orden = [...rows].sort((a, b) => b.contribucion_pct - a.contribucion_pct);
  const mejor = orden[0];
  const peor = orden[orden.length - 1];
  if (mejor.contribucion_pct - peor.contribucion_pct < minSpread) return null;

  return `De cada euro que entra, ${nombreCorto(mejor.codigo)} conserva `
    + `${pct(mejor.contribucion_pct, 0)} tras sus costes directos y ${nombreCorto(peor.codigo)} `
    + `solo ${pct(peor.contribucion_pct, 0)}. Esa distancia es la renta.`;
}
