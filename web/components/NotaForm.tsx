"use client";
// Formulario de /anotar (087) con dictado en la propia pantalla (088).
//
// Sigue siendo un <form> nativo que hace POST: si el JavaScript falla, el micrófono no
// aparece pero escribir y guardar funciona igual. El dictado es una mejora encima, no la
// única vía — es lo que hace que se pueda usar en la calle con mala conexión.
//
// Sobre el "que arranque solo": iOS NO deja que una página abra el micrófono sin un toque
// del usuario, y al llegar desde otra pantalla el gesto ya no cuenta. Así que el arranque
// automático se intenta SOLO a partir de la segunda vez: la primera hay que tocar "Hablar"
// y conceder el permiso. Es deliberado — si el intento automático hiciera saltar el permiso
// de la nada, un "No permitir" reflejo dejaría el micrófono bloqueado para el sitio y
// recuperarlo exige irse a Ajustes. Se recuerda que hubo permiso cuando llega la primera
// transcripción, que es la única prueba de que el micrófono funcionó de verdad.
import { useCallback, useEffect, useRef, useState } from "react";
import { componerDictado, corregirDictado } from "@/lib/notas";

type Alternativa = { transcript: string };
type Resultado = ArrayLike<Alternativa> & { isFinal: boolean };
type EventoVoz = { resultIndex: number; results: ArrayLike<Resultado> };
type Reconocedor = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  start: () => void;
  stop: () => void;
  onresult: ((e: EventoVoz) => void) | null;
  onend: (() => void) | null;
  onerror: ((e: { error?: string }) => void) | null;
};
type ConstructorVoz = new () => Reconocedor;

function reconocedorDisponible(): ConstructorVoz | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as {
    SpeechRecognition?: ConstructorVoz;
    webkitSpeechRecognition?: ConstructorVoz;
  };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}

// Marca de "acá ya hubo dictado con permiso". localStorage puede tirar (modo privado):
// si falla, simplemente nunca arranca solo y queda el botón, que siempre funciona.
const CLAVE_VOZ = "stag:voz-ok";
const huboPermiso = () => {
  try { return window.localStorage.getItem(CLAVE_VOZ) === "1"; } catch { return false; }
};
const recordarPermiso = () => {
  try { window.localStorage.setItem(CLAVE_VOZ, "1"); } catch { /* modo privado */ }
};

