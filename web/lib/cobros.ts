// Cobros: por dónde entra la plata. Alimenta /cobros desde la vista v_cobros (migración 087).
//
// OJO con la métrica: acá el importe es el del PAGO, no el ingreso Samavi. Son cosas distintas
// y no hay que mezclarlas — en Jacobine un cobro de 520 € deja 130 € a Samavi. Esta pantalla
// responde "¿por dónde entró el dinero?" (caja), no "¿cuánto ganamos?" (P&L). Por eso todo se
// etiqueta como **cobrado**.
//
// Las tres dimensiones (docs/operativa/COBROS.md):
//   canal   — de dónde vino la reserva          (dato duro: reservations.source)
//   familia — cómo entró la plata               (dato duro: guesty_payment_methods)
//   destino — dónde cayó, ¿aparece en el banco? (de la nota que escribe Stag)

export type CobroRow = {
  codigo: string;
  confirmation_code: string | null;
  checkin_local: string;
  estado_reserva: string | null;
  canal: string;
  importe: number;
  estado_pago: string | null;
  fecha_pago: string | null;
  metodo: string;
  familia: string;
  nota: string | null;
  destino: string | null;
  entra_en_banco_es: boolean | null;
};

export type Eje = "canal" | "familia" | "destino";

export type Grupo = {
  clave: string;
  total: number;
  n: number;
  pct: number;      // 0..1
  filas: CobroRow[];
};

// Orden fijo por entidad, nunca cíclico (doctrina de color del repo: color = entidad).
// "Sin clasificar" siempre va último: es la ausencia de dato, no una categoría más.
export const SIN_CLASIFICAR = "Sin clasificar";

export const ORDEN: Record<Eje, string[]> = {
  canal:   ["Airbnb", "Booking.com", "Directa"],
  familia: ["Pasarela Airbnb", "Efectivo", "Transferencia"],
  destino: ["Airbnb", "Efectivo", "Galicia USD", "Revolut", "BBVA"],
};

const FAMILIA_LABEL: Record<string, string> = {
  PASARELA: "Pasarela Airbnb",
  EFECTIVO: "Efectivo",
  TRANSFERENCIA: "Transferencia",
};

const DESTINO_LABEL: Record<string, string> = {
  AIRBNB: "Airbnb",
  EFECTIVO: "Efectivo",
  "GALICIA-USD": "Galicia USD",
  REVOLUT: "Revolut",
  BBVA: "BBVA",
};

/** Solo la plata que entró de verdad: pago cobrado y reserva viva. */
export const esCobroReal = (r: CobroRow) =>
  r.estado_pago === "SUCCEEDED" && r.estado_reserva !== "canceled";

export function clave(r: CobroRow, eje: Eje): string {
  if (eje === "canal") return r.canal || SIN_CLASIFICAR;
  if (eje === "familia") return FAMILIA_LABEL[r.familia] ?? SIN_CLASIFICAR;
  return r.destino ? (DESTINO_LABEL[r.destino] ?? r.destino) : SIN_CLASIFICAR;
}

export function agrupar(rows: CobroRow[], eje: Eje): Grupo[] {
  const cobros = rows.filter(esCobroReal);
  const total = cobros.reduce((a, r) => a + r.importe, 0);
  const m = new Map<string, Grupo>();
  for (const r of cobros) {
    const k = clave(r, eje);
    if (!m.has(k)) m.set(k, { clave: k, total: 0, n: 0, pct: 0, filas: [] });
    const g = m.get(k)!;
    g.total += r.importe;
    g.n += 1;
    g.filas.push(r);
  }
  for (const g of m.values()) g.pct = total > 0 ? g.total / total : 0;

  // Orden fijo primero; lo que no esté en la lista va detrás por importe; SIN_CLASIFICAR al final.
  const fijo = ORDEN[eje];
  return [...m.values()].sort((a, b) => {
    if (a.clave === SIN_CLASIFICAR) return 1;
    if (b.clave === SIN_CLASIFICAR) return -1;
    const ia = fijo.indexOf(a.clave), ib = fijo.indexOf(b.clave);
    if (ia >= 0 && ib >= 0) return ia - ib;
    if (ia >= 0) return -1;
    if (ib >= 0) return 1;
    return b.total - a.total;
  });
}

export type Resumen = {
  total: number;
  nCobros: number;
  /** Cobrado que NO va a aparecer en un extracto español → cuenta con el socio. */
  fueraDeBanco: number;
  /** Cobrado que no se puede clasificar porque le falta la nota. Es la lista de tareas. */
  sinNota: number;
  nSinNota: number;
  /** Cobros programados que todavía no ocurrieron. No son una forma de cobro. */
  previsto: number;
  nPrevisto: number;
};

export function resumen(rows: CobroRow[]): Resumen {
  const cobros = rows.filter(esCobroReal);
  const pendientes = rows.filter(
    (r) => r.estado_pago === "PENDING" && r.estado_reserva !== "canceled",
  );
  const sinNota = cobros.filter((r) => r.entra_en_banco_es === null);
  return {
    total: cobros.reduce((a, r) => a + r.importe, 0),
    nCobros: cobros.length,
    fueraDeBanco: cobros
      .filter((r) => r.entra_en_banco_es === false)
      .reduce((a, r) => a + r.importe, 0),
    sinNota: sinNota.reduce((a, r) => a + r.importe, 0),
    nSinNota: sinNota.length,
    previsto: pendientes.reduce((a, r) => a + r.importe, 0),
    nPrevisto: pendientes.length,
  };
}

/** Las que hay que ir a arreglar a Guesty, de mayor a menor. */
export function porSanear(rows: CobroRow[]): CobroRow[] {
  return rows
    .filter((r) => esCobroReal(r) && r.entra_en_banco_es === null)
    .sort((a, b) => b.importe - a.importe);
}
