// Portada = Morning Check (02_Prompt §5.1). Respuesta primero: titular generado,
// tira de KPIs con sparklines, stack de alertas/señales, on-the-books y acceso al
// simulador en 1 tap. Las preguntas 1–4 del CEO se responden sin scroll (390×844).
import Link from "next/link";
import { AlertStack, type AlertaV2 } from "@/components/AlertStack";
import { BreakevenTable, type BreakevenRow } from "@/components/BreakevenTable";
import { BulletBreakeven } from "@/components/BulletBreakeven";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { KpiStrip, type KpiItem } from "@/components/KpiStrip";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { RankingTable, type RankingRow } from "@/components/RankingTable";
import { Tabs } from "@/components/Tabs";
import { TrendChart } from "@/components/TrendChart";
import { propColor } from "@/lib/colors";
import { eur, fechaLarga, MESES, pct, pp } from "@/lib/format";
import { buildHeadline, nombreCorto } from "@/lib/headline";
import { mtdPorPropiedad, type NocheRow } from "@/lib/mtd";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Kpis = {
  margen_neto_ytd: number; ingreso_samavi_ytd: number; ocupacion_ytd: number;
  adr_ytd: number; revpar_ytd: number; noches_ytd: number;
  margen_neto_pct_ytd: number; last_sync: string | null;
};
type Freshness = { last_sync: string | null; costes_cargados_hasta: string | null };
type TrendRow = { anio: number; mes: number; ingreso_samavi: number; margen_directo: number; margen_neto: number };
type PnlMes = { codigo: string; anio: number; mes: number; dias_mes: number; bruto: number; noches: number };

const hoyMadrid = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid" }).format(new Date());

