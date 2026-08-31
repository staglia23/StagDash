import { describe, expect, it } from "vitest";
import {
  estrenoYoy, filasPace, resumenMercado, resumenMercadoSolo, resumenYoy,
  serieAdrYoy, serieMercado, titularPace, titularYoy,
  type MercadoRow, type PaceRow, type YoyRow,
} from "../lib/yoy";

// Fixtures con datos REALES de producción (v_yoy_mensual / v_pace_yoy /
// v_pricelabs_mercado, consultadas el 01/09/2026, recién aplicada la 094).
// Los numeric van como string a propósito: replican lo que devuelve Supabase.

const yoyNica: YoyRow[] = [
  { codigo: "1A_NICA", anio: 2026, mes: 5, noches: 28, ocupacion: "0.903", adr: "221.79", revpar: "200.32", noches_ly: 31, ocupacion_ly: "1.000", adr_ly: "192.53", revpar_ly: "192.53", comparable: true, arranque_ly: false },
  { codigo: "1A_NICA", anio: 2026, mes: 6, noches: 27, ocupacion: "0.900", adr: "228.82", revpar: "205.93", noches_ly: 28, ocupacion_ly: "0.933", adr_ly: "197.78", revpar_ly: "184.59", comparable: true, arranque_ly: false },
  { codigo: "1A_NICA", anio: 2026, mes: 7, noches: 26, ocupacion: "0.839", adr: "166.34", revpar: "139.51", noches_ly: 30, ocupacion_ly: "0.968", adr_ly: "173.35", revpar_ly: "167.76", comparable: true, arranque_ly: false },
];

const yoyJaco: YoyRow[] = [
  { codigo: "1A_JACO", anio: 2026, mes: 5, noches: 26, ocupacion: "0.839", adr: "278.08", revpar: "233.23", noches_ly: null, ocupacion_ly: null, adr_ly: null, revpar_ly: null, comparable: false, arranque_ly: false },
  { codigo: "1A_JACO", anio: 2026, mes: 6, noches: 27, ocupacion: "0.900", adr: "212.86", revpar: "191.57", noches_ly: 6, ocupacion_ly: "0.200", adr_ly: "126.50", revpar_ly: "25.30", comparable: true, arranque_ly: true },
  { codigo: "1A_JACO", anio: 2026, mes: 7, noches: 24, ocupacion: "0.774", adr: "172.73", revpar: "133.72", noches_ly: 24, ocupacion_ly: "0.774", adr_ly: "117.86", revpar_ly: "91.25", comparable: true, arranque_ly: false },
];

const yoyMare: YoyRow[] = [
  { codigo: "3G_MARE", anio: 2026, mes: 6, noches: 30, ocupacion: "1.000", adr: "158.35", revpar: "158.35", noches_ly: null, ocupacion_ly: null, adr_ly: null, revpar_ly: null, comparable: false, arranque_ly: false },
];

describe("resumenYoy", () => {
  it("agrega NICA may–jul ponderado por noches (ADR y RevPAR al céntimo)", () => {
    const r = resumenYoy(yoyNica, 2026)!;
    // aloj 2026 = 28·221,79 + 27·228,82 + 26·166,34 = 16.713,10 € en 81 noches
    expect(r.noches).toBe(81);
    expect(r.adr).toBeCloseTo(206.33, 1);
    // aloj 2025 = 31·192,53 + 28·197,78 + 30·173,35 = 16.706,77 € en 89 noches
    expect(r.nochesLy).toBe(89);
    expect(r.adrLy).toBeCloseTo(187.72, 1);
    expect(r.deltaAdrPct).toBeCloseTo(0.0992, 3);
    // 92 días en ambos años (may+jun+jul) → ocupación 81/92 vs 89/92
    expect(r.deltaOcupPp).toBeCloseTo(-0.087, 3);
    // La lección del RevPAR: +10 % de precio y −9 pp de ocupación ≈ mismo RevPAR
    expect(r.deltaRevparPct).toBeCloseTo(0.0004, 3);
  });

  it("excluye del agregado el mes de alta del año previo (Jacobine jun-2025, 6 noches)", () => {
    const r = resumenYoy(yoyJaco, 2026)!;
    expect(r.meses).toBe(1);          // solo julio
    expect(r.mesesExcluidos).toBe(1); // junio, arranque
    expect(r.deltaAdrPct).toBeCloseTo(0.4655, 3);
  });

  it("sin meses comparables devuelve null, nunca ceros (Marechal)", () => {
    expect(resumenYoy(yoyMare, 2026)).toBeNull();
  });
});

