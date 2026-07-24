// /cuadre — integridad automática del modelo (roadmap 22/07): el motor se chequea a sí
// mismo comparando cada total por dos caminos. El control del CEO sobre el dashboard,
// visible todos los días. La definición de los chequeos vive en SQL (v_cuadre, migración
// 012); acá solo se renderiza. Estados siempre con icono + texto, nunca solo color.
import Link from "next/link";
import { lineaCuadre, normalizaCuadre, resumenCuadre, type CuadreRow } from "@/lib/cuadre";
import { bancoTodoOk, resumenBanco, type BancoRow } from "@/lib/cuadreBanco";
import { eur, fechaLarga, MESES } from "@/lib/format";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Freshness = { last_sync: string | null; costes_cargados_hasta: string | null };

const ICONO = { ok: "✓", alerta: "✖", info: "ℹ" } as const;
const CLASE = { ok: "ok", alerta: "critical", info: "" } as const;

export default async function Cuadre() {
  const [rowsRaw, freshArr, bancoRows] = await Promise.all([
    readView<CuadreRow>("v_cuadre", { order: { col: "orden" } }),
    readView<Freshness>("v_freshness"),
    readView<BancoRow>("v_cuadre_banco"),
  ]);
  const rows = normalizaCuadre(rowsRaw);
  const resumen = resumenCuadre(rows);
  const fresh = freshArr[0];
  const banco = resumenBanco(bancoRows);
  const periodo = bancoRows.length
    ? (() => {
        const ord = [...bancoRows].sort((a, b) => (a.anio - b.anio) || (a.mes - b.mes));
        const f = ord[0], l = ord[ord.length - 1];
        return `${MESES[f.mes]}–${MESES[l.mes]} ${l.anio}`;
      })()
    : "";

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

          {banco.length > 0 && (
            <section>
              <div className="section-title" style={{ marginTop: 26 }}>
                Conciliación bancaria · {periodo}
              </div>
              <p className={"titular cuadre-resumen " + (bancoTodoOk(banco) ? "pos" : "neg")}
                 style={{ fontSize: "1.05rem" }}>
                {bancoTodoOk(banco)
                  ? "✓ La plata que pagó Airbnb llegó al banco en las dos cuentas"
                  : "⚠ Una cuenta necesita revisión"}
              </p>
              <div className="cuadre-lista">
                {banco.map((c) => (
                  <div key={c.iban} className={"alerta cuadre-item " + (c.ok ? "ok" : "critical")}>
                    <span className={"cuadre-icono " + (c.ok ? "pos" : "neg")} aria-label={c.ok ? "cuadra" : "revisar"}>
                      {c.ok ? "✓" : "⚠"}
                    </span>
                    <div>
                      <div className="cuadre-titulo">{c.cuenta}</div>
                      <div className="cuadre-num">
                        Airbnb pagó {eur(c.airbnb)} · llegó al banco {eur(c.banco)}
                      </div>
                      <div className="alerta-msg">
                        {c.enTransito >= 0
                          ? `Diferencia +${eur(Math.abs(c.enTransito))}: en tránsito a favor (pagos de fin de período que aún no entraron el mes anterior).`
                          : `Diferencia −${eur(Math.abs(c.enTransito))}: pagos de fin de período que llegan al banco el mes siguiente.`}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              <p className="section-note">
                Las tres puntas: <strong>Guesty = Airbnb</strong> (arriba) y <strong>Airbnb = banco</strong>
                {" "}(acá). La diferencia es <strong>timing de pago</strong> (Airbnb transfiere ~5 días
                después del check-in), no plata perdida — mientras el "en tránsito" quede chico
                frente a lo que entra, está sano.
              </p>
            </section>
          )}
        </>
      )}
    </main>
  );
}