export default async function Home({ searchParams }: { searchParams: { margen?: string } }) {
  const verDirecto = searchParams.margen === "directo";
  const hoyIso = hoyMadrid();
  const [anio, mes] = hoyIso.split("-").map(Number);
  const inicioPrevio = `${anio}-${String(Math.max(mes - 1, 1)).padStart(2, "0")}-01`;

  const [kpisArr, freshArr, alertas, ranking, breakeven, costes, trend, pnlMes, otb, canal, noches] =
    await Promise.all([
      readView<Kpis>("v_kpis"),
      readView<Freshness>("v_freshness"),
      readView<AlertaV2>("v_alertas"),
      readView<RankingRow & { margen_directo: number; bruto: number }>("v_ranking_ytd"),
      readView<BreakevenRow>("v_breakeven_ytd"),
      readView<CosteRow>("v_costes_ytd"),
      readView<TrendRow>("v_trend_mensual", { order: { col: "mes" } }),
      readView<PnlMes>("v_pnl_mensual_propiedad", { order: { col: "mes" } }),
      readView<OtbRow>("v_on_the_books"),
      readView<CanalRow>("v_canal_ytd"),
      mes > 1
        ? readView<NocheRow>("v_reservation_nights", { gte: { night: inicioPrevio }, lt: { night: hoyIso } })
        : Promise.resolve([] as NocheRow[]),
    ]);

  const k = kpisArr[0];
  const fresh = freshArr[0];
  const codigos = ranking.map((r) => r.codigo);
  const mtd = mtdPorPropiedad(noches, hoyIso);

  // ── Titular generado (cascada §5.1) ──────────────────────────────────────────
  const titular = k ? buildHeadline({
    alertas: alertas.map((a) => ({
      codigo: a.codigo, tipo: a.tipo, clase: a.clase, dias_restantes: a.dias_restantes,
    })),
    costesPct: Object.fromEntries(costes.map((c) => [c.codigo, Number(c.pct_sobre_ingreso)])),
    mtd,
    kpis: { margen_neto_ytd: Number(k.margen_neto_ytd), margen_neto_pct_ytd: Number(k.margen_neto_pct_ytd) },
    breakeven: breakeven.map((b) => ({ codigo: b.codigo, colchon: b.colchon == null ? null : Number(b.colchon) })),
  }) : supabaseConfigured
    ? "Sin conexión con los datos ahora mismo — reintentá en unos minutos."
    : "Sin datos: configurá Supabase para ver el Morning Check.";

  // ── Sparklines mensuales (margen/ingreso: v_trend_mensual; ocup/ADR: v_pnl_mensual) ──
  const meses = Array.from(new Set(pnlMes.map((r) => r.mes))).sort((a, b) => a - b);
  const porMes = meses.map((m) => {
    const filas = pnlMes.filter((r) => r.mes === m);
    const n = filas.reduce((s, r) => s + Number(r.noches), 0);
    const d = filas.reduce((s, r) => s + Number(r.dias_mes), 0);
    const b = filas.reduce((s, r) => s + Number(r.bruto), 0);
    return { ocup: d > 0 ? n / d : 0, adr: n > 0 ? b / n : 0 };
  });

  const mtdActual = mtd ? mtd.porPropiedad.reduce((s, p) => s + p.actual, 0) : 0;
  const mtdPrevio = mtd ? mtd.porPropiedad.reduce((s, p) => s + p.previo, 0) : 0;
  const desvio = mtd && mtdPrevio > 0 ? (mtdActual - mtdPrevio) / mtdPrevio : null;
  const peorColchon = [...breakeven]
    .filter((b) => b.colchon != null)
    .sort((a, b) => Number(a.colchon) - Number(b.colchon))[0];

  const kpiItems: KpiItem[] = k ? [
    {
      label: "Margen neto YTD", value: eur(k.margen_neto_ytd),
      spark: trend.map((t) => Number(t.margen_neto)),
      sub: `${pct(k.margen_neto_pct_ytd)} de lo que ingresa`,
    },
    {
      label: "Ingreso Samavi YTD", value: eur(k.ingreso_samavi_ytd),
      spark: trend.map((t) => Number(t.ingreso_samavi)),
      sub: desvio == null ? `real devengado ${anio}`
        : `${MESES[mes]} vs ${MESES[mes - 1]} a igual día: ${desvio >= 0 ? "+" : "−"}${pct(Math.abs(desvio), 0)}`,
    },
    {
      label: "Ocupación YTD", value: pct(k.ocupacion_ytd, 0),
      spark: porMes.map((x) => x.ocup),
      sub: peorColchon ? `peor colchón: ${nombreCorto(peorColchon.codigo)} ${pp(Number(peorColchon.colchon))}` : `${k.noches_ytd} noches`,
    },
    {
      label: "ADR YTD", value: eur(k.adr_ytd),
      spark: porMes.map((x) => x.adr),
      sub: (() => {
        const n = porMes.length;
        if (n < 2 || porMes[n - 2].adr <= 0) return `RevPAR ${eur(k.revpar_ytd)} · ${k.noches_ytd} noches`;
        const d = (porMes[n - 1].adr - porMes[n - 2].adr) / porMes[n - 2].adr;
        return `RevPAR ${eur(k.revpar_ytd)} · ${MESES[mes]} vs ${MESES[mes - 1]}: ${d >= 0 ? "+" : "−"}${pct(Math.abs(d), 0)}`;
      })(),
    },
  ] : [];

  // ── On-the-books: futuro YA confirmado (status reserved fuera — cuestión abierta §8.1) ──
  const otbTotal = otb.reduce((s, r) => s + Number(r.ingreso ?? 0), 0);
  const otbNoches = otb.reduce((s, r) => s + Number(r.noches ?? 0), 0);
  const otbMeses = Array.from(
    otb.reduce((map, r) => {
      const key = `${r.anio}-${String(r.mes).padStart(2, "0")}`;
      map.set(key, (map.get(key) ?? 0) + Number(r.ingreso ?? 0));
      return map;
    }, new Map<string, number>()),
  ).sort(([a], [b]) => a.localeCompare(b)).slice(0, 3);

  const costesHasta = fresh?.costes_cargados_hasta
    ? `${MESES[Number(fresh.costes_cargados_hasta.split("-")[1])]} ${fresh.costes_cargados_hasta.split("-")[0]}`
    : "—";

  // Mix de canal: la dependencia de Airbnb es señal permanente (§6.2)
  const ingresoCanal = (pred: (r: CanalRow) => boolean) =>
    canal.filter(pred).reduce((s, r) => s + Number(r.ingreso), 0);
  const totalCanal = ingresoCanal(() => true);
  const pctAirbnb = totalCanal > 0 ? ingresoCanal((r) => r.canal.startsWith("airbnb")) / totalCanal : 0;
  const jacoAirbnb = ingresoCanal((r) => r.codigo === "1A_JACO" && r.canal.startsWith("airbnb"));
  const jacoTotal = ingresoCanal((r) => r.codigo === "1A_JACO");

  const chipsOrden = [...ranking].sort((a, b) => {
    const ca = breakeven.find((x) => x.codigo === a.codigo)?.colchon;
    const cb = breakeven.find((x) => x.codigo === b.codigo)?.colchon;
    return Number(ca ?? 9) - Number(cb ?? 9);
  });

  return (
    <main className="container">
      <header className="header mc-header">
        <h1>Morning Check</h1>
        <div className="sub">{fechaLargaDia(hoyIso)} · Samavi Global Vision SL</div>
        <div className="stamp">
          Sync {fechaLarga(fresh?.last_sync ?? k?.last_sync)} · costes cargados hasta {costesHasta}
        </div>
      </header>

      {!supabaseConfigured ? (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      ) : null}

      {/* 1 · el titular ES la respuesta */}
      <p className="titular">{titular}</p>

      {/* 2 · vital signs con contexto */}
      <KpiStrip items={kpiItems} />

      {/* 3 · qué requiere acción / qué sangra */}
      <div className="section-title">Requiere atención</div>
      <AlertStack rows={alertas} />

      {/* 4 · ya vendido hacia adelante + 5 · palancas, en 1 tap */}
      <div className="grid-2">
        <div className="card otb-card">
          <div className="kpi-label">Ya reservado <span className="badge badge-otb">futuro confirmado</span></div>
          <div className="kpi-mini-value">{eur(otbTotal)}</div>
          <div className="kpi-sub">
            {otbNoches} noches · {otbMeses.map(([key, v]) => {
              const [, m] = key.split("-").map(Number);
              return `${MESES[m]} ${eur(v)}`;
            }).join(" · ")}
          </div>
        </div>
        <Link href="/simulador" className="cta-sim">
          <span className="cta-titulo">Simulador de escenarios →</span>
          <span className="cta-sub">¿Qué pasa si muevo renta, precio u ocupación?</span>
        </Link>
      </div>

      {/* ── diagnóstico (1 minuto): las 4 de un vistazo, tendencia y comparativas ── */}
      <div className="section-title">Propiedades · margen neto YTD (peor colchón primero)</div>
      <div className="chips chips-props">
        {chipsOrden.map((r) => {
          const c = breakeven.find((b) => b.codigo === r.codigo)?.colchon;
          const colchon = c == null ? null : Number(c);
          const icono = colchon == null ? "—" : colchon < 0 ? "▼" : colchon < 0.1 ? "⚠" : "▲";
          const cls = colchon == null ? "muted" : colchon < 0 ? "neg" : colchon < 0.1 ? "warn" : "pos";
          return (
            <Link key={r.codigo} href={`/p/${encodeURIComponent(r.codigo)}`} className="chip chip-prop">
              <span className="dot" style={{ background: propColor(r.codigo) }} />
              <span className="chip-nombre">{nombreCorto(r.codigo)}</span>
              <span className="chip-valor">{eur(r.margen_neto)}</span>
              <span className={"chip-colchon " + cls}>{icono} {colchon == null ? "—" : pp(colchon)} colchón</span>
            </Link>
          );
        })}
      </div>

      <div className="section-title">
        Tendencia margen {verDirecto ? "directo" : "neto"} mensual · real {anio}
        <span className="toggle toggle-inline">
          <Link href="/" className={"toggle-btn" + (!verDirecto ? " active" : "")}>neto</Link>
          <Link href="/?margen=directo" className={"toggle-btn" + (verDirecto ? " active" : "")}>directo</Link>
        </span>
      </div>
      <div className="chart-card">
        <TrendChart
          nombre={verDirecto ? "Margen directo" : "Margen neto"}
          data={trend.map((t) => ({
            mes: t.mes,
            valor: Number(verDirecto ? t.margen_directo : t.margen_neto),
          }))}
        />
      </div>

      <div className="section-title">Comparar las 4 propiedades · YTD {anio}</div>
      <Tabs
        items={[
          { label: "Ranking", content: <RankingTable rows={ranking} /> },
          {
            label: "Equilibrio",
            content: (
              <div>
                <div className="bullets-stack">
                  {[...breakeven]
                    .sort((a, b) => Number(a.colchon ?? 9) - Number(b.colchon ?? 9))
                    .map((b) => (
                      <div key={b.codigo} className="bullet-fila">
                        <Link href={`/p/${encodeURIComponent(b.codigo)}`} className="bullet-nombre">
                          <span className="dot" style={{ background: propColor(b.codigo) }} />
                          {nombreCorto(b.codigo)}
                        </Link>
                        <BulletBreakeven
                          necesaria={b.ocup_breakeven == null ? null : Number(b.ocup_breakeven)}
                          real={Number(b.ocup_actual)}
                          colchon={b.colchon == null ? null : Number(b.colchon)}
                          color={propColor(b.codigo)}
                          etiqueta="real"
                        />
                      </div>
                    ))}
                </div>
                <BreakevenTable rows={breakeven} />
              </div>
            ),
          },
          { label: "Costes", content: <CostesTable rows={costes} /> },
          {
            label: "Canales",
            content: (
              <div>
                <div className="alerta warning senal-canal">
                  ⚠️ <span className="alerta-msg">
                    Airbnb concentra el {pct(pctAirbnb, 1)} del ingreso {anio}.
                    JACO: {jacoTotal > 0 ? pct(jacoAirbnb / jacoTotal, 0) : "—"} Airbnb y cero Booking
                    siendo la única con licencia turística (señal permanente, sin fecha límite).
                  </span>
                </div>
                <CanalTable rows={canal} codigos={codigos} />
              </div>
            ),
          },
          { label: "Ya reservado", content: <OnTheBooksTable rows={[...otb].sort((a, b) => (a.anio - b.anio) || (a.mes - b.mes))} codigos={codigos} /> },
        ]}
      />
    </main>
  );
}

/** "2026-07-16" → "jueves, 16 de julio de 2026" (sin depender del TZ del server) */
function fechaLargaDia(iso: string) {
  const [a, m, d] = iso.split("-").map(Number);
  return new Intl.DateTimeFormat("es-ES", { dateStyle: "full", timeZone: "UTC" })
    .format(new Date(Date.UTC(a, m - 1, d)));
}
