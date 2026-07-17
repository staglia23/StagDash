import { describe, expect, it } from "vitest";
import { pasosWaterfall } from "../lib/waterfall";

// Fixture: JACO YTD real tras la migración 009 (canceladas retenidas como entrada aparte).
const JACO = {
  modelo: "comision" as const,
  bruto: 44887.15,
  ingreso_samavi: 14176.96,          // incluye 598,60 de canceladas
  ingreso_cancelaciones: 598.6,
  renta: 0, limpieza: 0, suministros: 75.53, comunidad: 0, otros: 368.2,
  overhead: 5267.28,
  margen_directo: 13733.23,
  margen_neto: 8465.95,
};

describe("pasosWaterfall", () => {
  it("la cadena cierra: bruto − comisión + canceladas = ingreso, y el último total es el margen neto", () => {
    const pasos = pasosWaterfall(JACO);
    const ingreso = pasos.find((p) => p.key === "ingreso")!;
    const comision = pasos.find((p) => p.key === "comision")!;
    const canceladas = pasos.find((p) => p.key === "cancelaciones")!;
    expect(comision.desde - comision.hasta).toBeCloseTo(
      JACO.bruto - (JACO.ingreso_samavi - JACO.ingreso_cancelaciones), 6);
    expect(canceladas.tipo).toBe("entrada");
    expect(canceladas.hasta - canceladas.desde).toBeCloseTo(598.6, 6);
    expect(canceladas.hasta).toBeCloseTo(ingreso.hasta, 6);
    expect(pasos[pasos.length - 1].key).toBe("neto");
    expect(pasos[pasos.length - 1].hasta).toBeCloseTo(JACO.margen_neto, 6);
  });

  it("sin canceladas no hay escalón de entrada y la identidad clásica se mantiene", () => {
    const pasos = pasosWaterfall({ ...JACO, ingreso_samavi: 13578.36, ingreso_cancelaciones: 0 });
    expect(pasos.find((p) => p.key === "cancelaciones")).toBeUndefined();
    const comision = pasos.find((p) => p.key === "comision")!;
    expect(comision.hasta).toBeCloseTo(13578.36, 6);
  });

  it("una línea de coste en crédito (importe negativo) sube el acumulado", () => {
    const pasos = pasosWaterfall({ ...JACO, otros: -100 });
    const otros = pasos.find((p) => p.key === "otros")!;
    expect(otros.hasta).toBeGreaterThan(otros.desde);
  });
});
