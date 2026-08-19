import { describe, it, expect } from "vitest";
import {
  agrupar, resumen, porSanear, clave, esCobroReal, SIN_CLASIFICAR, type CobroRow,
} from "../lib/cobros";

// Fixture con datos REALES de v_cobros (19/08/2026). Incluye a propósito los tres casos que
// rompen una torta ingenua: un Booking cobrado en efectivo, un cobro sin nota y un PENDING.
const mk = (o: Partial<CobroRow>): CobroRow => ({
  codigo: "1A_NICA", confirmation_code: "X", checkin_local: "2026-06-01",
  estado_reserva: "confirmed", canal: "Airbnb", importe: 100, estado_pago: "SUCCEEDED",
  fecha_pago: "2026-06-01", metodo: "Pasarela Airbnb", familia: "PASARELA",
  nota: null, destino: "AIRBNB", entra_en_banco_es: true, ...o,
});

const ROWS: CobroRow[] = [
  mk({ confirmation_code: "HM1", importe: 1000 }),
  mk({ confirmation_code: "HM2", importe: 500, codigo: "3G_MARE" }),
  // Booking cobrado EN EFECTIVO: canal y forma de cobro son ejes distintos
  mk({ confirmation_code: "BC-68wENnWVl", canal: "Booking.com", importe: 1054.52,
       metodo: "Cash", familia: "EFECTIVO", nota: "Cash Claudio",
       destino: "EFECTIVO", entra_en_banco_es: false }),
  // Transferencia a Galicia: no aparece en el banco español
  mk({ confirmation_code: "GY-jtnC3pfA", canal: "Directa", importe: 329.30, codigo: "3G_MARE",
       metodo: "Bank transfer", familia: "TRANSFERENCIA", nota: "CC USD Banco Galicia",
       destino: "GALICIA-USD", entra_en_banco_es: false }),
  // Transferencia a Revolut: sí aparece
  mk({ confirmation_code: "BC-qpY7JQDO7", canal: "Booking.com", importe: 882.48,
       metodo: "Bank transfer", familia: "TRANSFERENCIA", nota: "Revolut Business",
       destino: "REVOLUT", entra_en_banco_es: true }),
  // Cobrado pero SIN NOTA: no se puede saber si aparece en el banco
  mk({ confirmation_code: "GY-pbc8LdUs", canal: "Directa", importe: 75, codigo: "4B_ALEX",
       metodo: "Cash", familia: "EFECTIVO", nota: null,
       destino: "EFECTIVO", entra_en_banco_es: null }),
  // Cobro previsto: NO entró todavía
  mk({ confirmation_code: "GY-LUsayzD9", canal: "Directa", importe: 1217.07, codigo: "4B_ALEX",
       estado_pago: "PENDING", metodo: "Cobro previsto (sin identificar)", familia: "PREVISTO",
       destino: null, entra_en_banco_es: null }),
  // Reserva cancelada: tampoco cuenta
  mk({ confirmation_code: "GY-cancel", estado_reserva: "canceled", importe: 999,
       estado_pago: "CANCELLED" }),
];

const COBRADO = 1000 + 500 + 1054.52 + 329.30 + 882.48 + 75; // 3841,30

describe("qué cuenta como cobro", () => {
  it("solo suma pagos SUCCEEDED de reservas vivas", () => {
    expect(ROWS.filter(esCobroReal)).toHaveLength(6);
    expect(resumen(ROWS).total).toBeCloseTo(COBRADO, 2);
  });

  it("un PENDING no es un cobro: va aparte y nunca al total", () => {
    const r = resumen(ROWS);
    expect(r.previsto).toBeCloseTo(1217.07, 2);
    expect(r.nPrevisto).toBe(1);
    expect(r.total).toBeCloseTo(COBRADO, 2);
  });

  it("una reserva cancelada no cuenta aunque tenga pago", () => {
    expect(resumen(ROWS).total).not.toContain(999);
    expect(agrupar(ROWS, "canal").flatMap((g) => g.filas)
      .some((f) => f.confirmation_code === "GY-cancel")).toBe(false);
  });
});

describe("los ejes son independientes (la trampa que motivó todo esto)", () => {
  it("un Booking cobrado en efectivo cuenta UNA vez en cada eje, no dos", () => {
    const canal = agrupar(ROWS, "canal");
    const familia = agrupar(ROWS, "familia");
    const bk = canal.find((g) => g.clave === "Booking.com")!;
    const ef = familia.find((g) => g.clave === "Efectivo")!;
    expect(bk.filas.some((f) => f.confirmation_code === "BC-68wENnWVl")).toBe(true);
    expect(ef.filas.some((f) => f.confirmation_code === "BC-68wENnWVl")).toBe(true);
    // y el total no se infla en ninguno de los dos
    expect(canal.reduce((a, g) => a + g.total, 0)).toBeCloseTo(COBRADO, 2);
    expect(familia.reduce((a, g) => a + g.total, 0)).toBeCloseTo(COBRADO, 2);
  });

  it("los porcentajes de cada eje suman 1", () => {
    for (const eje of ["canal", "familia", "destino"] as const) {
      const s = agrupar(ROWS, eje).reduce((a, g) => a + g.pct, 0);
      expect(s).toBeCloseTo(1, 10);
    }
  });
});

describe("orden y clasificación", () => {
  it("respeta el orden fijo por entidad, no el ranking por importe", () => {
    expect(agrupar(ROWS, "canal").map((g) => g.clave))
      .toEqual(["Airbnb", "Booking.com", "Directa"]);
  });

  it("«Sin clasificar» va siempre al final aunque pese más que otra categoría", () => {
    const rows = [
      mk({ importe: 10, canal: "Directa" }),
      mk({ importe: 5000, canal: "", destino: null }),
    ];
    const g = agrupar(rows, "canal");
    expect(g[g.length - 1].clave).toBe(SIN_CLASIFICAR);
  });

  it("sin destino, la fila cae en Sin clasificar y no se inventa una categoría", () => {
    expect(clave(mk({ destino: null }), "destino")).toBe(SIN_CLASIFICAR);
  });

  it("traduce la familia de la base a la etiqueta que ve Stag", () => {
    expect(clave(mk({ familia: "TRANSFERENCIA" }), "familia")).toBe("Transferencia");
    expect(clave(mk({ familia: "PREVISTO" }), "familia")).toBe(SIN_CLASIFICAR);
  });
});

describe("lo que hay que sanear", () => {
  it("cuenta como pendiente el cobro sin nota, no el que sí la tiene", () => {
    const r = resumen(ROWS);
    expect(r.nSinNota).toBe(1);
    expect(r.sinNota).toBeCloseTo(75, 2);
  });

  it("porSanear lista solo los cobrados sin nota, de mayor a menor", () => {
    const s = porSanear([
      ...ROWS,
      mk({ confirmation_code: "GY-ZBqRdqsg", importe: 440, familia: "EFECTIVO",
           metodo: "Cash", nota: null, destino: null, entra_en_banco_es: null }),
    ]);
    expect(s.map((r) => r.confirmation_code)).toEqual(["GY-ZBqRdqsg", "GY-pbc8LdUs"]);
  });

  it("el dinero fuera del banco español suma efectivo + Galicia, no Revolut", () => {
    // 1.054,52 (efectivo) + 329,30 (Galicia) = 1.383,82; los 882,48 de Revolut NO entran
    expect(resumen(ROWS).fueraDeBanco).toBeCloseTo(1383.82, 2);
  });
});
