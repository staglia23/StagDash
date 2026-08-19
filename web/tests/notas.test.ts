import { describe, expect, it } from "vitest";
import { autorCorto, cuandoCorto, resumenInbox, validarNota, type NotaRow } from "../lib/notas";

const nota = (o: Partial<NotaRow>): NotaRow => ({
  id: 1, texto: "x", autor: "info@stag-properties.com",
  creado_en: "2026-08-19T10:00:00Z", estado: "SIN_PROCESAR",
  resultado: null, procesado_en: null, ...o,
});

describe("validarNota", () => {
  it("acepta lo dictado y le quita los espacios de los bordes", () => {
    const v = validarNota("  patas para los muebles de baño, 47,98  ");
    expect(v.ok).toBe(true);
    expect(v.texto).toBe("patas para los muebles de baño, 47,98");
  });

  it("rechaza vacío y solo-espacios, que es lo que manda un botón tocado sin querer", () => {
    expect(validarNota("").ok).toBe(false);
    expect(validarNota("   \n  \n ").ok).toBe(false);
    expect(validarNota(null).ok).toBe(false);
    expect(validarNota(undefined).error).toMatch(/vacía/);
  });

  it("conserva los saltos de línea (dos gastos en una nota) pero aplasta los que sobran", () => {
    const v = validarNota("trona 47,11\n\n\n\npatas 47,98");
    expect(v.texto).toBe("trona 47,11\n\npatas 47,98");
  });

  it("recorta al mismo tope que la función SQL, para que no rechace después de guardar", () => {
    const v = validarNota("a".repeat(2500));
    expect(v.ok).toBe(true);
    expect(v.texto.length).toBe(2000);
  });
});

describe("cuandoCorto", () => {
  // Verano en Madrid = UTC+2. Las 22:30 UTC del 19/08 ya son las 00:30 del 20/08 en Madrid:
  // si la función razonara en UTC, una nota de la madrugada aparecería fechada el día
  // anterior y Stag buscaría el cargo en el extracto del día equivocado.
  const ahora = new Date("2026-08-19T12:00:00Z"); // 14:00 en Madrid

  it("dice la hora de Madrid, no la del servidor", () => {
    expect(cuandoCorto("2026-08-19T06:05:00Z", ahora)).toBe("hoy 08:05");
  });

  it("ayer es ayer en el calendario madrileño", () => {
    expect(cuandoCorto("2026-08-18T20:00:00Z", ahora)).toBe("ayer 22:00");
  });

  it("las 22:30 UTC ya son del día siguiente en Madrid", () => {
    const medianoche = new Date("2026-08-19T22:30:00Z"); // 20/08 00:30 en Madrid
    expect(cuandoCorto("2026-08-19T22:30:00Z", medianoche)).toBe("hoy 00:30");
    expect(cuandoCorto("2026-08-19T12:00:00Z", medianoche)).toBe("ayer 14:00");
  });

  it("más atrás muestra la fecha, y el año solo si no es el corriente", () => {
    expect(cuandoCorto("2026-08-14T09:05:00Z", ahora)).toBe("14/08 11:05");
    expect(cuandoCorto("2025-09-29T09:05:00Z", ahora)).toBe("29/09/2025");
  });

  it("una fecha ilegible no rompe la pantalla", () => {
    expect(cuandoCorto(null, ahora)).toBe("—");
    expect(cuandoCorto("no soy una fecha", ahora)).toBe("—");
  });
});

describe("resumenInbox", () => {
  it("cuenta lo que falta, no lo que hay: el total no le sirve de nada", () => {
    const r = resumenInbox([
      nota({ id: 1 }),
      nota({ id: 2 }),
      nota({ id: 3, estado: "REGISTRADA", resultado: "recobro #12", procesado_en: "2026-08-19T11:00:00Z" }),
      nota({ id: 4, estado: "DESCARTADA", resultado: "duplicada", procesado_en: "2026-08-19T11:00:00Z" }),
    ]);
    expect(r).toMatchObject({ sinProcesar: 2, registradas: 1, descartadas: 1, total: 4 });
    expect(r.texto).toBe("2 notas esperando que las registre");
  });

  it("bandeja vacía invita a dictar en vez de cantar un cero", () => {
    expect(resumenInbox([]).texto).toBe("dictá un gasto y lo registro");
    expect(resumenInbox([nota({})]).texto).toBe("1 nota esperando que la registre");
  });
});

describe("autorCorto", () => {
  it("se queda con lo de antes de la arroba", () => {
    expect(autorCorto("info@stag-properties.com")).toBe("info");
    expect(autorCorto(null)).toBe("—");
  });
});
