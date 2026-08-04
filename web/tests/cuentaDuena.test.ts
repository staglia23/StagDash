import { describe, expect, it } from "vitest";
import { resumenCuentaDuena, type FilaCuenta } from "../lib/cuentaDuena";

// Fixture con los datos REALES de producción (v_cuenta_duena, 04/08/2026).
// Supabase devuelve los numeric como string: el fixture lo replica a propósito.
const REAL: FilaCuenta[] = [
  { anio: 2026, mes: 1, pasivo_alquiler: "2205.83", pasivo_cancelaciones: "210.68", limpieza: "-700.00", descuentos: "0.00", neto: "1716.51" },
  { anio: 2026, mes: 2, pasivo_alquiler: "2494.21", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "-77.00", neto: "1717.21" },
  { anio: 2026, mes: 3, pasivo_alquiler: "3273.21", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "-130.00", neto: "2443.21" },
  { anio: 2026, mes: 4, pasivo_alquiler: "5486.05", pasivo_cancelaciones: "798.43", limpieza: "-700.00", descuentos: "0.00", neto: "5584.47" },
  { anio: 2026, mes: 5, pasivo_alquiler: "3931.82", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "0.00", neto: "3231.82" },
  { anio: 2026, mes: 6, pasivo_alquiler: "3187.75", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "0.00", neto: "2487.75" },
  { anio: 2026, mes: 7, pasivo_alquiler: "2397.62", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "0.00", neto: "1697.62" },
  { anio: 2026, mes: 8, pasivo_alquiler: "192.11", pasivo_cancelaciones: "0.00", limpieza: "-700.00", descuentos: "0.00", neto: "-507.89" },
];

const AGO = { anio: 2026, mes: 8 };

describe("resumenCuentaDuena", () => {
  it("excluye el mes en curso: agosto lleva la limpieza entera contra pocos días", () => {
    const r = resumenCuentaDuena(REAL, AGO);
    expect(r.cerrados).toHaveLength(7);
    expect(r.enCurso?.mes).toBe(8);
    // sin el guard, agosto restaría 507,89 € al total y la cuenta mentiría
    expect(r.neto).toBeCloseTo(18878.59, 2);
  });

  it("cuadra con producción: devengado − limpieza − descuentos = neto", () => {
    const r = resumenCuentaDuena(REAL, AGO);
    expect(r.alquiler).toBeCloseTo(22976.49, 2);
    expect(r.cancelaciones).toBeCloseTo(1009.11, 2);   // ene 210,68 + abr 798,43
    expect(r.limpieza).toBeCloseTo(-4900, 2);          // 700 × 7 meses
    expect(r.descuentos).toBeCloseTo(-207, 2);         // UPS 77 + aspiradora 130
    expect(r.devengado).toBeCloseTo(23985.60, 2);
    // 1 céntimo de holgura: el motor redondea cada mes antes de sumar
    expect(r.devengado + r.limpieza + r.descuentos).toBeCloseTo(r.neto, 1);
  });

  it("suma los numeric-como-string de Supabase en vez de concatenarlos", () => {
    const r = resumenCuentaDuena(REAL, AGO);
    expect(typeof r.neto).toBe("number");
    expect(String(r.alquiler)).not.toContain("2205.832494.21");
  });

  it("enero del año: sin meses cerrados no inventa un total", () => {
    const soloEnero = [REAL[0]];
    const r = resumenCuentaDuena(soloEnero, { anio: 2026, mes: 1 });
    expect(r.cerrados).toHaveLength(0);
    expect(r.enCurso?.mes).toBe(1);
    expect(r.neto).toBe(0);   // el UI muestra "—", no "0,00 € a favor"
  });

  it("cuenta acumulativa 2025+2026: separa los años y suma el total (datos de producción)", () => {
    // 2025 real de v_cuenta_duena tras la migración 071 (limpieza a coste real hasta oct).
    const dosAnios: FilaCuenta[] = [
      { anio: 2025, mes: 6,  pasivo_alquiler: "463.88",  pasivo_cancelaciones: "0", limpieza: "-299.48", descuentos: "-272.25", neto: "-107.85" },
      { anio: 2025, mes: 7,  pasivo_alquiler: "1772.57", pasivo_cancelaciones: "0", limpieza: "-592.90", descuentos: "-2044.00", neto: "-864.33" },
      { anio: 2025, mes: 8,  pasivo_alquiler: "1712.65", pasivo_cancelaciones: "0", limpieza: "-508.20", descuentos: "0", neto: "1204.45" },
      { anio: 2025, mes: 9,  pasivo_alquiler: "2913.03", pasivo_cancelaciones: "0", limpieza: "-707.85", descuentos: "0", neto: "2205.18" },
      { anio: 2025, mes: 10, pasivo_alquiler: "3545.53", pasivo_cancelaciones: "0", limpieza: "-592.90", descuentos: "0", neto: "2952.63" },
      { anio: 2025, mes: 11, pasivo_alquiler: "2695.16", pasivo_cancelaciones: "0", limpieza: "-700.00", descuentos: "-83.00", neto: "1912.16" },
      { anio: 2025, mes: 12, pasivo_alquiler: "2284.58", pasivo_cancelaciones: "0", limpieza: "-700.00", descuentos: "-409.14", neto: "1175.44" },
      ...REAL.slice(0, 7),  // ene–jul 2026
    ];
    const r = resumenCuentaDuena(dosAnios, AGO);
    expect(r.porAnio.map((a) => a.anio)).toEqual([2025, 2026]);
    // el saldo 2025 verificado contra Guesty reserva por reserva
    expect(r.porAnio[0].neto).toBeCloseTo(8477.68, 2);
    expect(r.porAnio[0].meses).toBe(7);
    expect(r.porAnio[1].neto).toBeCloseTo(18878.59, 2);
    // el total es la deuda entera: a la dueña no se le transfirió nada todavía
    expect(r.neto).toBeCloseTo(8477.68 + 18878.59, 2);
  });

  it("con un solo año no genera el desglose por años (no hay nada que desglosar)", () => {
    const r = resumenCuentaDuena(REAL, AGO);
    expect(r.porAnio).toHaveLength(1);
    expect(r.porAnio[0].anio).toBe(2026);
  });

  it("si el mes en curso todavía no existe en el motor, todo cuenta como cerrado", () => {
    // borde real: Madrid ya pasó a septiembre y el spine aún no trae la fila nueva
    const r = resumenCuentaDuena(REAL, { anio: 2026, mes: 9 });
    expect(r.cerrados).toHaveLength(8);
    expect(r.enCurso).toBeNull();
  });
});
