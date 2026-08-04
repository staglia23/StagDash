import { describe, expect, it } from "vitest";
import {
  deltaStly, titularPrecios, totalesPrecios, type ResumenPrecioRow,
} from "../lib/precios";

// Fixture con los datos REALES del primer sync (v_pricelabs_resumen, 05/08/2026).
// Supabase devuelve los numeric como string: el fixture lo replica a propósito.
const REAL: ResumenPrecioRow[] = [
  { codigo: "1A_JACO", noches_baratas: "9", euros_sobre_la_mesa: "345", dias_primera: "6",
    reservadas: "22", bloqueadas: "3", huerfanas: "2", libres: "3",
    ocupacion: "0.7333", adr_reservado: "175.07", stly_ocupacion: "0.9000", stly_adr: "116.86",
    refreshed_at: "2026-08-04 09:28:07+00" },
  { codigo: "3G_MARE", noches_baratas: "7", euros_sobre_la_mesa: "104", dias_primera: "7",
    reservadas: "19", bloqueadas: "2", huerfanas: "2", libres: "7",
    ocupacion: "0.6333", adr_reservado: "116.00", stly_ocupacion: null, stly_adr: null,
    refreshed_at: "2026-08-04 09:28:01+00" },
  { codigo: "4B_ALEX", noches_baratas: "2", euros_sobre_la_mesa: "83", dias_primera: "56",
    reservadas: "23", bloqueadas: "0", huerfanas: "0", libres: "7",
    ocupacion: "0.7667", adr_reservado: "140.79", stly_ocupacion: null, stly_adr: null,
    refreshed_at: "2026-08-04 09:27:42+00" },
  { codigo: "1A_NICA", noches_baratas: "4", euros_sobre_la_mesa: "76", dias_primera: "7",
    reservadas: "23", bloqueadas: "0", huerfanas: "2", libres: "5",
    ocupacion: "0.7667", adr_reservado: "159.33", stly_ocupacion: "0.8000", stly_adr: "147.31",
    refreshed_at: "2026-08-04 09:28:01+00" },
];

describe("totalesPrecios", () => {
  it("suma los numeric-como-string en vez de concatenarlos", () => {
    const t = totalesPrecios(REAL);
    expect(t.noches).toBe(22);
    expect(t.euros).toBe(608);          // 345 + 104 + 83 + 76
    expect(t.bloqueadas).toBe(5);
    expect(t.huerfanas).toBe(6);
  });

  it("la primera noche accionable es la más cercana de todos los pisos", () => {
    expect(totalesPrecios(REAL).diasPrimera).toBe(6);
  });

  it("sin oportunidades no inventa una fecha", () => {
    const limpio = REAL.map((r) => ({
      ...r, noches_baratas: "0", euros_sobre_la_mesa: "0", dias_primera: null,
    }));
    const t = totalesPrecios(limpio);
    expect(t.euros).toBe(0);
    expect(t.diasPrimera).toBeNull();
  });
});

describe("deltaStly", () => {
  it("Jacobine va 16,7 puntos por debajo del año pasado", () => {
    expect(deltaStly(REAL[0])!).toBeCloseTo(-0.1667, 4);
  });

  it("devuelve null cuando el piso no se gestionaba el año pasado (arreglo de la 064)", () => {
    // sin este guard, 'no gestionábamos' se leía como '0 % de ocupación'
    expect(deltaStly(REAL[1])).toBeNull();
    expect(deltaStly(REAL[2])).toBeNull();
  });
});

describe("titularPrecios", () => {
  it("dice cuántas noches y cuándo es la primera", () => {
    expect(titularPrecios(totalesPrecios(REAL)))
      .toBe("22 noches libres están por debajo del precio recomendado — la primera en 6 días");
  });

  it("singular y 'hoy'/'mañana' en vez de 'en 0 días'", () => {
    const base = totalesPrecios(REAL);
    expect(titularPrecios({ ...base, noches: 1, diasPrimera: 0 }))
      .toBe("1 noche libre está por debajo del precio recomendado — la primera es hoy");
    expect(titularPrecios({ ...base, noches: 1, diasPrimera: 1 }))
      .toContain("mañana");
  });

  it("cuando no hay nada que revisar lo dice sin alarmar", () => {
    expect(titularPrecios({ noches: 0, euros: 0, bloqueadas: 0, huerfanas: 0, diasPrimera: null }))
      .toBe("Ninguna noche libre está por debajo del precio recomendado.");
  });
});
