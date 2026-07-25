// Fixture = margen neto YTD real de producción tras las migraciones 021 y 022 (25/07/2026).
import { describe, expect, it } from "vitest";
import { calcularFiscal, TIPO_IS_ESTIMADO } from "../lib/impuestos";

const MARGEN_YTD = 15143.67;

describe("calcularFiscal", () => {
  it("provisiona el 20 % sobre el margen operativo real de hoy", () => {
    const f = calcularFiscal(MARGEN_YTD);
    expect(f.tipo).toBe(0.20);
    expect(f.provisionIS).toBeCloseTo(3028.73, 2);
    expect(f.quedaEstimado).toBeCloseTo(12114.94, 2);
  });

  it("sin beneficio no provisiona nada: no se inventa un gasto que no existe", () => {
    const f = calcularFiscal(-4200);
    expect(f.provisionIS).toBe(0);
    expect(f.quedaEstimado).toBe(-4200);
  });

  it("en el cero exacto tampoco provisiona", () => {
    expect(calcularFiscal(0).provisionIS).toBe(0);
  });

  it("acepta otro tipo si Confisic confirma uno distinto", () => {
    const f = calcularFiscal(10000, 0.25);
    expect(f.provisionIS).toBeCloseTo(2500, 2);
    expect(f.quedaEstimado).toBeCloseTo(7500, 2);
  });

  it("el tipo por defecto es el acordado con Stag", () => {
    expect(TIPO_IS_ESTIMADO).toBe(0.20);
    expect(calcularFiscal(1000).provisionIS).toBeCloseTo(200, 2);
  });
});
