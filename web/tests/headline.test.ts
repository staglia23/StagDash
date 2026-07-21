import { describe, expect, it } from "vitest";
import {
  buildHeadline, MAX_CHARS, UMBRAL_DESVIO_MTD, UMBRAL_DIAS_LIMITE,
  type HeadlineInput,
} from "../lib/headline";
import { eur, pct } from "../lib/format";

// Fixture con los datos verificados en producción (15/07/2026).
const base = (): HeadlineInput => ({
  alertas: [
    { codigo: "4B_ALEX", tipo: "contrato", clase: "alerta", dias_restantes: 48 },
    { codigo: "4B_ALEX", tipo: "breakeven", clase: "senal", dias_restantes: null },
    { codigo: "4B_ALEX", tipo: "mes_negativo", clase: "senal", dias_restantes: null },
    { codigo: "3G_MARE", tipo: "mes_negativo", clase: "senal", dias_restantes: null },
  ],
  costesPct: { "1A_NICA": 0.639, "1A_JACO": 0.4206, "3G_MARE": 0.8377, "4B_ALEX": 0.9447 },
  mtd: {
    mesActual: 7,
    mesPrevio: 6,
    porPropiedad: [
      { codigo: "1A_JACO", actual: 645.5, previo: 958.74 },
      { codigo: "1A_NICA", actual: 2124.85, previo: 2517.5 },
      { codigo: "3G_MARE", actual: 1759.41, previo: 2029.28 },
      { codigo: "4B_ALEX", actual: 1705.73, previo: 2368.34 },
    ],
  },
  kpis: { margen_neto_ytd: 25005, margen_neto_pct_ytd: 0.258 },
  breakeven: [
    { codigo: "4B_ALEX", colchon: 0.0557 },
    { codigo: "3G_MARE", colchon: 0.1662 },
    { codigo: "1A_NICA", colchon: 0.3667 },
    { codigo: "1A_JACO", colchon: 0.4673 },
  ],
});

describe("caso 1 — alerta con fecha límite ≤ 60 días", () => {
  it("caso rey: ALEX a 48 días nombra la propiedad y su consumo de costes", () => {
    const frase = buildHeadline(base());
    expect(frase).toBe(
      `Quedan 48 días para avisar a Alexander — hoy consume el ${pct(0.9447)} de lo que ingresa`,
    );
    expect(frase.length).toBeLessThanOrEqual(MAX_CHARS);
  });

  it("respeta el umbral: a 61 días cae al caso 2", () => {
    const i = base();
    i.alertas[0].dias_restantes = UMBRAL_DIAS_LIMITE + 1;
    expect(buildHeadline(i)).toContain("Ingreso de julio");
  });

  it("a exactamente 60 días sigue siendo caso 1", () => {
    const i = base();
    i.alertas[0].dias_restantes = UMBRAL_DIAS_LIMITE;
    expect(buildHeadline(i)).toContain("Quedan 60 días");
  });

  it("singular y vencimiento hoy", () => {
    const i = base();
    i.alertas[0].dias_restantes = 1;
    expect(buildHeadline(i)).toContain("Queda 1 día");
    i.alertas[0].dias_restantes = 0;
    expect(buildHeadline(i)).toContain("Hoy vence el plazo");
  });

  it("gana la alerta con menor fecha límite", () => {
    const i = base();
    i.alertas.push({ codigo: "3G_MARE", tipo: "contrato", clase: "alerta", dias_restantes: 20 });
    expect(buildHeadline(i)).toContain("Marechal");
  });

  it("las señales sin fecha nunca disparan el caso 1", () => {
    const i = base();
    i.alertas = i.alertas.filter((a) => a.clase === "senal");
    expect(buildHeadline(i)).not.toContain("Quedan");
  });
});

describe("caso 2 — desvío de ingreso MTD ±10 %", () => {
  const sinAlertas = (): HeadlineInput => ({ ...base(), alertas: [] });

  it("nombra la propiedad causante de la caída (ALEX resta más)", () => {
    const frase = buildHeadline(sinAlertas());
    // total: 6.235 vs 7.874 → cae 21 %; ALEX resta 663 €
    expect(frase).toContain("Ingreso de julio cae");
    expect(frase).toContain("vs junio a igual día");
    expect(frase).toContain(`Alexander resta ${eur(662.61)}`);
    expect(frase.length).toBeLessThanOrEqual(MAX_CHARS);
  });

  it("una subida usa verbos en positivo", () => {
    const i = sinAlertas();
    i.mtd!.porPropiedad = [{ codigo: "1A_NICA", actual: 3000, previo: 2500 }];
    const frase = buildHeadline(i);
    expect(frase).toContain("sube");
    expect(frase).toContain("Nicasio suma");
  });

  it("la causante va en la dirección del desvío: una caída nunca se atribuye a la que subió", () => {
    const i = sinAlertas();
    i.mtd!.porPropiedad = [
      { codigo: "1A_NICA", actual: 3300, previo: 2500 }, // sube 800 (el mayor |Δ|)
      { codigo: "4B_ALEX", actual: 1000, previo: 1700 }, // resta 700
      { codigo: "3G_MARE", actual: 800, previo: 1500 },  // resta 700
    ];
    // total: 5.100 vs 5.700 → cae 10,5 % — la causa es una que RESTA, no NICA
    const frase = buildHeadline(i);
    expect(frase).toContain("cae");
    expect(frase).not.toContain("Nicasio");
    expect(frase).toContain("resta");
  });

  it("por debajo del umbral (±10 %) cae al caso 3", () => {
    const i = sinAlertas();
    const factor = 1 - UMBRAL_DESVIO_MTD + 0.01; // −9 %
    i.mtd!.porPropiedad = i.mtd!.porPropiedad.map((p) => ({ ...p, actual: p.previo * factor }));
    expect(buildHeadline(i)).toContain("Margen neto");
  });

  it("sin mes previo comparable (previo = 0) cae al caso 3", () => {
    const i = sinAlertas();
    i.mtd!.porPropiedad = i.mtd!.porPropiedad.map((p) => ({ ...p, previo: 0 }));
    expect(buildHeadline(i)).toContain("Margen neto");
  });
});

describe("caso 3 — estado + dato fuerte", () => {
  const soloEstado = (): HeadlineInput => ({ ...base(), alertas: [], mtd: null });

  it("todas cubren el equilibrio", () => {
    const frase = buildHeadline(soloEstado());
    expect(frase).toBe(
      `Margen neto ${eur(25005)} (${pct(0.258)}) — las 4 propiedades cubren su punto de equilibrio`,
    );
    expect(frase.length).toBeLessThanOrEqual(MAX_CHARS);
  });

  it("con colchón negativo nombra la peor propiedad", () => {
    const i = soloEstado();
    i.breakeven[0].colchon = -0.03;
    expect(buildHeadline(i)).toContain("Alexander opera bajo su punto de equilibrio");
  });
});

describe("restricción global", () => {
  it("ningún titular supera los 90 caracteres", () => {
    const variantes: HeadlineInput[] = [
      base(),
      { ...base(), alertas: [] },
      { ...base(), alertas: [], mtd: null },
      {
        ...base(),
        alertas: [{ codigo: "3G_MARE", tipo: "contrato", clase: "alerta", dias_restantes: 59 }],
        costesPct: { "3G_MARE": 0.8377 },
      },
    ];
    for (const v of variantes) {
      expect(buildHeadline(v).length).toBeLessThanOrEqual(MAX_CHARS);
    }
  });
});
