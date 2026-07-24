import { describe, expect, it } from "vitest";
import { bancoTodoOk, resumenBanco, type BancoRow } from "../lib/cuadreBanco";

// Fixture con los números reales H1 2026 (Revolut 7165 = Nica+Jaco, BBVA 8920 = Alex+Mare).
const row = (o: Partial<BancoRow>): BancoRow => ({
  iban: "7165", cuenta: "Revolut · Nicasio + Jacobine", anio: 2026, mes: 1,
  airbnb_pago: 0, banco_recibio: 0, depositos: 0, diferencia_mes: 0, diferencia_acum: 0, ...o,
});

describe("resumenBanco", () => {
  it("agrega por cuenta y toma el en-tránsito del último mes", () => {
    const rows: BancoRow[] = [
      row({ mes: 1, airbnb_pago: 6434.41, banco_recibio: 9090.96, diferencia_acum: 2656.55 }),
      row({ mes: 6, airbnb_pago: 9817.30, banco_recibio: 10426.79, diferencia_acum: 2328.86 }),
    ];
    const [rev] = resumenBanco(rows);
    expect(rev.airbnb).toBeCloseTo(16251.71, 2);
    expect(rev.banco).toBeCloseTo(19517.75, 2);
    expect(rev.enTransito).toBe(2328.86); // el acumulado del último mes, no la suma
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

  it("ordena por iban y bancoTodoOk agrega el veredicto", () => {
    const rows: BancoRow[] = [
      row({ iban: "8920", cuenta: "BBVA · Alexander + Marechal", airbnb_pago: 44040.25, banco_recibio: 43164.18, diferencia_acum: -876.07 }),
      row({ iban: "7165", airbnb_pago: 59649.01, banco_recibio: 61977.87, diferencia_acum: 2328.86 }),
    ];
    const res = resumenBanco(rows);
    expect(res.map((c) => c.iban)).toEqual(["7165", "8920"]);
    expect(bancoTodoOk(res)).toBe(true);
  });
});