describe("titularYoy", () => {
  it("NICA: sube precio, baja ocupación", () => {
    expect(titularYoy(resumenYoy(yoyNica, 2026))).toBe(
      "Vende un +10 % más caro que el año pasado, con −9 pp de ocupación.",
    );
  });
  it("sin base: lo dice, no inventa", () => {
    expect(titularYoy(null)).toBe("Sin año previo comparable todavía.");
  });
  it("delta plano se dice como plano", () => {
    const r = { ...resumenYoy(yoyNica, 2026)!, deltaAdrPct: 0.002, deltaOcupPp: 0.001 };
    expect(titularYoy(r)).toBe("Vende al precio del año pasado, con igual ocupación.");
  });
});

describe("serieAdrYoy", () => {
  it("mayo de Jacobine no lleva línea del año pasado (no existía)", () => {
    const s = serieAdrYoy(yoyJaco, 2026);
    expect(s[0]).toEqual({ mes: 5, adr: 278.08, adrLy: null, arranqueLy: false });
    expect(s[1].arranqueLy).toBe(true); // junio: se dibuja, pero avisado
    expect(s[2].adrLy).toBe(117.86);
  });
});

const mercadoNica: MercadoRow[] = [
  { codigo: "1A_NICA", mes: "2024-08-01", adr_mercado: "111.79", ocupacion_mercado: "0.700", adr_mercado_ly: null, ocupacion_mercado_ly: null, n_listings: 266, categoria: "1", muestra_chica: true },
  { codigo: "1A_NICA", mes: "2026-04-01", adr_mercado: "179.67", ocupacion_mercado: "0.885", adr_mercado_ly: "158.55", ocupacion_mercado_ly: "0.886", n_listings: 266, categoria: "1", muestra_chica: false },
  { codigo: "1A_NICA", mes: "2026-08-01", adr_mercado: "118.94", ocupacion_mercado: "0.728", adr_mercado_ly: "118.76", ocupacion_mercado_ly: "0.770", n_listings: 266, categoria: "1", muestra_chica: false },
  { codigo: "1A_NICA", mes: "2026-09-01", adr_mercado: "50.00", ocupacion_mercado: "0.050", adr_mercado_ly: "159.71", ocupacion_mercado_ly: "0.896", n_listings: 266, categoria: "1", muestra_chica: false },
];

describe("serieMercado", () => {
  it("descarta la muestra chica (ago-2024) y el mes en curso, y casa propio con barrio", () => {
    const yoyAbr: YoyRow[] = [
      { codigo: "1A_NICA", anio: 2026, mes: 4, noches: 26, ocupacion: "0.867", adr: "238.11", revpar: "206.36", noches_ly: 29, ocupacion_ly: "0.967", adr_ly: "222.06", revpar_ly: "214.66", comparable: true, arranque_ly: false },
    ];
    const s = serieMercado(yoyAbr, mercadoNica, "2026-09-01");
    expect(s.map((p) => p.label)).toEqual(["Abr 26", "Ago 26"]);
    expect(s[0]).toMatchObject({ propio: 238.11, mercado: 179.67 });
    expect(s[1].propio).toBeNull(); // sin fila propia de agosto en este fixture
  });
});

