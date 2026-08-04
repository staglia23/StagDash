// Resumen de la cuenta de la dueña (modelo comisión) — migración 066/067.
// Función pura: la ficha la usa dos veces (el acceso rápido de arriba y la sección),
// y sin esto el número se calcularía en dos sitios y podrían discrepar.
//
// Regla clave: el MES EN CURSO no entra al total. Lleva la refactura de limpieza
// completa (700 €) contra los pocos días de alquiler ya devengados, así que mostraría
// un neto negativo que no significa nada. El motor razona a mes completo (060).

export type FilaCuenta = {
  anio: number; mes: number;
  pasivo_alquiler: number | string;
  pasivo_cancelaciones: number | string;
  limpieza: number | string;
  descuentos: number | string;
  neto: number | string;
};

export type TotalesCuenta = {
  alquiler: number;
  cancelaciones: number;
  limpieza: number;      // negativo
  descuentos: number;    // negativo
  devengado: number;     // alquiler + cancelaciones (lo que le pertenece)
  neto: number;          // lo que queda a su favor
};

export type ResumenCuenta = TotalesCuenta & {
  cerrados: FilaCuenta[];
  enCurso: FilaCuenta | null;
  /** Un bloque por año, del más viejo al más nuevo. La cuenta es acumulativa: 2025 sigue
   *  vivo porque a la dueña no se le ha transferido nada todavía. */
  porAnio: (TotalesCuenta & { anio: number; meses: number })[];
};

/** "Hoy" en hora de Madrid: el negocio vive ahí y Stag viaja (mismo criterio que format.ts). */
export function hoyMadrid(): { anio: number; mes: number } {
  const [a, m] = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Madrid", year: "numeric", month: "2-digit",
  }).format(new Date()).split("-").map(Number);
  return { anio: a, mes: m };
}

export function resumenCuentaDuena(
  rows: FilaCuenta[],
  hoy: { anio: number; mes: number } = hoyMadrid(),
): ResumenCuenta {
  const enCurso = rows.find((r) => r.anio === hoy.anio && r.mes === hoy.mes) ?? null;
  const cerrados = rows.filter((r) => r !== enCurso);

  const totales = (filas: FilaCuenta[]): TotalesCuenta => {
    const suma = (sel: (r: FilaCuenta) => number | string) =>
      filas.reduce((s, r) => s + Number(sel(r)), 0);
    const alquiler = suma((r) => r.pasivo_alquiler);
    const cancelaciones = suma((r) => r.pasivo_cancelaciones);
    return {
      alquiler, cancelaciones,
      limpieza: suma((r) => r.limpieza),
      descuentos: suma((r) => r.descuentos),
      devengado: alquiler + cancelaciones,
      // el neto se suma de la columna del motor, no se recalcula: así el total de la
      // tarjeta y el de la tabla son el mismo número aunque el motor cambie una regla
      neto: suma((r) => r.neto),
    };
  };

  const anios = Array.from(new Set(cerrados.map((r) => r.anio))).sort((a, b) => a - b);

  return {
    cerrados, enCurso,
    ...totales(cerrados),
    porAnio: anios.map((anio) => {
      const filas = cerrados.filter((r) => r.anio === anio);
      return { anio, meses: filas.length, ...totales(filas) };
    }),
  };
}
