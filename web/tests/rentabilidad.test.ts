// Fixtures = v_ranking_ytd real de producción (25/07/2026), POST migraciones 025–036: el motor
// tiene tres capas y estas funciones miran la CONTRIBUCIÓN, que es la que decide si vale la
// pena tener una propiedad. Antes miraban el margen neto, que dependía de una regla de
// reparto de overhead — comparaba el reparto, no el piso.
// La 031 metió la limpieza real de Ecocleans (ene–jun) y la 034 los suministros reales de las
// facturas de Confisic: la limpieza baja la contribución, los suministros la suben (el fijo de
// 150 €/mes estaba largo). Alexander queda en 36,59 % — el peor aportador de la cartera.
import { describe, expect, it } from "vitest";
import { cruceRentabilidad, spreadContribucion, type RentRow } from "../lib/rentabilidad";

const REAL: RentRow[] = [
  { codigo: "1A_NICA", ingreso_samavi: 33517.81, contribucion: 20847.16, contribucion_pct: 0.6220, margen_neto: 13187.31 },
  { codigo: "1A_JACO", ingreso_samavi: 11699.68, contribucion: 10830.03, contribucion_pct: 0.9257, margen_neto: 3170.18 },
  { codigo: "3G_MARE", ingreso_samavi: 23420.76, contribucion: 10126.42, contribucion_pct: 0.4324, margen_neto: 2466.57 },
  { codigo: "4B_ALEX", ingreso_samavi: 27178.17, contribucion: 9944.01, contribucion_pct: 0.3659, margen_neto: 2284.16 },
];

/** es-ES mete espacios duros distintos antes de € (U+00A0) y de % (U+202F, fino):
 *  normalizar TODOS los separadores Unicode para poder comparar. */
const plano = (s: string | null) => s?.replace(/\s/g, " ") ?? null;

describe("cruceRentabilidad", () => {
  it("con los datos de hoy CALLA: ninguna propiedad chica aporta como Nicasio", () => {
    // Jacobine aporta 10.830 € contra los 20.854 € de Nicasio: un 52 %, lejos del 80 %.
    // Con el reparto viejo (por ingreso) Jacobine parecía rendir casi como Nicasio, pero era
    // un artefacto de cargarle un tercio del overhead que le correspondía.
    expect(cruceRentabilidad(REAL)).toBeNull();
  });

  it("emite la frase cuando el cruce SÍ existe", () => {
    const conCruce: RentRow[] = [
      { codigo: "1A_NICA", ingreso_samavi: 30000, contribucion: 9000, contribucion_pct: 0.30, margen_neto: 5000 },
      { codigo: "1A_JACO", ingreso_samavi: 12000, contribucion: 7800, contribucion_pct: 0.65, margen_neto: 4000 },
    ];
    expect(plano(cruceRentabilidad(conCruce))).toBe(
      "Jacobine aporta casi lo mismo que Nicasio (7.800 € vs 9.000 €) con menos de la mitad "
      + "del ingreso: 65 % de contribución contra 30 %.",
    );
  });

  it("calla si la que más aporta es además la más eficiente", () => {
    const sinCruce: RentRow[] = [
      { codigo: "1A_NICA", ingreso_samavi: 30000, contribucion: 9000, contribucion_pct: 0.30, margen_neto: 5000 },
      { codigo: "3G_MARE", ingreso_samavi: 20000, contribucion: 2000, contribucion_pct: 0.10, margen_neto: 1000 },
    ];
    expect(cruceRentabilidad(sinCruce)).toBeNull();
  });

  it("calla si nadie aporta nada (no hay nada que celebrar)", () => {
    const enRojo: RentRow[] = [
      { codigo: "1A_NICA", ingreso_samavi: 30000, contribucion: -100, contribucion_pct: -0.003, margen_neto: -900 },
      { codigo: "1A_JACO", ingreso_samavi: 10000, contribucion: -50, contribucion_pct: -0.005, margen_neto: -800 },
    ];
    expect(cruceRentabilidad(enRojo)).toBeNull();
  });

  it("con una sola propiedad no hay comparación posible", () => {
    expect(cruceRentabilidad([REAL[0]])).toBeNull();
  });
});

describe("spreadContribucion", () => {
  it("señala la horquilla real de hoy: Jacobine 93 % contra Alexander 37 %", () => {
    expect(plano(spreadContribucion(REAL))).toBe(
      "De cada euro que entra, Jacobine conserva 93 % tras sus costes directos y Alexander "
      + "solo 37 %. Esa distancia es la renta.",
    );
  });

  it("calla si la horquilla es estrecha: ahí no hay nada que decidir", () => {
    const parejas: RentRow[] = [
      { codigo: "1A_NICA", ingreso_samavi: 30000, contribucion: 12000, contribucion_pct: 0.40, margen_neto: 5000 },
      { codigo: "3G_MARE", ingreso_samavi: 20000, contribucion: 6600, contribucion_pct: 0.33, margen_neto: 3000 },
    ];
    expect(spreadContribucion(parejas)).toBeNull();
  });

  it("con una sola propiedad no hay horquilla", () => {
    expect(spreadContribucion([REAL[0]])).toBeNull();
  });
});
