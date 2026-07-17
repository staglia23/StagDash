// Simulador de escenarios (02_Prompt §5.4). Server component: arma el baseline REAL desde
// las vistas y lo pasa por props; el cálculo vive 100 % en el cliente (cero red después).
// El estado "qué propiedad" vive en la URL (?p=) — searchParams como fuente de verdad.
import Link from "next/link";
import { Simulador, type RealYtd } from "@/components/Simulador";
import { fechaLarga } from "@/lib/format";
import type { Modelo, PropBaseline } from "@/lib/simulador";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type RankRow = {
  codigo: string; ingreso_samavi: number; bruto: number; noches: number;
  noches_disponibles: number; margen_neto: number; margen_neto_pct: number; ocup_pct: number;
  ingreso_cancelaciones: number;
};
type CosteRow = {
  codigo: string; renta: number; limpieza: number; suministros: number;
  comunidad: number; otros: number; overhead: number;
};
type BreakevenRow = { codigo: string; colchon: number | null };
type Propiedad = { codigo: string; modelo: Modelo; renta_base: number; comision_pct: number };
type PnlMes = { codigo: string; mes: number };
type Freshness = { last_sync: string | null };

const CASO_REY = "4B_ALEX";

export default async function SimuladorPage({ searchParams }: { searchParams: { p?: string } }) {
  const [ranking, costes, breakeven, propiedades, pnlMes, freshArr] = await Promise.all([
    readView<RankRow>("v_ranking_ytd"),
    readView<CosteRow>("v_costes_ytd"),
    readView<BreakevenRow>("v_breakeven_ytd"),
    readView<Propiedad>("v_propiedades"),
    readView<PnlMes>("v_pnl_mensual_propiedad"),
    readView<Freshness>("v_freshness"),
  ]);

  const baselines: PropBaseline[] = ranking.map((r) => {
    const c = costes.find((x) => x.codigo === r.codigo);
    const p = propiedades.find((x) => x.codigo === r.codigo);
    return {
      codigo: r.codigo,
      modelo: (p?.modelo ?? "titular") as Modelo,
      meses: pnlMes.filter((x) => x.codigo === r.codigo).length,
      // los cobros de canceladas (windfall) quedan fuera del baseline: el simulador
      // proyecta el negocio por noches, no ingresos extraordinarios
      ingresoYtd: Number(r.ingreso_samavi) - Number(r.ingreso_cancelaciones ?? 0),
      brutoYtd: Number(r.bruto),
      nochesYtd: Number(r.noches),
      disponiblesYtd: Number(r.noches_disponibles),
      rentaYtd: Number(c?.renta ?? 0),
      limpiezaYtd: Number(c?.limpieza ?? 0),
      suministrosYtd: Number(c?.suministros ?? 0),
      comunidadYtd: Number(c?.comunidad ?? 0),
      otrosYtd: Number(c?.otros ?? 0),
      overheadYtd: Number(c?.overhead ?? 0),
      rentaBaseMes: Number(p?.renta_base ?? 0),
      comisionModeloPct: Number(p?.comision_pct ?? 0),
    };
  });

  const real: Record<string, RealYtd> = Object.fromEntries(ranking.map((r) => [r.codigo, {
    margen_neto: Number(r.margen_neto),
    margen_neto_pct: Number(r.margen_neto_pct),
    ocup_pct: Number(r.ocup_pct),
    colchon: breakeven.find((b) => b.codigo === r.codigo)?.colchon == null
      ? null
      : Number(breakeven.find((b) => b.codigo === r.codigo)!.colchon),
  }]));

  // Next.js ya entrega searchParams decodificados — un decode extra revienta con "%" sueltos
  const pedido = searchParams.p ?? CASO_REY;
  const inicial = baselines.some((b) => b.codigo === pedido)
    ? pedido
    : baselines[0]?.codigo ?? CASO_REY;

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>
      <header className="header">
        <h1>Simulador de escenarios <span className="badge badge-sim">simulado</span></h1>
        <div className="sub">Proyección 2026 a ritmo actual — mové una palanca y mirá el margen</div>
        <div className="stamp">Baseline real: sync {fechaLarga(freshArr[0]?.last_sync)}</div>
      </header>

      {!supabaseConfigured || baselines.length === 0 ? (
        <div className="notice">Sin baseline: configurá Supabase para usar el simulador.</div>
      ) : (
        <Simulador key={inicial} baselines={baselines} inicial={inicial} real={real} />
      )}
    </main>
  );
}
