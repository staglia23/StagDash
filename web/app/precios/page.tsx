// Precios · próximos 60 días (migración 072). La pantalla que faltaba: PriceLabs venía
// sincronizando desde el 02/08 y el dato no se mostraba en ninguna página.
//
// La pregunta que responde: "¿estoy dejando plata sobre la mesa?". PriceLabs recomienda un
// precio por noche; los suelos manuales lo pisan. Cuando el suelo queda por debajo de la
// recomendación en una noche que sigue libre, esa noche se vende más barata de lo que el
// mercado admitiría. Todo lo de acá es FORWARD: nunca toca el P&L devengado.
import Link from "next/link";
import { MercadoChart } from "@/components/MercadoChart";
import { PaceYoy } from "@/components/PaceYoy";
import { propColor } from "@/lib/colors";
import { eur, fechaLarga, MESES, pct, pp } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import {
  deltaStly, titularPrecios, totalesPrecios,
  type OportunidadRow, type ResumenPrecioRow,
} from "@/lib/precios";
import { readView } from "@/lib/supabase";
import {
  filasPace, resumenMercadoSolo, serieMercado, titularPace,
  type MercadoRow, type PaceRow,
} from "@/lib/yoy";

export const dynamic = "force-dynamic";

type Freshness = { last_sync: string | null; pricelabs_last_run?: string | null };

const fechaCorta = (iso: string) => {
  const [, m, d] = iso.split("-");
  return `${Number(d)} ${MESES[Number(m)].toLowerCase()}`;
};

