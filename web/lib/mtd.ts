// Comparación de ingreso MTD (mes en curso vs mes anterior a igual día) para el caso 2
// del titular. Función PURA sobre filas de v_reservation_nights. El margen no es computable
// a grano diario (los costes son mensuales y manuales) → se compara INGRESO devengado.
// Solo días completos: mes actual días 1..ayer vs mes anterior días 1..(mismo día − 1).
// En enero no hay mes anterior dentro del año → null (nunca se compara entre años).
import type { MtdPropiedad } from "./headline";

export type NocheRow = { codigo: string; night: string; ingreso_samavi_night: number };

export type MtdResultado = {
  mesActual: number;
  mesPrevio: number;
  porPropiedad: MtdPropiedad[];
} | null;

const iso = (anio: number, mes: number, dia: number) =>
  `${anio}-${String(mes).padStart(2, "0")}-${String(dia).padStart(2, "0")}`;

/** hoyIso = "2026-07-15" (fecha local del servidor, sin hora) */
export function mtdPorPropiedad(rows: NocheRow[], hoyIso: string): MtdResultado {
  const [anio, mes, dia] = hoyIso.split("-").map(Number);
  if (mes === 1 || dia <= 1) return null; // sin mes anterior en el año, o sin días completos

  const inicioActual = iso(anio, mes, 1);
  const inicioPrevio = iso(anio, mes - 1, 1);
  const finPrevio = iso(anio, mes - 1, dia); // exclusivo → días 1..(dia−1) del mes anterior

  const mapa = new Map<string, { actual: number; previo: number }>();
  for (const r of rows) {
    const e = mapa.get(r.codigo) ?? { actual: 0, previo: 0 };
    if (r.night >= inicioActual && r.night < hoyIso) e.actual += Number(r.ingreso_samavi_night);
    else if (r.night >= inicioPrevio && r.night < finPrevio) e.previo += Number(r.ingreso_samavi_night);
    mapa.set(r.codigo, e);
  }
  const porPropiedad = Array.from(mapa, ([codigo, v]) => ({ codigo, ...v }));
  if (porPropiedad.length === 0) return null;
  return { mesActual: mes, mesPrevio: mes - 1, porPropiedad };
}
