import { KpiCard } from "@/components/KpiCard";
import { RankingTable, type RankingRow } from "@/components/RankingTable";
import { TrendChart, type TrendPoint } from "@/components/TrendChart";
import { BreakevenTable, type BreakevenRow } from "@/components/BreakevenTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { readView, supabaseConfigured } from "@/lib/supabase";
import { eur, pct, fechaLarga } from "@/lib/format";

export const dynamic = "force-dynamic";

type Kpis = {
  margen_neto_ytd: number; ingreso_samavi_ytd: number; ocupacion_ytd: number;
  adr_ytd: number; revpar_ytd: number; noches_ytd: number;
  margen_neto_pct_ytd: number; last_sync: string | null;
};

export default async function Home() {
  const [kpisArr, ranking, trend, breakeven, costes, canal, otb] = await Promise.all([
    readView<Kpis>("v_kpis"),
    readView<RankingRow>("v_ranking_ytd"),
    readView<TrendPoint>("v_trend_mensual", { col: "mes" }),
    readView<BreakevenRow>("v_breakeven_ytd"),
    readView<CosteRow>("v_costes_ytd"),
    readView<CanalRow>("v_canal_ytd"),
    readView<OtbRow>("v_on_the_books", { col: "mes" }),
  ]);
  const k = kpisArr[0];
  // orden de columnas de los pivots: el del ranking (por margen neto)
  const codigos = ranking.map((r) => r.codigo);
  const comprometido = otb.reduce((a, r) => a + Number(r.ingreso ?? 0), 0);

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

      <div className="section-title">Ranking de propiedades — por Margen Neto</div>
      <RankingTable rows={ranking} />

      <div className="section-title">Punto de equilibrio</div>
      <p className="section-note">
        Ocupación mínima para cubrir costes fijos (renta, suministros, comunidad, otros y overhead).
        El colchón es la distancia entre tu ocupación real y ese mínimo: cuanto más chico, más frágil.
      </p>
      <BreakevenTable rows={breakeven} />

      <div className="section-title">Desglose de costes por propiedad</div>
      <p className="section-note">
        Cuánto cuesta cada línea en lo que va del año. «Overhead» es la parte de los gastos generales
        de Samavi (sueldo, gestoría, software…) que le toca a cada propiedad, según su peso en ingresos.
      </p>
      <CostesTable rows={costes} />

      <div className="section-title">Tendencia Margen Neto mensual</div>
      <div className="chart-card">
        <TrendChart data={trend} />
      </div>

      <div className="section-title">Mix por canal</div>
      <p className="section-note">Ingreso por canal de venta en lo que va del año.</p>
      <CanalTable rows={canal} codigos={codigos} />

      <div className="section-title">Ingreso ya reservado (on the books)</div>
      <p className="section-note">
        No es una proyección: son reservas confirmadas para las noches que todavía no ocurrieron.
      </p>
      <OnTheBooksTable rows={otb} codigos={codigos} />
    </main>
  );
}
