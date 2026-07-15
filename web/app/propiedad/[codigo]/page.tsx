import Link from "next/link";
import { KpiCard } from "@/components/KpiCard";
import { Alertas, type AlertaRow } from "@/components/Alertas";
import { TrendChart } from "@/components/TrendChart";
import { BreakevenTable, type BreakevenRow } from "@/components/BreakevenTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { readView } from "@/lib/supabase";
import { eur, pct, MESES } from "@/lib/format";
import { propColor } from "@/lib/colors";

export const dynamic = "force-dynamic";

type RankRow = {
  codigo: string; ingreso_samavi: number; bruto: number; noches: number; reservas: number;
  margen_directo: number; cuota_samavi_gen: number; margen_neto: number;
  margen_neto_pct: number; eur_noche_neto: number; ocup_pct: number; adr: number; revpar: number;
};
type Fila = {
  codigo: string; anio: number; mes: number;
  ingreso_samavi: number; noches: number; reservas: number; ocup_pct: number; adr: number;
  total_gastos_directos: number; margen_directo: number;
  cuota_samavi_gen: number; margen_neto: number;
};

export default async function PropiedadPage({ params }: { params: { codigo: string } }) {
  const codigo = decodeURIComponent(params.codigo);

  const [rankAll, beAll, costAll, canalAll, otbAll, mesesAll, alertAll] = await Promise.all([
    readView<RankRow>("v_ranking_ytd"),
    readView<BreakevenRow>("v_breakeven_ytd"),
    readView<CosteRow>("v_costes_ytd"),
    readView<CanalRow>("v_canal_ytd"),
    readView<OtbRow>("v_on_the_books", { col: "mes" }),
    readView<Fila>("v_pnl_neto_propiedad", { col: "mes" }),
    readView<AlertaRow>("v_alertas"),
  ]);

  const only = <T extends { codigo: string }>(rows: T[]) => rows.filter((r) => r.codigo === codigo);
  const r = rankAll.find((x) => x.codigo === codigo);
  const filas = only(mesesAll);

  if (!r) {
    return (
      <main className="container">
        <Link className="backlink" href="/">← Volver</Link>
        <div className="notice">No encuentro la propiedad «{codigo}».</div>
      </main>
    );
  }

  return (
    <main className="container">
      <Link className="backlink" href="/">← Volver al dashboard</Link>
      <header className="header">
        <h1>
          <span className="dot" style={{ background: propColor(codigo) }} />
          {codigo}
        </h1>
        <div className="sub">Ficha completa · YTD {new Date().getFullYear()}</div>
      </header>

      <div className="kpi-grid">
        <KpiCard label="Margen Neto YTD" value={eur(r.margen_neto)}
          sub={`% sobre Ingreso ${pct(r.margen_neto_pct)}`} />
        <KpiCard label="Ingreso Samavi YTD" value={eur(r.ingreso_samavi)} />
        <KpiCard label="Ocupación YTD" value={pct(r.ocup_pct, 0)}
          sub={`${r.noches} noches · ${r.reservas} reservas`} />
        <KpiCard label="ADR / RevPAR" value={eur(r.adr)} sub={`RevPAR: ${eur(r.revpar)}`} />
        <KpiCard label="€/noche neto" value={eur(r.eur_noche_neto)}
          sub="Lo que queda limpio por noche vendida" />
        <KpiCard label="Margen directo" value={eur(r.margen_directo)}
          sub={`Overhead: ${eur(r.cuota_samavi_gen)}`} />
      </div>

      {only(alertAll).length > 0 && (
        <>
          <div className="section-title">Requiere atención</div>
          <Alertas rows={only(alertAll)} />
        </>
      )}

      <div className="section-title">Punto de equilibrio</div>
      <BreakevenTable rows={only(beAll)} />

      <div className="section-title">Desglose de costes</div>
      <CostesTable rows={only(costAll)} showTotal={false} />

      <div className="section-title">Tendencia Margen Neto mensual</div>
      <div className="chart-card">
        <TrendChart data={filas.map((f) => ({ mes: f.mes, margen_neto: Number(f.margen_neto) }))} />
      </div>

      <div className="section-title">Detalle mensual</div>
      <div className="table-wrap">
        <table className="ranking">
          <thead>
            <tr>
              <th>Mes</th><th>Ingreso Samavi</th><th>Noches</th><th>Ocup.</th><th>ADR</th>
              <th>Gastos directos</th><th>Margen Directo</th><th>Overhead</th><th>Margen Neto</th>
            </tr>
          </thead>
          <tbody>
            {filas.map((f) => (
              <tr key={`${f.anio}-${f.mes}`}>
                <td>{MESES[f.mes]} {f.anio}</td>
                <td className="num">{eur(f.ingreso_samavi)}</td>
                <td className="num">{f.noches}</td>
                <td className="num">{pct(f.ocup_pct, 0)}</td>
                <td className="num">{eur(f.adr)}</td>
                <td className="num">{eur(f.total_gastos_directos)}</td>
                <td className="num">{eur(f.margen_directo)}</td>
                <td className="num">{eur(f.cuota_samavi_gen)}</td>
                <td className={"num " + (Number(f.margen_neto) >= 0 ? "pos" : "neg")}>
                  {eur(f.margen_neto)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="section-title">Mix por canal</div>
      <CanalTable rows={only(canalAll)} codigos={[codigo]} />

      <div className="section-title">Ingreso ya reservado</div>
      <OnTheBooksTable rows={only(otbAll)} codigos={[codigo]} />
    </main>
  );
}
