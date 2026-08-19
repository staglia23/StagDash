// Bandeja de entrada (migración 087): notas dictadas desde el móvil, sin procesar todavía.
// Lógica pura y testeada porque la usan la pantalla /anotar y el handler que guarda: si el
// recorte del texto se hiciera en dos sitios, el que valida y el que escribe podrían
// discrepar y la nota se rechazaría después de que Stag la creyera guardada.

export const LARGO_MAX = 2000;

export type NotaRow = {
  id: number;
  texto: string;
  autor: string;
  creado_en: string;
  estado: string;
  resultado: string | null;
  procesado_en: string | null;
  editada_en?: string | null;
  texto_previo?: string | null;
};

/**
 * ¿Se puede tocar todavía? Solo la propia y solo mientras no la haya procesado (088).
 *
 * Es el mismo criterio que aplican `f_nota_editar`/`f_nota_borrar` en la base: acá decide
 * si el botón se pinta, y allá si el cambio se acepta. La copia de la regla en el cliente
 * es cosmética a propósito — quien manda es la base, porque el navegador se puede trucar.
 */
export const puedeEditar = (n: NotaRow, email: string | null | undefined) =>
  n.estado === "SIN_PROCESAR" && !!email && n.autor === email;

export type NotaValidada = { ok: boolean; texto: string; error?: string };

/**
 * Limpia lo dictado y decide si vale la pena guardarlo.
 *
 * Conserva los saltos de línea (una nota puede traer dos gastos) pero aplasta los que
 * sobran, y recorta a LARGO_MAX — el mismo tope que la función SQL, para que el rechazo
 * ocurra acá y no después de darle a Guardar.
 */
export function validarNota(texto: string | null | undefined): NotaValidada {
  const limpio = (texto ?? "")
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((l) => l.trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
    .slice(0, LARGO_MAX);

  if (limpio === "") {
    return { ok: false, texto: "", error: "La nota está vacía: dictá o escribí algo antes de guardar." };
  }
  return { ok: true, texto: limpio };
}

const PARTES = new Intl.DateTimeFormat("es-ES", {
  timeZone: "Europe/Madrid",
  year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", minute: "2-digit", hourCycle: "h23",
});

function partesMadrid(d: Date) {
  const p = PARTES.formatToParts(d);
  const g = (t: string) => p.find((x) => x.type === t)?.value ?? "";
  return { y: Number(g("year")), m: Number(g("month")), d: Number(g("day")), hh: g("hour"), mm: g("minute") };
}

/**
 * "hoy 14:32" · "ayer 09:10" · "14/08 11:05" · "29/09/2025".
 *
 * El servidor de Vercel corre en UTC y el negocio vive en Madrid: una nota de las 23:30
 * hora española es "hoy", no "mañana". La distancia se mide en días de CALENDARIO madrileño
 * (no restando 24 h), para que un cambio de hora no convierta "ayer" en una fecha suelta.
 */
export function cuandoCorto(iso: string | null | undefined, ahora: Date): string {
  if (!iso) return "—";
  const f = new Date(iso);
  if (Number.isNaN(f.getTime())) return "—";

  const a = partesMadrid(f);
  const b = partesMadrid(ahora);
  const hora = `${a.hh}:${a.mm}`;
  const dias = Math.round(
    (Date.UTC(b.y, b.m - 1, b.d) - Date.UTC(a.y, a.m - 1, a.d)) / 86_400_000,
  );

  if (dias === 0) return `hoy ${hora}`;
  if (dias === 1) return `ayer ${hora}`;
  const dd = String(a.d).padStart(2, "0");
  const mm = String(a.m).padStart(2, "0");
  return a.y === b.y ? `${dd}/${mm} ${hora}` : `${dd}/${mm}/${a.y}`;
}

/** "info@stag-properties.com" → "info". Para no repetir el dominio en cada fila. */
export const autorCorto = (email: string | null | undefined) =>
  (email ?? "").split("@")[0] || "—";

export type ResumenInbox = {
  sinProcesar: number;
  registradas: number;
  descartadas: number;
  total: number;
  /** Frase para la portada y la cabecera: dice qué falta, no cuántas hay en total. */
  texto: string;
};

export function resumenInbox(rows: NotaRow[]): ResumenInbox {
  const sinProcesar = rows.filter((r) => r.estado === "SIN_PROCESAR").length;
  const registradas = rows.filter((r) => r.estado === "REGISTRADA").length;
  const descartadas = rows.filter((r) => r.estado === "DESCARTADA").length;

  const texto =
    sinProcesar === 0
      ? "dictá un gasto y lo registro"
      : sinProcesar === 1
        ? "1 nota esperando que la registre"
        : `${sinProcesar} notas esperando que las registre`;

  return { sinProcesar, registradas, descartadas, total: rows.length, texto };
}