export function NotaForm({
  defaultValue = "",
  editandoId,
  autoIniciar = false,
}: {
  defaultValue?: string;
  editandoId?: number;
  autoIniciar?: boolean;
}) {
  const [texto, setTexto] = useState(defaultValue);
  const [escuchando, setEscuchando] = useState(false);
  const [hayVoz, setHayVoz] = useState(false);
  const [avisoVoz, setAvisoVoz] = useState<string | null>(null);

  const recRef = useRef<Reconocedor | null>(null);
  const baseRef = useRef("");            // lo que ya había escrito cuando empezó a hablar
  const finalesRef = useRef<string[]>([]); // las frases que el reconocedor ya dio por cerradas

  // El texto vive en un ref además del estado para que `arrancar` no dependa de él: si
  // dependiera, cambiaría de identidad con cada palabra dictada, el efecto de abajo se
  // volvería a ejecutar y su limpieza cortaría el micrófono a media frase.
  const textoRef = useRef(texto);
  useEffect(() => { textoRef.current = texto; }, [texto]);

  const arrancar = useCallback((silencioso: boolean) => {
    const Voz = reconocedorDisponible();
    if (!Voz) return;
    if (recRef.current) return;   // ya está escuchando

    const rec = new Voz();
    rec.lang = "es-ES";
    rec.continuous = true;        // iOS lo ignora y corta solo tras un silencio
    rec.interimResults = true;

    baseRef.current = textoRef.current.trimEnd();
    finalesRef.current = [];

    rec.onresult = (e) => {
      recordarPermiso();  // llegó audio transcrito: el permiso está concedido
      let provisional = "";
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        const t = r[0]?.transcript ?? "";
        // Las frases cerradas se guardan SUELTAS, no concatenadas: el separador entre dos
        // lo decide componerDictado. Pegarlas acá fue el bug de "pruebaPara".
        if (r.isFinal) finalesRef.current.push(t);
        else provisional += t;
      }
      setTexto(componerDictado(baseRef.current, finalesRef.current, provisional));
    };
    rec.onend = () => {
      recRef.current = null;
      setEscuchando(false);
    };
    rec.onerror = (e) => {
      recRef.current = null;
      setEscuchando(false);
      // "no-speech"/"aborted" son ruido normal (silencio, o parar a mano): no se avisa.
      if (silencioso || e.error === "no-speech" || e.error === "aborted") return;
      setAvisoVoz(
        e.error === "not-allowed"
          ? "El micrófono está bloqueado para este sitio. Se activa en Ajustes → Safari, o usá el micrófono del teclado."
          : "El dictado se cortó. Probá otra vez o usá el micrófono del teclado.",
      );
    };

    try {
      rec.start();
      recRef.current = rec;
      setEscuchando(true);
      setAvisoVoz(null);
    } catch {
      // iOS tira cuando no hay gesto del usuario: se queda el botón, sin cartel.
      recRef.current = null;
      setEscuchando(false);
    }
  }, []);

  const parar = useCallback(() => {
    recRef.current?.stop();
    recRef.current = null;
    setEscuchando(false);
  }, []);

  useEffect(() => {
    setHayVoz(reconocedorDisponible() !== null);
    // Al salir de la pantalla, el micrófono se apaga sí o sí.
    return () => recRef.current?.stop();
  }, []);

  // Arranque automático: una sola vez al entrar, solo si la pantalla no viene de guardar
  // (si no, el micrófono se encendería solo después de cada nota) y solo si ya hubo un
  // dictado con permiso concedido en este teléfono.
  const yaIntentado = useRef(false);
  useEffect(() => {
    if (!autoIniciar || yaIntentado.current || !huboPermiso()) return;
    yaIntentado.current = true;
    arrancar(true);
  }, [autoIniciar, arrancar]);

  return (
    <form action="/anotar/guardar" method="post" className="card nota-form">
      {editandoId != null && <input type="hidden" name="id" value={editandoId} />}

      {hayVoz && (
        <>
          <button
            type="button"
            className={"nota-voz" + (escuchando ? " nota-voz-on" : "")}
            onClick={() => (escuchando ? parar() : arrancar(false))}
            aria-pressed={escuchando}
          >
            <span aria-hidden="true">{escuchando ? "⏹" : "🎤"}</span>
            {escuchando ? "Detener y revisar" : "Hablar"}
          </button>
          <p className={"nota-voz-estado " + (escuchando ? "warn" : "muted")} role="status">
            {escuchando
              ? "● Escuchando… hablá tranquilo; se escribe abajo."
              : "Tocá Hablar y dictá. También podés escribir a mano."}
          </p>
        </>
      )}
      {avisoVoz && <p className="nota-voz-estado neg" role="alert">✖ {avisoVoz}</p>}

      <label className="nota-label" htmlFor="texto">
        {editandoId != null ? "Corregí la nota" : "¿Qué anotamos?"}
      </label>
      <textarea
        id="texto"
        name="texto"
        className="nota-input"
        rows={5}
        maxLength={2000}
        required
        value={texto}
        onChange={(e) => setTexto(e.target.value)}
        placeholder={
          "Ej.: patas para los muebles de baño de Jacobine, 47,98 €, compradas hoy en " +
          "Amazon con la tarjeta de Samavi — es gasto de mi madre, no lo asume Samavi."
        }
      />
      <button type="submit" className="nota-btn">
        {editandoId != null ? "Guardar la corrección" : "Guardar nota"}
      </button>
      {texto.trim() !== "" && (
        <div className="nota-secundarios">
          <button
            type="button"
            className="nota-btn-sec"
            onClick={() => setTexto((t) => corregirDictado(t))}
          >
            ✨ Ordenar el texto
          </button>
          <button type="button" className="nota-btn-sec" onClick={() => setTexto("")}>
            Borrar y empezar de nuevo
          </button>
        </div>
      )}
      {editandoId == null && (
        <p className="nota-tip">
          Decí <strong>qué es</strong>, <strong>cuánto</strong>, <strong>de qué piso</strong>,{" "}
          <strong>con qué tarjeta</strong> y <strong>de quién es el gasto</strong>. Si algo
          falta, te lo pregunto después. {hayVoz ? "Si el botón de Hablar no responde, también sirve el micrófono del teclado." : "Tocá el cuadro y usá el micrófono del teclado del iPhone."}
        </p>
      )}
    </form>
  );
}
