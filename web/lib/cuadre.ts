// Lógica de presentación de /cuadre (la definición de los chequeos vive en SQL: v_cuadre).
// Funciones puras: el resumen del semáforo y la línea de números de cada chequeo.
import { eur, MESES, num } from "./format";

export type CuadreRow = {
  orden: number;
  chequeo: string;
  titulo: string;
  estado: "ok" | "alerta" | "info";
  esperado: number | null;
  obtenido: number | null;
  unidad: "eur" | "casos" | "horas" | "mes" | null;
  detalle: string;
};

export type ResumenCuadre = { total: number; alertas: number; texto: string };

/** Supabase devuelve los numeric como string → a números una sola vez, en el borde. */
export function normalizaCuadre(rows: Array<Record<string, unknown>>): CuadreRow[] {
  return rows.map((r) => ({
    ...(r as CuadreRow),
    orden: Number(r.orden),
    esperado: r.esperado == null ? null : Number(r.esperado),
    obtenido: r.obtenido == null ? null : Number(r.obtenido),
  }));
}

/** Resumen para el semáforo: los 'info' no cuentan como chequeo pasa/falla. */
export function resumenCuadre(rows: CuadreRow[]): ResumenCuadre {
  const checks = rows.filter((r) => r.estado !== "info");
  const alertas = checks.filter((r) => r.estado === "alerta").length;
  return {
    total: checks.length,
    alertas,
    texto: alertas === 0
      ? `✓ ${checks.length} de ${checks.length} chequeos cuadran`
      : `⚠ ${alertas} de ${checks.length} chequeos no cuadran`,
  };
}

/** Versión corta para el stamp de la portada: "cuadre ✓ 8/8" | "cuadre ⚠ 2". */
export function stampCuadre(rows: CuadreRow[]): string | null {
  if (rows.length === 0) return null;
  const { total, alertas } = resumenCuadre(rows);
  return alertas === 0 ? `cuadre ✓ ${total}/${total}` : `cuadre ⚠ ${alertas}`;
}

/** La línea de números de un chequeo, legible para el CEO (es-ES, sin jerga). */
export function lineaCuadre(r: CuadreRow): string {
  const { esperado, obtenido } = r;
  switch (r.unidad) {
    case "eur": {
      if (esperado == null || obtenido == null) return "sin datos";
      const dif = obtenido - esperado;
      if (r.estado === "ok") {
        return Math.abs(dif) < 0.005
          ? `los dos caminos dan ${eur(obtenido, 2)}`
          : `${eur(obtenido, 2)} · dif ${eur(dif, 2)} (redondeo, dentro de tolerancia)`;
      }
      return `debería dar ${eur(esperado, 2)} y da ${eur(obtenido, 2)} · dif ${eur(dif, 2)}`;
    }
    case "casos":
      return obtenido === 0 ? "0 casos" : `${num(obtenido)} caso(s) — revisar`;
    case "horas":
      return obtenido == null
        ? "sin datos de sync"
        : `hace ${num(obtenido, 1)} h (límite ${num(esperado ?? 6)} h)`;
    case "mes":
      return obtenido == null ? "sin meses conciliados" : `hasta ${MESES[obtenido]}`;
    default:
      return "";
  }
}
