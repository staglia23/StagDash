// Fixtures = datos REALES de producción (v_margen_asegurado y v_breakeven_ytd, 25/07/2026,
// POST migraciones 021–025: Jacobine va neto de IVA repercutido, las rentas de
// ALEX/MARE cargan el IVA soportado como coste (hipótesis prudente), y la reimputación de
// eventos de Q1 movió los equilibrios. Si cambian las reglas del motor, actualizar acá y en
// las migraciones a la vez.
import { describe, expect, it } from "vitest";
import {
  construirTabla, estadoMes, resumenAsegurado, type AseguradoRow,
} from "../lib/asegurado";

const BREAKEVEN: Record<string, number | null> = {
  "1A_JACO": 0.6507,   // saltó del 38 % al 65 %: ahora carga su parte real del overhead
  "1A_NICA": 0.5480,
  "3G_MARE": 0.8267,
  "4B_ALEX": 0.8517,   // colchón otra vez POSITIVO (+6,3 pp) tras el reparto por días
};

const fila = (
  codigo: string, mes: number, margen_neto: number, ocup_vendida: number,
): AseguradoRow => ({
  codigo, anio: 2026, mes, margen_neto, ocup_vendida,
  ingreso_asegurado: 0, noches_vendidas: Math.round(ocup_vendida * 30),
});

// Julio → diciembre de las 4 propiedades, tal cual salen de la vista.
const ROWS: AseguradoRow[] = [
  fila("1A_JACO", 7, -45.86, 0.7742), fila("1A_JACO", 8, -264.65, 0.6129),
  fila("1A_JACO", 9, -219.58, 0.5000), fila("1A_JACO", 10, -120.21, 0.4839),
  fila("1A_JACO", 11, -959.58, 0.1000), fila("1A_JACO", 12, -1173.46, 0.0000),
  fila("1A_NICA", 7, 2033.94, 0.9677), fila("1A_NICA", 8, 1437.44, 0.7419),
  fila("1A_NICA", 9, 3787.93, 0.8333), fila("1A_NICA", 10, 2223.77, 0.5484),
  fila("1A_NICA", 11, 271.53, 0.4000), fila("1A_NICA", 12, -279.09, 0.2903),
  fila("3G_MARE", 7, 113.74, 0.8710), fila("3G_MARE", 8, -879.23, 0.4839),
  fila("3G_MARE", 9, 774.08, 0.7333), fila("3G_MARE", 10, 85.14, 0.5161),
  fila("3G_MARE", 11, -1908.59, 0.2000), fila("3G_MARE", 12, -2322.06, 0.0968),
  fila("4B_ALEX", 7, 180.23, 0.8387), fila("4B_ALEX", 8, -368.98, 0.7742),
  fila("4B_ALEX", 9, 1917.62, 0.9333), fila("4B_ALEX", 10, -550.45, 0.4839),
  fila("4B_ALEX", 11, -2011.61, 0.3667), fila("4B_ALEX", 12, -3021.66, 0.0645),
];

const ORDEN = ["1A_NICA", "1A_JACO", "3G_MARE", "4B_ALEX"];

describe("estadoMes — el umbral es el punto de equilibrio, no un target inventado", () => {
  it("margen positivo siempre es 'pos', aunque falte mucho por vender", () => {
    // NICA nov: solo 40 % vendido pero ya deja +272 € → verde, no gris
    expect(estadoMes({ margenNeto: 271.53, ocupVendida: 0.4000, ocupBreakeven: 0.5480 })).toBe("pos");
  });

  it("negativo por debajo del equilibrio = 'llenando' (el mes está a medio vender)", () => {
    // ALEX ago: −369 € con 77 % vendido y equilibrio en 85,2 % → todavía se está llenando
    expect(estadoMes({ margenNeto: -368.98, ocupVendida: 0.7742, ocupBreakeven: 0.8517 })).toBe("llenando");
  });

  it("negativo POR ENCIMA del equilibrio sí es alarma real ('neg')", () => {
    // Caso que hoy no ocurre pero es el que importa: vendiste más que tu equilibrio y perdés
    expect(estadoMes({ margenNeto: -300, ocupVendida: 0.98, ocupBreakeven: 0.8517 })).toBe("neg");
  });

  it("sin equilibrio conocido no inventa indulgencia: negativo es negativo", () => {
    expect(estadoMes({ margenNeto: -300, ocupVendida: 0.10, ocupBreakeven: null })).toBe("neg");
  });

  it("cero cuenta como cubierto (el equilibrio es exactamente cero)", () => {
    expect(estadoMes({ margenNeto: 0, ocupVendida: 0, ocupBreakeven: 0.5 })).toBe("pos");
  });
});

