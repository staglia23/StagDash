// Lectura de la foto de precios de PriceLabs (migración 072) — funciones puras testeables.
//
// Qué mide: PriceLabs calcula un precio recomendado para cada noche, pero los overrides
// manuales (los suelos que pone Stag) lo pisan. Cuando el suelo queda por DEBAJO de la
// recomendación en una noche que sigue LIBRE, eso es dinero que se está dejando ir: la
// noche se puede vender igual, solo que más barata de lo que el mercado admitiría.
//
// Nunca entra al P&L: es dato forward y operativo, no devengado (regla del CLAUDE.md).

export type OportunidadRow = {
  codigo: string; fecha: string; dias_hasta: number | string;
  publicado: number | string; recomendado: number | string; diferencia: number | string;
  min_stay: number | string | null; demanda: string | null; stly_reservado: boolean | null;
};

export type ResumenPrecioRow = {
  codigo: string;
  noches_baratas: number | string;
  euros_sobre_la_mesa: number | string;
  dias_primera: number | string | null;
  reservadas: number | string; bloqueadas: number | string;
  huerfanas: number | string; libres: number | string;
  ocupacion: number | string;
  adr_reservado: number | string | null;
  stly_ocupacion: number | string | null;
  stly_adr: number | string | null;
  refreshed_at: string | null;
};

export type TotalesPrecios = {
  noches: number;
  euros: number;
  bloqueadas: number;
  huerfanas: number;
  /** Días hasta la primera noche accionable; null si no hay ninguna. */
  diasPrimera: number | null;
};

export function totalesPrecios(rows: ResumenPrecioRow[]): TotalesPrecios {
  const suma = (sel: (r: ResumenPrecioRow) => number | string | null) =>
    rows.reduce((s, r) => s + Number(sel(r) ?? 0), 0);
  const dias = rows
    .map((r) => (r.dias_primera == null ? null : Number(r.dias_primera)))
    .filter((d): d is number => d != null);
  return {
    noches: suma((r) => r.noches_baratas),
    euros: suma((r) => r.euros_sobre_la_mesa),
    bloqueadas: suma((r) => r.bloqueadas),
    huerfanas: suma((r) => r.huerfanas),
    diasPrimera: dias.length ? Math.min(...dias) : null,
  };
}

/** Cuánto se aleja la ocupación de la del año pasado a la misma altura (en pp). null si
 *  no hay comparable — el piso no se gestionaba todavía (la 064 arregló ese falso 0 %). */
export function deltaStly(r: ResumenPrecioRow): number | null {
  if (r.stly_ocupacion == null) return null;
  return Number(r.ocupacion) - Number(r.stly_ocupacion);
}

/** El titular de la pantalla: la respuesta antes que los datos (doctrina CEO). */
export function titularPrecios(t: TotalesPrecios): string {
  if (t.noches === 0) {
    return "Ninguna noche libre está por debajo del precio recomendado.";
  }
  const cuando = t.diasPrimera == null ? ""
    : t.diasPrimera === 0 ? " — la primera es hoy"
    : t.diasPrimera === 1 ? " — la primera es mañana"
    : ` — la primera en ${t.diasPrimera} días`;
  return `${t.noches} ${t.noches === 1 ? "noche libre está" : "noches libres están"} por debajo del precio recomendado${cuando}`;
}