describe("resumenMercado / resumenMercadoSolo", () => {
  it("premium ponderado por noches propias y YoY medio del barrio", () => {
    const yoyAbr: YoyRow[] = [
      { codigo: "1A_NICA", anio: 2026, mes: 4, noches: 26, ocupacion: "0.867", adr: "238.11", revpar: "206.36", noches_ly: 29, ocupacion_ly: "0.967", adr_ly: "222.06", revpar_ly: "214.66", comparable: true, arranque_ly: false },
    ];
    const r = resumenMercado(yoyAbr, mercadoNica, 2026);
    expect(r.premiumPct).toBeCloseTo(238.11 / 179.67 - 1, 4); // +32,5 %
    expect(r.mercadoYoyPct).toBeCloseTo(179.67 / 158.55 - 1, 4);
  });
  it("la tendencia sola promedia los meses del año con base", () => {
    const r = resumenMercadoSolo(mercadoNica, 2026);
    // abr +13,3 %, ago +0,2 %, sep (en curso, pero con base) −68,7 % — el corte del mes
    // en curso lo hace la serie del gráfico; acá entran los tres con base LY
    expect(r.meses).toBe(3);
    expect(r.ocupYoyPp).toBeCloseTo(((0.885 - 0.886) + (0.728 - 0.770) + (0.05 - 0.896)) / 3, 4);
  });
});

const paceRows: PaceRow[] = [
  { codigo: "1A_NICA", anio: 2026, mes: 9, dias: 30, noches_otb: 25, adr_otb: "260.93", noches_ly: 27, adr_ly: "208.12", stly_valido: true },
  { codigo: "1A_NICA", anio: 2027, mes: 2, dias: 28, noches_otb: 1, adr_otb: "164.88", noches_ly: 27, adr_ly: "142.98", stly_valido: true },
  { codigo: "3G_MARE", anio: 2026, mes: 9, dias: 30, noches_otb: 28, adr_otb: "185.11", noches_ly: 0, adr_ly: null, stly_valido: false },
  { codigo: "3G_MARE", anio: 2027, mes: 1, dias: 31, noches_otb: 6, adr_otb: "123.00", noches_ly: 30, adr_ly: "91.24", stly_valido: true },
];

describe("filasPace", () => {
  it("sin STLY válido, ly es null (no existía) — nunca un cero inventado", () => {
    const f = filasPace(paceRows.filter((r) => r.codigo === "3G_MARE"));
    expect(f[0].ly).toBeNull();
    expect(f[1].adrDeltaPct).toBeCloseTo(123 / 91.24 - 1, 4);
  });
  it("con menos de 5 noches vendidas el delta de ADR se calla (muestra chica)", () => {
    const f = filasPace(paceRows.filter((r) => r.codigo === "1A_NICA"));
    expect(f[0].adrDeltaPct).toBeCloseTo(0.2538, 3); // sep: 25 noches, habla
    expect(f[1].adrDeltaPct).toBeNull();             // feb: 1 noche, se calla
  });
});

describe("titularPace", () => {
  it("resume el rango de los dos meses más cercanos", () => {
    const porPiso = [
      { filas: filasPace(paceRows.filter((r) => r.codigo === "1A_NICA")) },
      { filas: filasPace([{ codigo: "1A_JACO", anio: 2026, mes: 10, dias: 31, noches_otb: 24, adr_otb: "273.67", noches_ly: 29, adr_ly: "222.35", stly_valido: true }]) },
    ];
    // meses más cercanos: sep (NICA +25 %) y oct (JACO +23 %)
    expect(titularPace(porPiso)).toBe(
      "Lo ya vendido para sep y oct va entre +23 % y +25 % más caro que como cerró el año pasado.",
    );
  });
  it("sin deltas calculables devuelve null", () => {
    expect(titularPace([{ filas: filasPace(paceRows.filter((r) => r.codigo === "3G_MARE").slice(0, 1)) }])).toBeNull();
  });
});

describe("estrenoYoy", () => {
  it("un año después del alta", () => {
    expect(estrenoYoy("2025-10-01")).toBe("oct 2026");
    expect(estrenoYoy(null)).toBeNull();
  });
});
