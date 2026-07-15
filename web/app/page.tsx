import { KpiCard } from "@/components/KpiCard";
import { Alertas, type AlertaRow } from "@/components/Alertas";
import { PropiedadCards, type PropCard } from "@/components/PropiedadCards";
import { RankingTable, type RankingRow } from "@/components/RankingTable";
import { TrendChart, type TrendPoint } from "@/components/TrendChart";
import { BreakevenTable, type BreakevenRow } from "@/components/BreakevenTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { Tabs } from "@/components/Tabs";
import { readView, supabaseConfigured } from "@/lib/supabase";
import { eur, pct, fechaLarga } from "@/lib/format";

export const dynamic = "force-dynamic";

type Kpis = {
  margen_neto_ytd: number; ingreso_samavi_ytd: number; ocupacion_ytd: number;
  adr_ytd: number; revpar_ytd: number; noches_ytd: number;
  margen_neto_pct_ytd: number; last_sync: string | null;
};

export default async function Home() {
  const [kpisArr, ranking, trend, breakeven, costes, canal, otb, alertas] = await Promise.all([
    readView<Kpis>("v_kpis"),
    readView<RankingRow>("v_ranking_ytd"),
    readView<TrendPoint>("v_trend_mensual", { col: "mes" }),
    readView<BreakevenRow>("v_breakeven_ytd"),
    readView<CosteRow>("v_costes_ytd"),
    readView<CanalRow>("v_canal_ytd"),
    readView<OtbRow>("v_on_the_books", { col: "mes" }),
    readView<AlertaRow>("v_alertas"),
  ]);
  const k = kpisArr[0];
  const codigos = ranking.map((r) => r.codigo);
  const comprometido = otb.reduce((a, r) => a + Number(r.ingreso ?? 0), 0);

  // tarjetas = ranking + colchón del break-even
  const cards: PropCard[] = ranking.map((r) => ({
    codigo: r.codigo,
    ingreso_samavi: r.ingreso_samavi,
    margen_neto: r.margen_neto,
    margen_neto_pct: r.margen_neto_pct,
    ocup_pct: r.ocup_pct,
    eur_noche_neto: r.eur_noche_neto,
    colchon: breakeven.find((b) => b.codigo === r.codigo)?.colchon ?? null,
  }));

  return (
    <main className="container">
      <header className="header">
        <h1>Dashboard Samavi</h1>
        <div className="sub">Rendimiento neto por propiedad · YTD {new Date().getFullYear()}</div>
        <div className="stamp">Última actualización: {fechaLarga(k?.last_sync)}</div>
      </header>

      {!supabaseConfigured ? (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      ) : null}

      <div className="section-title">Vital signs</div>
      <div className="kpi-grid">
        <KpiCard label="Margen Neto YTD" value={eur(k?.margen_neto_ytd)}
          sub={`% sobre Ingreso ${pct(k?.margen_neto_pct_ytd)}`} />
        <KpiCard label="Ingreso Samavi YTD" value={eur(k?.ingreso_samavi_ytd)} />
        <KpiCard label="Ocupación Portfolio YTD" value={pct(k?.ocupacion_ytd, 0)}
          sub={`Noches reservadas: ${k?.noches_ytd ?? 0}`} />
        <KpiCard label="ADR / RevPAR Portfolio" value={eur(k?.adr_ytd)}
          sub={`RevPAR: ${eur(k?.revpar_ytd)}`} />
        <KpiCard label="Ingreso ya reservado" value={eur(comprometido)}
          sub="Reservas futuras confirmadas" />
      </div>

      <div className="section-title">Requiere atención</div>
      <Alertas rows={alertas} />

      <div className="section-title">Propiedades — de un vistazo</div>
      <p className="section-note">Tocá una tarjeta para ver su ficha completa.</p>
      <PropiedadCards rows={cards} />

      <div className="section-title">Tendencia Margen Neto mensual</div>
      <div className="chart-card">
        <TrendChart data={trend} />
      </div>

      <div className="section-title">Comparar las 4 propiedades</div>
      <Tabs
        items={[
          { label: "Ranking", content: <RankingTable rows={ranking} /> },
          { label: "Equilibrio", content: <BreakevenTable rows={breakeven} /> },
          { label: "Costes", content: <CostesTable rows={costes} /> },
          { label: "Canales", content: <CanalTable rows={canal} codigos={codigos} /> },
          { label: "Ya reservado", content: <OnTheBooksTable rows={otb} codigos={codigos} /> },
        ]}
      />
    </main>
  );
}
