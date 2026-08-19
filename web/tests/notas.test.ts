import { describe, expect, it } from "vitest";
import {
  autorCorto, componerDictado, corregirDictado, cuandoCorto, puedeEditar,
  resumenInbox, unirSegmentos, validarNota, type NotaRow,
} from "../lib/notas";

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

// Los cuatro trozos que devolvió el reconocedor en la PRIMERA prueba real de Stag
// (19/08/2026, captura del iPhone). El texto salía "pruebaPara… viejaLa propietariaY".
const PRUEBA_REAL = [
  "Quiero hacer una prueba",
  "Para poner un gasto de 100 € de mantenimiento en Jacob INE se lo vamos a imputar a mi vieja",
  "La propietaria",
  "Y se pagó con la tarjeta de Revolut Business",
];

describe("unirSegmentos", () => {
  it("nunca pega dos frases sin separador (el bug de la primera prueba)", () => {
    const t = unirSegmentos(PRUEBA_REAL);
    expect(t).not.toMatch(/pruebaPara|viejaLa|propietariaY/);
    expect(t).toContain("una prueba. Para poner");
  });

  it("baja la mayúscula del conector que quedó en medio de la frase", () => {
    expect(unirSegmentos(["La propietaria", "Y se pagó con la tarjeta"]))
      .toBe("La propietaria y se pagó con la tarjeta");
  });

  it("no parte una frase larga en dos: un trozo que sigue en minúscula se une con espacio", () => {
    expect(unirSegmentos(["Compré unas patas", "para el mueble del baño"]))
      .toBe("Compré unas patas para el mueble del baño");
  });

  it("no duplica el punto si el trozo anterior ya venía puntuado", () => {
    expect(unirSegmentos(["Compré las patas.", "Las pagué con Revolut"]))
      .toBe("Compré las patas. Las pagué con Revolut");
  });

  it("aguanta trozos vacíos y espacios sueltos", () => {
    expect(unirSegmentos(["  ", "Hola qué tal", "   "])).toBe("Hola qué tal");
    expect(unirSegmentos([])).toBe("");
  });
});

describe("corregirDictado", () => {
  it("arregla el nombre del piso que el dictado parte en dos", () => {
    expect(corregirDictado("gasto en Jacob INE")).toContain("Jacobine");
    expect(corregirDictado("gasto en Jacobin")).toContain("Jacobine");
  });

  it("escribe bien el resto del vocabulario de la casa", () => {
    const t = corregirDictado("pagué con revolut de sama vi y lo vi en price labs y en gesty");
    expect(t).toContain("Revolut");
    expect(t).toContain("Samavi");
    expect(t).toContain("PriceLabs");
    expect(t).toContain("Guesty");
  });

  it("pasa los euros hablados a cifra", () => {
    expect(corregirDictado("son 100 euros")).toBe("Son 100 €");
    expect(corregirDictado("son 47 con 98 euros")).toBe("Son 47,98 €");
  });

  it("es idempotente: aplicarlo dos veces no cambia nada", () => {
    const una = corregirDictado("gasto de 47 con 98 euros en Jacob INE");
    expect(corregirDictado(una)).toBe(una);
  });
});

describe("componerDictado", () => {
  it("reconstruye la nota real de la captura, limpia y legible", () => {
    expect(componerDictado("", PRUEBA_REAL, "")).toBe(
      "Quiero hacer una prueba. Para poner un gasto de 100 € de mantenimiento en Jacobine " +
      "se lo vamos a imputar a mi vieja. La propietaria y se pagó con la tarjeta de Revolut Business",
    );
  });

  it("respeta lo que ya estaba escrito y le añade lo dictado detrás", () => {
    expect(componerDictado("Trona 47,11.", ["Patas del baño"], ""))
      .toBe("Trona 47,11. Patas del baño");
  });

  it("deja crudo lo que todavía se está oyendo: se reescribe en el siguiente golpe", () => {
    expect(componerDictado("", ["Compré unas patas"], "y una tro"))
      .toBe("Compré unas patas y una tro");
  });
});

describe("puedeEditar", () => {
  const mia = nota({ autor: "info@stag-properties.com" });

  it("la propia y sin procesar se puede corregir", () => {
    expect(puedeEditar(mia, "info@stag-properties.com")).toBe(true);
  });

  it("una nota ya registrada se congela: hay un número que salió de ella", () => {
    const registrada = nota({ estado: "REGISTRADA", resultado: "recobro #12", procesado_en: "2026-08-19T11:00:00Z" });
    expect(puedeEditar(registrada, "info@stag-properties.com")).toBe(false);
  });

  it("la nota de otro no se toca, ni con sesión válida", () => {
    expect(puedeEditar(nota({ autor: "fede@ejemplo.com" }), "info@stag-properties.com")).toBe(false);
  });

  it("sin sesión conocida no se pinta ningún botón", () => {
    expect(puedeEditar(mia, null)).toBe(false);
    expect(puedeEditar(mia, "")).toBe(false);
  });
});

describe("autorCorto", () => {
  it("se queda con lo de antes de la arroba", () => {
    expect(autorCorto("info@stag-properties.com")).toBe("info");
    expect(autorCorto(null)).toBe("—");
  });
});
