// Fixtures = datos REALES de producción (v_margen_asegurado y v_breakeven_ytd, 25/07/2026,
// POST migraciones 021–029: Jacobine va neto de IVA repercutido, las rentas de
// ALEX/MARE cargan el IVA soportado como coste (hipótesis prudente), y la reimputación de
// eventos de Q1 movió los equilibrios. Si cambian las reglas del motor, actualizar acá y en
// las migraciones a la vez.
import { describe, expect, it } from "vitest";
import {
  construirTabla, estadoMes, resumenAsegurado, type AseguradoRow,
} from "../lib/asegurado";

const BREAKEVEN: Record<string, number | null> = {
  "1A_JACO": 0.5984,   // saltó del 38 % al 61 %: ahora carga su parte real del overhead
  "1A_NICA": 0.5254,
  "3G_MARE": 0.8141,
  "4B_ALEX": 0.8275,   // colchón POSITIVO (+8,1 pp) tras el reparto por días
};

const fila = (
  codigo: string, mes: number, margen_neto: number, ocup_vendida: number,
): AseguradoRow => ({
  codigo, anio: 2026, mes, margen_neto, ocup_vendida,
  ingreso_asegurado: 0, noches_vendidas: Math.round(ocup_vendida * 30),
});

// Julio → diciembre de las 4 propiedades, tal cual salen de la vista.
const ROWS: AseguradoRow[] = [
  fila("1A_JACO", 7, -31.33, 0.7742), fila("1A_JACO", 8, -250.11, 0.6129),
  fila("1A_JACO", 9, -205.05, 0.5000), fila("1A_JACO", 10, -105.67, 0.4839),
  fila("1A_JACO", 11, -945.05, 0.1000), fila("1A_JACO", 12, -1158.93, 0.0000),
  fila("1A_NICA", 7, 2048.47, 0.9677), fila("1A_NICA", 8, 1451.98, 0.7419),
  fila("1A_NICA", 9, 3802.46, 0.8333), fila("1A_NICA", 10, 2238.31, 0.5484),
  fila("1A_NICA", 11, 286.07, 0.4000), fila("1A_NICA", 12, -264.56, 0.2903),
  fila("3G_MARE", 7, 128.27, 0.8710), fila("3G_MARE", 8, -864.69, 0.4839),
  fila("3G_MARE", 9, 788.62, 0.7333), fila("3G_MARE", 10, 99.67, 0.5161),
  fila("3G_MARE", 11, -1894.06, 0.2000), fila("3G_MARE", 12, -2307.53, 0.0968),
  fila("4B_ALEX", 7, 194.77, 0.8387), fila("4B_ALEX", 8, -354.44, 0.7742),
  fila("4B_ALEX", 9, 1932.16, 0.9333), fila("4B_ALEX", 10, -535.92, 0.4839),
  fila("4B_ALEX", 11, -1997.08, 0.3667), fila("4B_ALEX", 12, -3007.12, 0.0645),
];

const ORDEN = ["1A_NICA", "1A_JACO", "3G_MARE", "4B_ALEX"];

describe("estadoMes — el umbral es el punto de equilibrio, no un target inventado", () => {
  it("margen positivo siempre es 'pos', aunque falte mucho por vender", () => {
    // NICA nov: solo 40 % vendido pero ya deja +286 € → verde, no gris
    expect(estadoMes({ margenNeto: 286.07, ocupVendida: 0.4000, ocupBreakeven: 0.5254 })).toBe("pos");
  });

  it("negativo por debajo del equilibrio = 'llenando' (el mes está a medio vender)", () => {
    // ALEX ago: −354 € con 77 % vendido y equilibrio en 82,8 % → todavía se está llenando
    expect(estadoMes({ margenNeto: -354.44, ocupVendida: 0.7742, ocupBreakeven: 0.8275 })).toBe("llenando");
  });

  it("negativo POR ENCIMA del equilibrio sí es alarma real ('neg')", () => {
    // Caso que hoy no ocurre pero es el que importa: vendiste más que tu equilibrio y perdés
    expect(estadoMes({ margenNeto: -300, ocupVendida: 0.98, ocupBreakeven: 0.8275 })).toBe("neg");
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

  it("JACOBINE tiene DOS meses de rojo real: vendió por encima de su equilibrio y pierde", () => {
    // jul: 77,42 % vendido contra 59,84 % de equilibrio → −31 €
    // ago: 61,29 % contra 59,84 % → −250 €, cruza la línea por 1,45 pp
    // Es el hallazgo que destapó el reparto por días: con solo un 25 % de comisión, Jacobine
    // no cubre el coste de gestionarla. Únicos casos que la doctrina admite como alarma.
    const jaco = t.filas.find((f) => f.codigo === "1A_JACO")!;
    const rojos = jaco.celdas.filter((c) => c.estado === "neg").map((c) => c.mes);
    expect(rojos).toEqual([7, 8]);
  });

  it("NICA: nov pasa a positivo y dic queda 'llenando'", () => {
    const nica = t.filas.find((f) => f.codigo === "1A_NICA")!;
    expect(nica.celdas[4].estado).toBe("pos");      // nov, +272 € tras el reparto por días
    expect(nica.celdas[5].estado).toBe("llenando"); // dic, −279 €
  });

  it("la fila de totales suma columnas", () => {
    const jul = t.totales[0];
    expect(jul.margen).toBeCloseTo(-31.33 + 2048.47 + 128.27 + 194.77, 2);
    expect(jul.estado).toBe("pos");
  });

  it("un mes con total negativo donde TODAS están llenando no se pinta en rojo", () => {
    const dic = t.totales[5];
    expect(dic.margen).toBeLessThan(0);
    expect(dic.estado).toBe("llenando");
  });

  it("el total de la fila es lo asegurado de esa propiedad hasta fin de año", () => {
    const jaco = t.filas.find((f) => f.codigo === "1A_JACO")!;
    expect(jaco.total).toBeCloseTo(-31.33 - 250.11 - 205.05 - 105.67 - 945.05 - 1158.93, 2);
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
    // jul, sep, oct en positivo · nov y dic llenando · agosto en rojo real, arrastrado por
    // Jacobine, que ya superó su ocupación de equilibrio y aun así pierde.
    expect(resumenAsegurado(t)).toBe(
      "3 de 6 meses ya cubren sus costes con lo reservado · 2 todavía a medio vender · "
      + "1 en negativo con la ocupación ya superada.",
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
