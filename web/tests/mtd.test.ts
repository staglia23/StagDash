import { describe, expect, it } from "vitest";
import { mtdPorPropiedad, type NocheRow } from "../lib/mtd";

const fila = (codigo: string, night: string, ingreso: number): NocheRow =>
  ({ codigo, night, ingreso_samavi_night: ingreso });

describe("mtdPorPropiedad", () => {
  it("compara días completos: mes actual 1..ayer vs mes anterior a igual día", () => {
    const rows = [
      fila("4B_ALEX", "2026-07-01", 100),
      fila("4B_ALEX", "2026-07-14", 100),  // ayer → cuenta
      fila("4B_ALEX", "2026-07-15", 100),  // hoy → fuera (día incompleto)
      fila("4B_ALEX", "2026-06-01", 80),
      fila("4B_ALEX", "2026-06-14", 80),   // día 14 < 15 → cuenta
      fila("4B_ALEX", "2026-06-15", 80),   // igual día → fuera
      fila("4B_ALEX", "2026-06-30", 80),   // resto de junio → fuera
    ];
    const r = mtdPorPropiedad(rows, "2026-07-15");
    expect(r).not.toBeNull();
    expect(r!.mesActual).toBe(7);
    expect(r!.mesPrevio).toBe(6);
    const alex = r!.porPropiedad.find((p) => p.codigo === "4B_ALEX")!;
    expect(alex.actual).toBe(200);
    expect(alex.previo).toBe(160);
  });

  it("agrupa por propiedad", () => {
    const rows = [
      fila("1A_NICA", "2026-07-10", 50),
      fila("3G_MARE", "2026-07-10", 70),
      fila("1A_NICA", "2026-06-05", 40),
    ];
    const r = mtdPorPropiedad(rows, "2026-07-15")!;
    expect(r.porPropiedad).toHaveLength(2);
    expect(r.porPropiedad.find((p) => p.codigo === "1A_NICA")).toEqual(
      { codigo: "1A_NICA", actual: 50, previo: 40 },
    );
  });

  it("en enero no compara (sería otro año): null", () => {
    expect(mtdPorPropiedad([fila("1A_NICA", "2026-01-10", 50)], "2026-01-15")).toBeNull();
  });

  it("el día 1 no hay días completos: null", () => {
    expect(mtdPorPropiedad([fila("1A_NICA", "2026-06-10", 50)], "2026-07-01")).toBeNull();
  });

  it("sin filas: null", () => {
    expect(mtdPorPropiedad([], "2026-07-15")).toBeNull();
  });
});
