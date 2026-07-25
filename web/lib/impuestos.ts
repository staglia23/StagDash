// Del margen operativo a lo que de verdad queda — funciones PURAS y testeables.
//
// Contexto (Stag, 25/07/2026): el dashboard nunca provisionó impuestos, así que su "margen
// neto" es en realidad un margen OPERATIVO antes de impuestos. Esto lo hace explícito.
//
// Dos piezas distintas, que no hay que confundir:
//   · IVA repercutido de la comisión de Jacobine — NO es un impuesto sobre el beneficio: es
//     plata de Hacienda que pasa por la cuenta. Desde la migración 021 ya está FUERA del
//     margen, así que acá solo se muestra para que se entienda a dónde fue.
//   · Impuesto de Sociedades — sí grava el beneficio, y no está provisionado en ningún lado.
//
// ⚑ Por qué el IS es una ESTIMACIÓN y no un cálculo: Samavi viene compensando bases
//   imponibles negativas de ejercicios anteriores (el IS de 2025 no salió a pagar). Mientras
//   queden BINs por compensar, el pago real es menor que esta provisión, y puede ser cero.
//   Es un TECHO prudente, no una previsión de pago — etiquetarlo como tal es obligatorio.
//   El tipo real y las BINs disponibles los tiene Confisic; acá no se inventan.

/** Tipo acordado con Stag para la provisión estimada (25/07/2026). No es asesoramiento fiscal. */
export const TIPO_IS_ESTIMADO = 0.20;

export type Fiscal = {
  /** Margen operativo antes de impuestos: lo que hoy muestra la portada. */
  margenOperativo: number;
  /** Provisión estimada de IS (0 si no hay beneficio: sin base positiva no hay impuesto). */
  provisionIS: number;
  /** Margen operativo − provisión. Estimado y prudente (ignora BINs por compensar). */
  quedaEstimado: number;
  tipo: number;
};

export function calcularFiscal(margenOperativo: number, tipo = TIPO_IS_ESTIMADO): Fiscal {
  // Sin beneficio no hay impuesto sobre el beneficio. Provisionar sobre pérdidas sería
  // inventar un gasto que no existe.
  const provisionIS = margenOperativo > 0 ? margenOperativo * tipo : 0;
  return {
    margenOperativo,
    provisionIS,
    quedaEstimado: margenOperativo - provisionIS,
    tipo,
  };
}
