import { describe, expect, it } from "vitest";
import { lineaCuadre, normalizaCuadre, resumenCuadre, stampCuadre, type CuadreRow } from "../lib/cuadre";
import { eur, eurCorto } from "../lib/format";

const row = (over: Partial<CuadreRow>): CuadreRow => ({
  orden: 1, chequeo: "x", titulo: "t", estado: "ok",
  esperado: 100, obtenido: 100, unidad: "eur", detalle: "",
  ...over,
});

describe("resumenCuadre", () => {
  it("todo ok: N de N cuadran, los info no cuentan", () => {
    const r = resumenCuadre([
      row({}), row({ orden: 2 }),
      row({ orden: 9, estado: "info", unidad: "mes", esperado: null, obtenido: 6 }),
    ]);
    expect(r.total).toBe(2);
    expect(r.alertas).toBe(0);
    expect(r.texto).toBe("✓ 2 de 2 chequeos cuadran");
  });

  it("con alertas: las cuenta y cambia el texto", () => {
    const r = resumenCuadre([row({}), row({ orden: 2, estado: "alerta", obtenido: 90 })]);
    expect(r.alertas).toBe(1);
    expect(r.texto).toBe("⚠ 1 de 2 chequeos no cuadran");
  });
});

describe("stampCuadre", () => {
  it("sin filas (vista sin migrar): null → la portada no muestra nada", () => {
    expect(stampCuadre([])).toBeNull();
  });
  it("ok → cuadre ✓ N/N; alerta → cuadre ⚠ N", () => {
    expect(stampCuadre([row({})])).toBe("cuadre ✓ 1/1");
    expect(stampCuadre([row({ estado: "alerta" })])).toBe("cuadre ⚠ 1");
  });
});

describe("lineaCuadre", () => {
  it("eur ok exacto: un solo número", () => {
    expect(lineaCuadre(row({ esperado: 45789, obtenido: 45789 })))
      .toBe(`los dos caminos dan ${eur(45789, 2)}`);
  });
  it("eur ok con redondeo: muestra la dif y la explica", () => {
    expect(lineaCuadre(row({ esperado: 100, obtenido: 100.02 })))
      .toContain("redondeo, dentro de tolerancia");
  });
  it("eur alerta: esperado, obtenido y dif", () => {
    const l = lineaCuadre(row({ estado: "alerta", esperado: 1000, obtenido: 900 }));
    expect(l).toContain(eur(1000, 2));
    expect(l).toContain(eur(900, 2));
    expect(l).toContain(`dif ${eur(-100, 2)}`);
  });
  it("casos: 0 limpio, >0 pide revisar", () => {
    expect(lineaCuadre(row({ unidad: "casos", esperado: 0, obtenido: 0 }))).toBe("0 casos");
    expect(lineaCuadre(row({ unidad: "casos", estado: "alerta", esperado: 0, obtenido: 3 })))
      .toBe("3 caso(s) — revisar");
  });
  it("horas y mes", () => {
    expect(lineaCuadre(row({ unidad: "horas", esperado: 6, obtenido: 2.4 })))
      .toBe("hace 2,4 h (límite 6 h)");
    expect(lineaCuadre(row({ unidad: "mes", estado: "info", esperado: null, obtenido: 6 })))
      .toBe("hasta Jun");
  });
});

describe("normalizaCuadre", () => {
  it("convierte los numeric-string de Supabase (el '0' string rompía el caso 'casos')", () => {
    const [r] = normalizaCuadre([{
      orden: "6", chequeo: "ocupacion_fisica", titulo: "t", estado: "ok",
      esperado: "0", obtenido: "0", unidad: "casos", detalle: "",
    }]);
    expect(r.obtenido).toBe(0);
    expect(lineaCuadre(r)).toBe("0 casos");
    expect(normalizaCuadre([{ ...r, esperado: null, obtenido: null }])[0].esperado).toBeNull();
  });
});

describe("eurCorto (etiquetas de minibarras)", () => {
  it("bajo mil: entero con €", () => {
    expect(eurCorto(434.4)).toBe("434 €");
    expect(eurCorto(-52)).toBe("−52 €");
  });
  it("miles: compacto es-ES con una decimal", () => {
    expect(eurCorto(1943)).toBe("1,9k€");
    expect(eurCorto(-12345)).toBe("−12,3k€");
    expect(eurCorto(2000)).toBe("2k€");
  });
});
