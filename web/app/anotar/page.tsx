// /anotar — la bandeja de entrada (migraciones 087 y 088). La pantalla más simple del
// dashboard y la única que escribe: Stag dicta un gasto en el momento en que ocurre y queda
// guardado aunque no haya nadie procesándolo.
//
// El formulario vive en un client component (el micrófono necesita JavaScript) pero sigue
// siendo un <form> con POST nativo: sin JS se puede escribir y guardar igual.
//
// La nota NO imputa nada: cae en `notas_inbox` como SIN_PROCESAR y se convierte en recobro o
// event con revisión humana. Ese es el trato que hace segura la única escritura del repo.
// Mientras siga sin procesar, su autor puede corregirla o borrarla (088); una vez
// registrada se congela, porque entonces ya hay un número que salió de ella.
import type { Metadata } from "next";
import Link from "next/link";
import { NotaForm } from "@/components/NotaForm";
import { autorCorto, cuandoCorto, puedeEditar, resumenInbox, type NotaRow } from "@/lib/notas";
import { emailSesion, readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

// Esta pantalla se puede poner SOLA en la pantalla de inicio (icono de micrófono, su
// propio apple-icon.tsx). El título corto es el nombre que queda debajo del icono.
export const metadata: Metadata = {
  title: "Anotar — Stag",
  appleWebApp: { capable: true, title: "Anotar", statusBarStyle: "default" },
};

const ESTADO: Record<string, { icon: string; label: string; cls: string }> = {
  SIN_PROCESAR: { icon: "⏳", label: "Sin procesar", cls: "warn" },
  REGISTRADA: { icon: "✓", label: "Registrada", cls: "pos" },
  DESCARTADA: { icon: "✖", label: "Descartada", cls: "muted" },
};

const AVISOS: Record<string, { cls: string; texto: string }> = {
  guardada: { cls: "pos", texto: "✓ Guardada. La registro y te la marco acá." },
  corregida: { cls: "pos", texto: "✓ Corregida." },
  borrada: { cls: "pos", texto: "✓ Borrada. Como si no hubiera existido." },
  vacia: { cls: "neg", texto: "✖ No guardé nada: la nota estaba vacía." },
  tarde: {
    cls: "neg",
    texto: "✖ Esa nota ya no se puede tocar: o la registré ya, o no es tuya. Dictá una nueva diciendo qué había que corregir.",
  },
  fallo: {
    cls: "neg",
    texto: "✖ No se pudo guardar. Volvé a intentarlo; si sigue fallando, mandámela por chat para no perderla.",
  },
};

export default async function Anotar({
  searchParams,
}: {
  searchParams: { ok?: string; error?: string; editar?: string };
}) {
  // Orden explícito: la vista ya ordena, pero PostgREST envuelve la consulta y no hay
  // garantía de que el ORDER BY interno sobreviva. Lo último dictado va arriba.
  const [rows, email] = await Promise.all([
    readView<NotaRow>("v_notas_inbox", { order: { col: "creado_en", asc: false } }),
    emailSesion(),
  ]);
  const resumen = resumenInbox(rows);
  const ahora = new Date();

  // Modo corregir: solo si la nota sigue siendo suya y sin procesar. Si no, se ignora el
  // parámetro y se muestra el formulario normal — nunca se pre-carga texto ajeno.
  const idEditar = Number(searchParams.editar);
  const editando = Number.isFinite(idEditar)
    ? rows.find((n) => n.id === idEditar && puedeEditar(n, email))
    : undefined;

  const aviso = AVISOS[searchParams.ok ?? searchParams.error ?? ""];

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>
      <header className="header">
        <h1>{editando ? "Corregir nota" : "Anotar"}</h1>
        <div className="sub">
          {editando ? (
            <>Cambiá lo que haga falta y guardá. Queda la versión anterior, por si acaso.</>
          ) : (
            <>
              Contame un gasto o una aclaración en el momento en que pasa. Queda guardado acá
              hasta que lo convierta en gasto de un piso o en recobro a la dueña — <strong>una
              nota no mueve ningún número por sí sola</strong>.
            </>
          )}
        </div>
      </header>

      {!supabaseConfigured && (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      )}

      {aviso && (
        <p className={"aviso-nota " + aviso.cls} role={aviso.cls === "neg" ? "alert" : "status"}>
          {aviso.texto}
        </p>
      )}

      <NotaForm
        key={editando ? `editar-${editando.id}` : "nueva"}
        defaultValue={editando?.texto ?? ""}
        editandoId={editando?.id}
        // Al corregir no se enciende el micrófono solo: el texto ya está y lo dictado se
        // añadiría al final, que casi nunca es lo que uno quiere al arreglar una palabra.
        autoIniciar={!editando && !aviso}
      />

      {editando && (
        <p className="nota-cancelar">
          <Link href="/anotar">← Dejarla como estaba</Link>
        </p>
      )}

      <div className="section-title">
        Últimas notas
        {resumen.sinProcesar > 0 && (
          <span className="badge badge-sim">{resumen.sinProcesar} sin procesar</span>
        )}
      </div>

      {rows.length === 0 ? (
        <p className="notice">Todavía no hay ninguna nota. La primera que dictes aparece acá.</p>
      ) : (
        <ul className="recobros-lista">
          {rows.map((n) => {
            const e = ESTADO[n.estado] ?? { icon: "—", label: n.estado, cls: "muted" };
            const mia = puedeEditar(n, email);
            return (
              <li
                key={n.id}
                className={
                  "recobro" +
                  (n.estado === "SIN_PROCESAR" ? "" : " recobro-resuelto") +
                  (editando?.id === n.id ? " nota-editandose" : "")
                }
              >
                <div className="recobro-top">
                  <span className="recobro-fecha">{cuandoCorto(n.creado_en, ahora)}</span>
                  <span className={"recobro-estado " + e.cls}>{e.icon} {e.label}</span>
                </div>
                <div className="nota-texto">{n.texto}</div>
                <div className="recobro-meta">
                  <span className="chip-rec">{autorCorto(n.autor)}</span>
                  {n.editada_en && <span className="chip-rec">corregida</span>}
                  {n.resultado && <span className="nota-resultado">→ {n.resultado}</span>}
                  {mia && (
                    <span className="nota-acciones">
                      <Link className="nota-accion" href={`/anotar?editar=${n.id}`}>✏️ Corregir</Link>
                      <form action="/anotar/borrar" method="post">
                        <input type="hidden" name="id" value={n.id} />
                        <button type="submit" className="nota-accion nota-accion-borrar">
                          🗑 Borrar
                        </button>
                      </form>
                    </span>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      )}

      <p className="section-note">
        Podés corregir o borrar una nota <strong>mientras siga sin procesar</strong>. En cuanto
        la convierta en un gasto o en un recobro se congela: a partir de ahí hay un número que
        salió de ella, y cambiarla en silencio sería falsear de dónde vino.
      </p>
    </main>
  );
}
