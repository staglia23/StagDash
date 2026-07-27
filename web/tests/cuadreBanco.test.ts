import { describe, expect, it } from "vitest";
import { bancoTodoOk, resumenBanco, type BancoRow } from "../lib/cuadreBanco";

// Fixture con los números reales H1 2026 (Revolut 7165 = Nica+Jaco, BBVA 8920 = Alex+Mare),
// tras la migración 057: el mes-borde (enero) queda fuera del "en tránsito" del semáforo.
const row = (o: Partial<BancoRow>): BancoRow => ({
  iban: "7165", cuenta: "Revolut · Nicasio + Jacobine", anio: 2026, mes: 1,
  airbnb_pago: 0, banco_recibio: 0, depositos: 0, diferencia_mes: 0, diferencia_acum: 0, ...o,
});

describe("resumenBanco", () => {
  it("usa el acumulado AJUSTADO (sin mes-borde) y mide el % contra lo pagado desde el 2º mes", () => {
    // Revolut real: ene arrastra +2.656,55 de estancias de dic-2025 (arranque, no tránsito).
    const rows: BancoRow[] = [
      row({ mes: 1, airbnb_pago: 6434.41, banco_recibio: 9090.96, diferencia_acum: 2656.55, mes_borde: true, diferencia_acum_ajustada: 0 }),
      row({ mes: 6, airbnb_pago: 9817.30, banco_recibio: 10426.79, diferencia_acum: 2328.86, mes_borde: false, diferencia_acum_ajustada: -327.69 }),
    ];
    const [rev] = resumenBanco(rows);
    expect(rev.airbnb).toBeCloseTo(16251.71, 2); // el total mostrado sigue siendo completo
    expect(rev.enTransito).toBe(-327.69);        // el semáforo mira el tránsito real
    expect(rev.bordeExcluido).toBe(true);
    expect(rev.ok).toBe(true);                   // 327,69 / 9.817,30 = 3,3 % < 15 %
  });

  it("el colchón del mes-borde ya no enmascara un faltante real", () => {
    // Con la regla vieja: acumulado −343 sobre 16.434 pagados = 2 % → verde MENTIROSO.
    // Faltan 3.000 € desde febrero; el colchón de enero los tapaba.
    const rows: BancoRow[] = [
      row({ mes: 1, airbnb_pago: 6434.41, banco_recibio: 9090.96, diferencia_acum: 2656.55, mes_borde: true, diferencia_acum_ajustada: 0 }),
      row({ mes: 2, airbnb_pago: 10000, banco_recibio: 7000, diferencia_acum: -343.45, mes_borde: false, diferencia_acum_ajustada: -3000 }),
    ];
    const [rev] = resumenBanco(rows);
    expect(rev.enTransito).toBe(-3000);
    expect(rev.ok).toBe(false); // 3.000 / 10.000 = 30 % → investigar
  });

  it("sin columna ajustada (datos viejos) cae al acumulado clásico", () => {
    const rows: BancoRow[] = [
      row({ mes: 1, airbnb_pago: 6434.41, banco_recibio: 9090.96, diferencia_acum: 2656.55 }),
      row({ mes: 6, airbnb_pago: 9817.30, banco_recibio: 10426.79, diferencia_acum: 2328.86 }),
    ];
    const [rev] = resumenBanco(rows);
    expect(rev.enTransito).toBe(2328.86);
    expect(rev.bordeExcluido).toBe(false);
    expect(rev.ok).toBe(true); // 2328/16251 = 14 % < 15 %... apenas
  });

  it("los numeric-string de Supabase se convierten bien", () => {
    const [c] = resumenBanco([row({ airbnb_pago: "100.00", banco_recibio: "100.00", diferencia_acum: "0.00" })]);
    expect(c.airbnb).toBe(100);
    expect(c.ok).toBe(true);
  });

  it("marca no-ok si el en-tránsito supera el 15 % de lo pagado", () => {
    const [c] = resumenBanco([row({ airbnb_pago: 1000, banco_recibio: 700, diferencia_acum: -300 })]);
    expect(c.ok).toBe(false); // 30 % → investigar
  });

  it("ordena por iban y bancoTodoOk agrega el veredicto (datos reales jun 2026 ajustados)", () => {
    const rows: BancoRow[] = [
      row({ iban: "8920", cuenta: "BBVA · Alexander + Marechal", mes: 6, airbnb_pago: 44040.25, banco_recibio: 43164.18, diferencia_acum: -876.07, mes_borde: false, diferencia_acum_ajustada: -260.64 }),
      row({ iban: "8920", cuenta: "BBVA · Alexander + Marechal", mes: 1, airbnb_pago: 5618.15, banco_recibio: 5002.72, diferencia_acum: -615.43, mes_borde: true, diferencia_acum_ajustada: 0 }),
      row({ iban: "7165", mes: 1, airbnb_pago: 6434.41, banco_recibio: 9090.96, diferencia_acum: 2656.55, mes_borde: true, diferencia_acum_ajustada: 0 }),
      row({ iban: "7165", mes: 6, airbnb_pago: 59649.01, banco_recibio: 61977.87, diferencia_acum: 2328.86, mes_borde: false, diferencia_acum_ajustada: -327.69 }),
    ];
    const res = resumenBanco(rows);
    expect(res.map((c) => c.iban)).toEqual(["7165", "8920"]);
    expect(res[0].enTransito).toBe(-327.69);
    expect(res[1].enTransito).toBe(-260.64);
    expect(bancoTodoOk(res)).toBe(true);
  });
});
