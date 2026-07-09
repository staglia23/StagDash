import { KpiCard } from "@/components/KpiCard";
import { RankingTable, type RankingRow } from "@/components/RankingTable";
import { TrendChart, type TrendPoint } from "@/components/TrendChart";
import { readView, supabaseConfigured } from "@/lib/supabase";
import { eur, pct, fechaLarga } from "@/lib/format";

export const dynamic = "force-dynamic";

type Kpis = {
  margen_neto_ytd: number; ingreso_samavi_ytd: number; ocupacion_ytd: number;
  adr_ytd: number; revpar_ytd: number; noches_ytd: number;
  margen_neto_pct_ytd: number; last_sync: string | null;
};

export default async function Home() {
  const [kpisArr, ranking, trend] = await Promise.all([
    readView<Kpis>("v_kpis"),
    readView<RankingRow>("v_ranking_ytd"),
    readView<TrendPoint>("v_trend_mensual", { col: "mes" }),
  ]);
  const k = kpisArr[0];

  return (
    <main className="container">
      <header className="header">
        <h1>Dashboard Samavi</h1>
        <div className="sub">Rendimiento neto por propiedad · YTD {new Date().getFullYear()}</div>
        <div className="stamp">Última actualización: {fechaLarga(k?.last_sync)}</div>
      </header>

      {!supabaseConfigured ? (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> en
          <code> web/.env.local</code> para ver los datos en vivo.
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
      </div>

      <div className="section-title">Ranking de propiedades — por Margen Neto</div>
      <RankingTable rows={ranking} />

      <div className="section-title">Tendencia Margen Neto mensual</div>
      <div className="chart-card">
        <TrendChart data={trend} />
      </div>
    </main>
  );
}
