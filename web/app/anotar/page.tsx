// /anotar — la bandeja de entrada (migración 087). La pantalla más simple del dashboard y
// la única que escribe: Stag dicta un gasto con el micrófono del teclado del iPhone en el
// momento en que ocurre, y queda guardado aunque no haya nadie procesándolo.
//
// Por qué un <form> clásico y no un client component: el POST nativo funciona sin
// JavaScript, sobrevive a una conexión mala en la calle y no puede perder lo escrito por un
// error de hidratación. Es el mismo patrón que /auth/signout.
//
// La nota NO imputa nada: cae en `notas_inbox` como SIN_PROCESAR y se convierte en recobro o
// event con revisión humana. Ese es el trato que hace segura la primera escritura del repo.
import Link from "next/link";
import { autorCorto, cuandoCorto, resumenInbox, type NotaRow } from "@/lib/notas";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

const ESTADO: Record<string, { icon: string; label: string; cls: string }> = {
  SIN_PROCESAR: { icon: "⏳", label: "Sin procesar", cls: "warn" },
  REGISTRADA: { icon: "✓", label: "Registrada", cls: "pos" },
  DESCARTADA: { icon: "✖", label: "Descartada", cls: "muted" },
};

export default async function Anotar({
  searchParams,
}: {
  searchParams: { ok?: string; error?: string };
}) {
  // Orden explícito: la vista ya ordena, pero PostgREST envuelve la consulta y no hay
  // garantía de que el ORDER BY interno sobreviva. Lo último dictado va arriba.
  const rows = await readView<NotaRow>("v_notas_inbox", { order: { col: "creado_en", asc: false } });
  const resumen = resumenInbox(rows);
  const ahora = new Date();
  const guardada = searchParams.ok === "1";
  const error = searchParams.error;

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>
      <header className="header">
        <h1>Anotar</h1>
        <div className="sub">
          Contame un gasto o una aclaración en el momento en que pasa. Queda guardado acá
          hasta que lo convierta en gasto de un piso o en recobro a la dueña — <strong>una
          nota no mueve ningún número por sí sola</strong>.
        </div>
      </header>

      {!supabaseConfigured && (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      )}

      {guardada && (
        <p className="aviso-nota pos" role="status">✓ Guardada. La registro y te la marco acá.</p>
      )}
      {error === "vacia" && (
        <p className="aviso-nota neg" role="alert">✖ No guardé nada: la nota estaba vacía.</p>
      )}
      {error === "fallo" && (
        <p className="aviso-nota neg" role="alert">
          ✖ No se pudo guardar. Volvé a intentarlo; si sigue fallando, mandámela por chat
          para no perderla.
        </p>
      )}

      <form action="/anotar/guardar" method="post" className="card nota-form">
        <label className="nota-label" htmlFor="texto">¿Qué anotamos?</label>
        <textarea
          id="texto"
          name="texto"
          className="nota-input"
          rows={5}
          maxLength={2000}
          required
          placeholder={
            "Ej.: patas para los muebles de baño de Jacobine, 47,98 €, compradas hoy en " +
            "Amazon con la tarjeta de Samavi — es gasto de mi madre, no lo asume Samavi."
          }
        />
        <button type="submit" className="nota-btn">Guardar nota</button>
        <p className="nota-tip">
          🎤 Tocá el micrófono del teclado del iPhone y hablá: lo transcribe el propio
          teléfono. Decí <strong>qué es</strong>, <strong>cuánto</strong>, <strong>de qué
          piso</strong>, <strong>con qué tarjeta</strong> y <strong>de quién es el gasto</strong>.
          Si algo falta, te lo pregunto después.
        </p>
      </form>

      <div className="section-title">
        Últimas notas
        {resumen.sinProcesar > 0 && <span className="badge badge-sim">{resumen.sinProcesar} sin procesar</span>}
      </div>

      {rows.length === 0 ? (
        <p className="notice">
          Todavía no hay ninguna nota. La primera que dictes aparece acá.
        </p>
      ) : (
        <ul className="recobros-lista">
          {rows.map((n) => {
            const e = ESTADO[n.estado] ?? { icon: "—", label: n.estado, cls: "muted" };
            return (
              <li key={n.id} className={"recobro" + (n.estado === "SIN_PROCESAR" ? "" : " recobro-resuelto")}>
                <div className="recobro-top">
                  <span className="recobro-fecha">{cuandoCorto(n.creado_en, ahora)}</span>
                  <span className={"recobro-estado " + e.cls}>{e.icon} {e.label}</span>
                </div>
                <div className="nota-texto">{n.texto}</div>
                <div className="recobro-meta">
                  <span className="chip-rec">{autorCorto(n.autor)}</span>
                  {n.resultado && <span className="nota-resultado">→ {n.resultado}</span>}
                </div>
              </li>
            );
          })}
        </ul>
      )}

      <p className="section-note">
        La bandeja no se edita ni se borra: si te equivocaste, dictá otra nota corrigiendo la
        anterior. Así queda el rastro de qué se dijo y cuándo, que es lo que después justifica
        un anticipo frente a Confisic.
      </p>
    </main>
  );
}
