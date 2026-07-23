// /cuadre — integridad automática del modelo (roadmap 22/07): el motor se chequea a sí
// mismo comparando cada total por dos caminos. El control del CEO sobre el dashboard,
// visible todos los días. La definición de los chequeos vive en SQL (v_cuadre, migración
// 012); acá solo se renderiza. Estados siempre con icono + texto, nunca solo color.
import Link from "next/link";
import { lineaCuadre, normalizaCuadre, resumenCuadre, type CuadreRow } from "@/lib/cuadre";
import { fechaLarga } from "@/lib/format";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Freshness = { last_sync: string | null; costes_cargados_hasta: string | null };

const ICONO = { ok: "✓", alerta: "✖", info: "ℹ" } as const;
const CLASE = { ok: "ok", alerta: "critical", info: "" } as const;

export default async function Cuadre() {
  const [rowsRaw, freshArr] = await Promise.all([
    readView<CuadreRow>("v_cuadre", { order: { col: "orden" } }),
    readView<Freshness>("v_freshness"),
  ]);
  const rows = normalizaCuadre(rowsRaw);
  const resumen = resumenCuadre(rows);
  const fresh = freshArr[0];

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>
      <header className="header">
        <h1>Cuadre</h1>
        <div className="sub">
          El modelo se verifica solo: cada total, calculado por dos caminos. Si algo no
          cuadra acá, no te fíes del resto hasta que se arregle.
        </div>
        <div className="stamp">Verificado con el dato de las {fechaLarga(fresh?.last_sync)}</div>
      </header>

      {!supabaseConfigured && (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      )}

      {rows.length === 0 ? (
        <p className="titular">Sin datos de cuadre — ¿la migración 012 ya está aplicada?</p>
      ) : (
        <>
          <p className={"titular cuadre-resumen " + (resumen.alertas === 0 ? "pos" : "neg")}>
            {resumen.texto}
          </p>

          <div className="cuadre-lista">
            {rows.map((r) => (
              <div key={r.chequeo} className={`alerta ${CLASE[r.estado]} cuadre-item`}>
                <span className={"cuadre-icono " + (r.estado === "alerta" ? "neg" : r.estado === "ok" ? "pos" : "")}
                  aria-label={r.estado === "ok" ? "cuadra" : r.estado === "alerta" ? "no cuadra" : "información"}>
                  {ICONO[r.estado]}
                </span>
                <div>
                  <div className="cuadre-titulo">{r.titulo}</div>
                  <div className="cuadre-num">{lineaCuadre(r)}</div>
                  <div className="alerta-msg">{r.detalle}</div>
                </div>
              </div>
            ))}
          </div>

          <p className="section-note">
            Todo lo de arriba es <strong>real</strong> (devengado, sobre el dato sincronizado
            de Guesty y los costes cargados). Las tolerancias marcadas como redondeo son
            céntimos que aparecen al redondear por propiedad y mes; cualquier diferencia
            mayor enciende el chequeo.
          </p>
        </>
      )}
    </main>
  );
}