describe("construirTabla", () => {
  const t = construirTabla(ROWS, BREAKEVEN, ORDEN);

  it("arma los 6 meses de julio a diciembre, en orden", () => {
    expect(t.meses.map((m) => m.mes)).toEqual([7, 8, 9, 10, 11, 12]);
  });

  it("respeta el orden de filas que le pasan (el mismo de la tabla YTD)", () => {
    expect(t.filas.map((f) => f.codigo)).toEqual(ORDEN);
  });

  it("julio de JACOBINE: vendió por ENCIMA de su equilibrio y pierde igual → rojo real", () => {
    // 77,42 % vendido contra 65,07 % de equilibrio: superó el listón y aun así deja −46 €.
    // Es el hallazgo que destapó el reparto por días: con solo un 25 % de comisión, Jacobine
    // apenas cubre el coste de gestionarla. Único caso que la doctrina admite como alarma.
    const jaco = t.filas.find((f) => f.codigo === "1A_JACO")!;
    expect(jaco.celdas[0].margen).toBeLessThan(0);
    expect(jaco.celdas[0].estado).toBe("neg");
  });

  it("NICA: nov pasa a positivo y dic queda 'llenando'", () => {
    const nica = t.filas.find((f) => f.codigo === "1A_NICA")!;
    expect(nica.celdas[4].estado).toBe("pos");      // nov, +272 € tras el reparto por días
    expect(nica.celdas[5].estado).toBe("llenando"); // dic, −279 €
  });

  it("la fila de totales suma columnas", () => {
    const jul = t.totales[0];
    expect(jul.margen).toBeCloseTo(-45.86 + 2033.94 + 113.74 + 180.23, 2);
    expect(jul.estado).toBe("pos");
  });

  it("un mes con total negativo donde TODAS están llenando no se pinta en rojo", () => {
    const dic = t.totales[5];
    expect(dic.margen).toBeLessThan(0);
    expect(dic.estado).toBe("llenando");
  });

  it("el total de la fila es lo asegurado de esa propiedad hasta fin de año", () => {
    const jaco = t.filas.find((f) => f.codigo === "1A_JACO")!;
    expect(jaco.total).toBeCloseTo(-45.86 - 264.65 - 219.58 - 120.21 - 959.58 - 1173.46, 2);
  });

  it("el total general es la suma de los totales mensuales", () => {
    expect(t.total).toBeCloseTo(t.totales.reduce((s, c) => s + c.margen, 0), 2);
  });

  it("una propiedad sin filas en la vista no aparece aunque esté en el orden", () => {
    const t2 = construirTabla(ROWS, BREAKEVEN, [...ORDEN, "9Z_NUEVA"]);
    expect(t2.filas.map((f) => f.codigo)).toEqual(ORDEN);
  });

  it("un mes sin fila para una propiedad se rellena con 0 y no rompe la grilla", () => {
    const t3 = construirTabla(ROWS.filter((r) => !(r.codigo === "3G_MARE" && r.mes === 9)), BREAKEVEN, ORDEN);
    const mare = t3.filas.find((f) => f.codigo === "3G_MARE")!;
    expect(mare.celdas).toHaveLength(6);
    expect(mare.celdas[2].margen).toBe(0);
  });

  it("sin datos devuelve una tabla vacía en vez de reventar", () => {
    const vacia = construirTabla([], BREAKEVEN, ORDEN);
    expect(vacia.meses).toEqual([]);
    expect(vacia.filas).toEqual([]);
    expect(vacia.total).toBe(0);
  });
});

describe("resumenAsegurado", () => {
  it("cuenta los meses cubiertos y los que siguen llenándose", () => {
    const t = construirTabla(ROWS, BREAKEVEN, ORDEN);
    // jul, sep, oct en positivo; ago, nov, dic todavía llenando
    expect(resumenAsegurado(t)).toBe(
      "3 de 6 meses ya cubren sus costes con lo reservado · 3 todavía a medio vender.",
    );
  });

  it("no menciona categorías vacías", () => {
    const soloBuenos = construirTabla(
      ROWS.filter((r) => [7, 9].includes(r.mes)), BREAKEVEN, ORDEN,
    );
    expect(resumenAsegurado(soloBuenos)).toBe(
      "2 de 2 meses ya cubren sus costes con lo reservado.",
    );
  });
});