export default async function Precios() {
  const [resumen, oportunidades, freshArr, paceAll, mercadoAll] = await Promise.all([
    readView<ResumenPrecioRow>("v_pricelabs_resumen"),
    readView<OportunidadRow>("v_pricelabs_oportunidades"),
    readView<Freshness>("v_freshness"),
    readView<PaceRow>("v_pace_yoy"),
    readView<MercadoRow>("v_pricelabs_mercado", { order: { col: "mes" } }),
  ]);

  const t = totalesPrecios(resumen);
  const fresh = freshArr[0];
  const porEuros = [...resumen].sort(
    (a, b) => Number(b.euros_sobre_la_mesa) - Number(a.euros_sobre_la_mesa),
  );

  // ── Año contra año (094): el embudo por piso + la tendencia del barrio ──
  const hoyMadrid = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Madrid" }).format(new Date());
  const mesLimite = `${hoyMadrid.slice(0, 7)}-01`;
  const anioActual = Number(hoyMadrid.slice(0, 4));
  const ORDEN_PISOS = ["1A_NICA", "4B_ALEX", "3G_MARE", "1A_JACO"];
  const pacePorPiso = ORDEN_PISOS
    .map((codigo) => ({
      codigo,
      filas: filasPace(paceAll.filter((r) => r.codigo === codigo)).slice(0, 6),
    }))
    .filter((p) => p.filas.length > 0);
  const paceTitular = titularPace(pacePorPiso);
  // Los tres de Madrid comparten compset (mismo edificio): el barrio se muestra una vez
  // por ciudad, con el piso de referencia de cada una.
  const barrios = [
    { ciudad: "Madrid · Calle Segovia", codigo: "1A_NICA" },
    { ciudad: "Sevilla · Alameda", codigo: "1A_JACO" },
  ].map(({ ciudad, codigo }) => {
    const rows = mercadoAll.filter((m) => m.codigo === codigo && m.mes < mesLimite);
    const meta = rows.length ? rows.reduce((a, b) => (a.mes > b.mes ? a : b)) : null;
    return {
      ciudad, codigo, meta,
      serie: serieMercado([], rows, mesLimite),
      resumen: resumenMercadoSolo(rows, anioActual),
    };
  }).filter((b) => b.serie.length > 0);

  if (resumen.length === 0) {
    return (
      <main className="container">
        <Link className="backlink" href="/">← Morning Check</Link>
        <div className="notice">
          Todavía no hay foto de precios. El sync con PriceLabs corre a las 07:10 UTC;
          si acaba de configurarse, mañana tenés datos.
        </div>
      </main>
    );
  }

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>

      <header className="header">
        <h1>Precios y mercado</h1>
        <div className="sub">Lo que PriceLabs recomienda, lo ya vendido contra el año pasado y el barrio</div>
        <div className="stamp">
          Foto de PriceLabs del {fechaLarga(resumen[0]?.refreshed_at)} · precios de hoy en
          adelante, no toca el resultado del año
        </div>
      </header>

      {/* la respuesta primero */}
      <p className="titular">{titularPrecios(t)}</p>

      {t.noches > 0 && (
        <div className="card precio-hero">
          <div className="kpi-label">Diferencia si se vendieran al precio recomendado</div>
          <div className="kpi-value">{eur(t.euros)}</div>
          <div className="kpi-sub">
            En {t.noches} {t.noches === 1 ? "noche" : "noches"} de los próximos 60 días ·
            no es beneficio garantizado: es lo que el algoritmo cree que el mercado paga
          </div>
        </div>
      )}

      <div className="section-title">Por piso</div>
      <div className="table-wrap">
        <table className="ranking precio-tabla">
          <thead>
            {/* Cuatro columnas y no seis: a 390 px, con seis la de "vs año pasado" —donde
                está la señal más fuerte— quedaba fuera de pantalla. Ocupación y su
                comparación viajan juntas en una celda. */}
            <tr>
              <th>Piso</th><th>A revisar</th><th>Difer.</th><th>Ocup. vs 2025</th>
            </tr>
          </thead>
          <tbody>
            {porEuros.map((r) => {
              const d = deltaStly(r);
              const euros = Number(r.euros_sobre_la_mesa);
              return (
                <tr key={r.codigo}>
                  <td>
                    <Link href={`/p/${encodeURIComponent(r.codigo)}`} className="alerta-prop">
                      <span className="dot" style={{ background: propColor(r.codigo) }} />
                      {nombreCorto(r.codigo)}
                    </Link>
                  </td>
                  <td className="num">
                    {Number(r.noches_baratas) || "—"}
                    <span className="precio-libres">{Number(r.libres)} libres</span>
                  </td>
                  <td className={"num " + (euros > 0 ? "warn" : "muted")}>
                    {euros > 0 ? eur(euros) : "—"}
                  </td>
                  <td className="num">
                    {pct(Number(r.ocupacion), 0)}
                    {/* solo la flecha y los puntos: el "vs el año pasado" lo dice la
                        cabecera y la nota de abajo. Con el texto largo la tabla no entraba. */}
                    <span className={"precio-stly " + (d == null ? "muted" : d >= 0 ? "pos" : "neg")}
                      title={d == null ? "No gestionábamos el piso en esa fecha del año pasado"
                        : `Ocupación del año pasado a la misma altura: ${pct(Number(r.stly_ocupacion), 0)}`}>
                      {d == null ? "—" : `${d >= 0 ? "▲" : "▼"} ${pp(Math.abs(d))}`}
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="section-note">
        La segunda línea de «Ocup.» compara con la ocupación que tenía el piso en la misma
        fecha del año pasado: ▼ es peor que entonces. «—» = todavía no lo gestionábamos.
      </p>

      {(t.bloqueadas > 0 || t.huerfanas > 0) && (
        <>
          <div className="section-title">Noches que no se pueden vender</div>
          <div className="card">
            <div className="precio-bloq">
              {t.bloqueadas > 0 && (
                <div>
                  <strong>{t.bloqueadas}</strong> bloqueadas a mano
                  <span className="precio-bloq-sub">
                    Si no las bloqueaste a propósito, son noches perdidas: revisalas en el
                    calendario.
                  </span>
                </div>
              )}
              {t.huerfanas > 0 && (
                <div>
                  <strong>{t.huerfanas}</strong> huecos demasiado cortos
                  <span className="precio-bloq-sub">
                    Quedaron entre dos reservas y no llegan a la estancia mínima. Bajar el
                    mínimo esas noches sueltas es la única forma de venderlas.
                  </span>
                </div>
              )}
            </div>
            <ul className="precio-bloq-lista">
              {porEuros.filter((r) => Number(r.bloqueadas) + Number(r.huerfanas) > 0).map((r) => (
                <li key={r.codigo}>
                  <span className="dot" style={{ background: propColor(r.codigo) }} />
                  {nombreCorto(r.codigo)}: {Number(r.bloqueadas)} bloqueadas ·{" "}
                  {Number(r.huerfanas)} huecos cortos
                </li>
              ))}
            </ul>
          </div>
        </>
      )}

      {oportunidades.length > 0 && (
        <>
          <div className="section-title">Noche por noche · lo más cercano primero</div>
          <ul className="precio-lista">
            {oportunidades.slice(0, 30).map((o) => {
              const dias = Number(o.dias_hasta);
              const dif = Number(o.diferencia);
              const urg = dias <= 7 ? "ya" : dias <= 21 ? "pronto" : "lejos";
              return (
                <li key={`${o.codigo}-${o.fecha}`} className="precio-fila">
                  <span className="dot" style={{ background: propColor(o.codigo) }} />
                  <span className="precio-fecha">
                    {fechaCorta(o.fecha)}
                    <span className="precio-prop">{nombreCorto(o.codigo)}</span>
                  </span>
                  <span className="precio-cambio">
                    {eur(Number(o.publicado))} <span className="muted">→</span>{" "}
                    <strong>{eur(Number(o.recomendado))}</strong>
                  </span>
                  <span className={"precio-dif u-" + urg}>+{eur(dif)}</span>
                </li>
              );
            })}
          </ul>
          {oportunidades.length > 30 && (
            <p className="section-note">
              Se muestran las 30 más cercanas de {oportunidades.length}.
            </p>
          )}
        </>
      )}

      {/* ── Año contra año (094): el embudo de los 4 pisos ── */}
      {pacePorPiso.length > 0 && (
        <>
          <div className="section-title">
            Año contra año · lo que viene <span className="badge badge-otb">ya reservado</span>
          </div>
          {paceTitular && <p className="titular titular-ficha">{paceTitular}</p>}
          {pacePorPiso.map((p) => (
            <div className="card" key={p.codigo} style={{ marginBottom: 10 }}>
              <div className="prop-head" style={{ marginBottom: 6 }}>
                <span className="dot" style={{ background: propColor(p.codigo) }} />
                <Link href={`/p/${encodeURIComponent(p.codigo)}`} className="alerta-prop">
                  {nombreCorto(p.codigo)}
                </Link>
              </div>
              <PaceYoy filas={p.filas} color={propColor(p.codigo)} />
            </div>
          ))}
          <p className="section-note">
            Barra de color: noches ya vendidas hoy. Pista gris: cómo cerró ese mes el año
            pasado. El % compara el precio medio de lo vendido con el de entonces (se calla
            con menos de 5 noches). «No existía» = el piso aún no estaba en gestión. Los
            meses con cierres de calendario a propósito (viajes) van por detrás
            deliberadamente.
          </p>
        </>
      )}

      {/* ── La tendencia del barrio, año tras año ── */}
      {barrios.length > 0 && (
        <>
          <div className="section-title">
            El barrio, año tras año <span className="badge badge-mercado">mercado</span>
          </div>
          {barrios.map((b) => (
            <div className="chart-card" key={b.codigo} style={{ marginBottom: 10 }}>
              <div className="card-sub" style={{ color: "var(--muted)", fontSize: "0.78rem", marginBottom: 4 }}>
                {b.ciudad} · {Number(b.meta?.n_listings ?? 0)} pisos de {b.meta?.categoria ?? "?"} dorm.
                (compset PriceLabs) · precio medio vendido por mes
              </div>
              <MercadoChart data={b.serie} color={propColor(b.codigo)}
                nombreMercado={b.ciudad} />
              <p className="section-note" style={{ marginTop: 4 }}>
                {anioActual} vs {anioActual - 1}:{" "}
                {b.resumen.adrYoyPct == null ? "sin base todavía" : (
                  <>
                    precio{" "}
                    <strong className={b.resumen.adrYoyPct >= 0 ? "pos" : "neg"}>
                      {b.resumen.adrYoyPct >= 0 ? "▲ +" : "▼ −"}{pct(Math.abs(b.resumen.adrYoyPct), 0)}
                    </strong>
                    {b.resumen.ocupYoyPp != null && (
                      <>
                        {" "}· ocupación{" "}
                        <strong className={b.resumen.ocupYoyPp >= 0 ? "pos" : "neg"}>
                          {b.resumen.ocupYoyPp >= 0 ? "▲ +" : "▼ −"}{pp(Math.abs(b.resumen.ocupYoyPp))}
                        </strong>
                      </>
                    )}
                    {" "}(media de {b.resumen.meses} meses)
                  </>
                )}
              </p>
            </div>
          ))}
          <p className="section-note">
            El mismo barrio vale para los tres pisos de Madrid (mismo edificio). El detalle
            de cada piso contra su barrio vive en su ficha.
          </p>
        </>
      )}

      <p className="section-note precio-nota">
        Los precios publicados salen de tus suelos manuales; el recomendado lo calcula
        PriceLabs con la demanda del mercado. Que una noche esté por debajo no significa que
        esté mal: significa que decidiste un suelo y conviene revisar si sigue teniendo
        sentido. Para cambiarlos, PriceLabs — desde acá no se toca nada.
      </p>
    </main>
  );
}
