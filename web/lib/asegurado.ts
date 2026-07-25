// Margen neto ASEGURADO por mes (portada híbrida) — funciones PURAS y testeables.
//
// Qué es: con lo ya reservado hoy, qué margen deja cada propiedad cada mes hasta diciembre.
// Es un piso que sube con cada reserva que entra, NO un pronóstico.
//
// El problema de lectura que resuelve este archivo: un mes lejano SIEMPRE da negativo, porque
// el coste ya está completo (renta, suministros, overhead) y el ingreso es solo lo vendido
// hasta hoy. Pintarlo en rojo sería mentir: no es un problema del negocio, es que el mes
// todavía no se vendió. Pero tampoco se puede esconder.
//
// El criterio para separar una cosa de la otra es el ÚNICO umbral objetivo que admite la
// doctrina (§ prompt CEO): el punto de equilibrio.
//   · Ya vendiste por encima de tu ocupación de equilibrio y aun así perdés → rojo, es real.
//   · Todavía no llegaste a esa ocupación → "llenando": el mes está a medio vender.
// Nunca por color solo: "llenando" se marca además con "…" y su leyenda (regla de contraste
// y de accesibilidad del prompt CEO).
//
// Caveat honesto: ocupBreakeven viene de v_breakeven_ytd, que es economía ANUAL. Un mes de
// temporada baja tiene un equilibrio real más alto que ese promedio. Es el mismo umbral que
// ya usa el panel de salud de la portada, así que al menos el dashboard es coherente consigo
// mismo; afinarlo por mes exigiría estacionalidad de costes que hoy no modelamos.

export type EstadoMes = "pos" | "neg" | "llenando";

export type AseguradoRow = {
  codigo: string;
  anio: number;
  mes: number;
  margen_neto: number;
  ingreso_asegurado: number;
  ocup_vendida: number;
  noches_vendidas: number;
};

export function estadoMes(x: {
  margenNeto: number;
  ocupVendida: number;
  ocupBreakeven: number | null;
}): EstadoMes {
  if (x.margenNeto >= 0) return "pos";
  if (x.ocupBreakeven != null && x.ocupVendida < x.ocupBreakeven) return "llenando";
  return "neg";
}

export type Celda = {
  anio: number;
  mes: number;
  margen: number;
  estado: EstadoMes;
  ocupVendida: number;
};

export type FilaAsegurado = {
  codigo: string;
  celdas: Celda[];
  /** Suma del margen asegurado de la fila — lo que la propiedad tiene garantizado de aquí a fin de año. */
  total: number;
};

export type TablaAsegurado = {
  meses: { anio: number; mes: number }[];
  filas: FilaAsegurado[];
  totales: Celda[];
  /** Margen asegurado de todo el portfolio hasta diciembre. */
  total: number;
};

/**
 * Arma la tabla propiedad × mes. El orden de las filas lo decide `orden` (mismo criterio
 * que la tabla YTD de abajo, para que las dos se lean juntas).
 */
export function construirTabla(
  rows: AseguradoRow[],
  breakeven: Record<string, number | null>,
  orden: string[],
): TablaAsegurado {
  const meses = [...new Map(rows.map((r) => [`${r.anio}-${r.mes}`, { anio: r.anio, mes: r.mes }])).values()]
    .sort((a, b) => a.anio - b.anio || a.mes - b.mes);

  const codigos = orden.filter((c) => rows.some((r) => r.codigo === c));

  const filas = codigos.map((codigo) => {
    const celdas = meses.map(({ anio, mes }) => {
      const r = rows.find((x) => x.codigo === codigo && x.anio === anio && x.mes === mes);
      const margen = r ? Number(r.margen_neto) : 0;
      const ocupVendida = r ? Number(r.ocup_vendida) : 0;
      return {
        anio, mes, margen, ocupVendida,
        estado: estadoMes({ margenNeto: margen, ocupVendida, ocupBreakeven: breakeven[codigo] ?? null }),
      };
    });
    return { codigo, celdas, total: celdas.reduce((s, c) => s + c.margen, 0) };
  });

  // La fila de totales suma columnas. Su estado no se hereda por mayoría: el mes del portfolio
  // solo se pinta en rojo si ALGUNA propiedad tiene una alarma real (vendió por encima de su
  // equilibrio y aun así pierde). Si todo lo negativo del mes viene de propiedades que todavía
  // se están llenando, el total también se está llenando — decir "rojo" ahí sería alarmismo.
  const totales: Celda[] = meses.map(({ anio, mes }, i) => {
    const col = filas.map((f) => f.celdas[i]);
    const margen = col.reduce((s, c) => s + c.margen, 0);
    const ocupVendida = col.length ? col.reduce((s, c) => s + c.ocupVendida, 0) / col.length : 0;
    const estado: EstadoMes = margen >= 0 ? "pos"
      : col.some((c) => c.estado === "neg") ? "neg"
      : "llenando";
    return { anio, mes, margen, estado, ocupVendida };
  });

  return { meses, filas, totales, total: totales.reduce((s, c) => s + c.margen, 0) };
}

/**
 * Frase de contexto bajo la tabla: cuántos meses ya están en positivo con lo vendido y
 * cuáles siguen llenándose. Sin adjetivos: solo el conteo y su consecuencia.
 */
export function resumenAsegurado(t: TablaAsegurado): string {
  const enPositivo = t.totales.filter((c) => c.estado === "pos").length;
  const llenando = t.totales.filter((c) => c.estado === "llenando").length;
  const enRojo = t.totales.filter((c) => c.estado === "neg").length;

  const partes = [
    `${enPositivo} de ${t.totales.length} meses ya cubren sus costes con lo reservado`,
  ];
  if (llenando > 0) partes.push(`${llenando} todavía a medio vender`);
  if (enRojo > 0) partes.push(`${enRojo} en negativo con la ocupación ya superada`);
  return partes.join(" · ") + ".";
}
