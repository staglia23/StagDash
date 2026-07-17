// Ficha por propiedad (02_Prompt §5.6). La de ALEX es la referencia: conclusión + CTA
// "Simular renegociación →" above the fold, luego alertas, bullet de break-even, waterfall,
// 12 mini-barras tappables, detalle mensual, mix de canal y on-the-books.
import Link from "next/link";
import { AlertStack, type AlertaV2 } from "@/components/AlertStack";
import { BulletBreakeven } from "@/components/BulletBreakeven";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { KpiCard } from "@/components/KpiCard";
import { MiniBarrasMes } from "@/components/MiniBarrasMes";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { WaterfallChart } from "@/components/WaterfallChart";
import { propColor } from "@/lib/colors";
import { eur, fechaLarga, MESES, pct, pp } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import type { Modelo } from "@/lib/simulador";
import { readView } from "@/lib/supabase";
import { pasosWaterfall } from "@/lib/waterfall";

export const dynamic = "force-dynamic";

type RankRow = {
  codigo: string; ingreso_samavi: number; bruto: number; noches: number; reservas: number;
  noches_disponibles: number; margen_directo: number; cuota_samavi_gen: number; margen_neto: number;
  margen_neto_pct: number; eur_noche_neto: number; ocup_pct: number; adr: number; revpar: number;
  ingreso_cancelaciones: number;
};
type BreakevenRow = {
  codigo: string; costes_fijos: number; contribucion_noche: number;
  noches_necesarias: number | null; ocup_breakeven: number | null; ocup_actual: number; colchon: number | null;
};
type Propiedad = {
  codigo: string; modelo: Modelo; fecha_inicio: string | null;
  renta_base: number; comision_pct: number; aviso_fecha: string | null; aviso_nota: string | null;
};
type Fila = {
  codigo: string; anio: number; mes: number;
  ingreso_samavi: number; noches: number; reservas: number; ocup_pct: number; adr: number;
  total_gastos_directos: number; margen_directo: number;
  cuota_samavi_gen: number; margen_neto: number;
};
type Freshness = { last_sync: string | null; costes_cargados_hasta: string | null };

const MODELO_LABEL: Record<string, string> = {
  titular: "titular — no paga renta",
  subarriendo: "subarriendo — paga renta",
  comision: "comisión — ingreso = 30,25 % del bruto",
};

export default async function FichaPropiedad({
  params, searchParams,
}: {
  params: { id: string };
  searchParams: { margen?: string };
}) {
  // los params de ruta llegan percent-encoded; decode defensivo (un "%" suelto no debe tirar 500)
  let codigo: string;
  try { codigo = decodeURIComponent(params.id); } catch { codigo = params.id; }
  const verDirecto = searchParams.margen === "directo";

  const [rankAll, beAll, costAll, propAll, canalAll, otbAll, mesesAll, alertAll, freshArr] =
    await Promise.all([
      readView<RankRow>("v_ranking_ytd"),
      readView<BreakevenRow>("v_breakeven_ytd"),
      readView<CosteRow>("v_costes_ytd"),
      readView<Propiedad>("v_propiedades"),
      readView<CanalRow>("v_canal_ytd"),
      readView<OtbRow>("v_on_the_books"),
      readView<Fila>("v_pnl_neto_propiedad", { order: { col: "mes" }, eq: { codigo } }),
      readView<AlertaV2>("v_alertas"),
      readView<Freshness>("v_freshness"),
    ]);

  const only = <T extends { codigo: string }>(rows: T[]) => rows.filter((r) => r.codigo === codigo);
  const r = rankAll.find((x) => x.codigo === codigo);
  const be = beAll.find((x) => x.codigo === codigo);
  const coste = costAll.find((x) => x.codigo === codigo);
  const propiedad = propAll.find((x) => x.codigo === codigo);
  const alertas = only(alertAll);
  const fresh = freshArr[0];

  if (!r || !coste) {
    return (
      <main className="container">
        <Link className="backlink" href="/">← Volver</Link>
        <div className="notice">No encuentro la propiedad «{codigo}».</div>
      </main>
    );
  }

  const anio = mesesAll[0]?.anio ?? new Date().getFullYear();

  // El toggle neto/directo cambia TODO lo afectado de forma consistente (§10):
  // titular, bullet de break-even y mini-barras. En directo, el break-even excluye la
  // cuota de overhead: fijos_directo = costes_fijos − overhead (ambos de vistas).
  const contribNoche = be ? Number(be.contribucion_noche) : 0;
  const necesariaNeto = be?.ocup_breakeven == null ? null : Number(be.ocup_breakeven);
  const necesariaDirecto = be && contribNoche > 0 && Number(r.noches_disponibles) > 0
    ? ((Number(be.costes_fijos) - Number(coste.overhead)) / contribNoche) / Number(r.noches_disponibles)
    : null;
  const necesaria = verDirecto ? necesariaDirecto : necesariaNeto;
  const ocupReal = Number(be?.ocup_actual ?? r.ocup_pct);
  const colchon = necesaria == null ? null : ocupReal - necesaria;

  const margenSel = Number(verDirecto ? r.margen_directo : r.margen_neto);
  const margenSelPct = verDirecto
    ? (Number(r.ingreso_samavi) > 0 ? Number(r.margen_directo) / Number(r.ingreso_samavi) : 0)
    : Number(r.margen_neto_pct);

  const estado = colchon == null ? { icon: "—", label: "sin dato", cls: "muted" }
    : colchon < 0 ? { icon: "▼", label: "en pérdida", cls: "neg" }
    : colchon < 0.1 ? { icon: "⚠", label: "colchón ajustado", cls: "warn" }
    : { icon: "▲", label: "colchón holgado", cls: "pos" };

  const portfolioBruto = rankAll.reduce((s, x) => s + Number(x.bruto), 0);
  const portfolioNoches = rankAll.reduce((s, x) => s + Number(x.noches), 0);
  const portfolioAdr = portfolioNoches > 0 ? portfolioBruto / portfolioNoches : 0;

  const eurSigned = (v: number | string) => {
    const n = Number(v);
    return `${n >= 0 ? "+" : "−"}${eur(Math.abs(n))}`;
  };

  const tieneContrato = alertas.some((a) => a.tipo === "contrato")
    || (propiedad?.modelo === "subarriendo" && propiedad.aviso_fecha != null);
  const ctaLabel = tieneContrato ? "Simular renegociación →" : "Simular escenarios →";

  const pasos = pasosWaterfall({
    modelo: (propiedad?.modelo ?? "titular") as Modelo,
    bruto: Number(r.bruto),
    ingreso_samavi: Number(r.ingreso_samavi),
    ingreso_cancelaciones: Number(r.ingreso_cancelaciones ?? 0),
    renta: Number(coste.renta),
    limpieza: Number(coste.limpieza),
    suministros: Number(coste.suministros),
    comunidad: Number(coste.comunidad),
    otros: Number(coste.otros),
    overhead: Number(coste.overhead),
    margen_directo: Number(r.margen_directo),
    margen_neto: Number(r.margen_neto),
  });

  const margenMes = mesesAll.map((f) => ({
    mes: f.mes,
    valor: Number(verDirecto ? f.margen_directo : f.margen_neto),
  }));

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>

      {/* ── above the fold: conclusión + CTA ── */}
      <header className="header">
        <h1>
          <span className="dot" style={{ background: propColor(codigo) }} />
          {nombreCorto(codigo)} <span className="tag">{codigo}</span>
        </h1>
        <div className="sub">{MODELO_LABEL[propiedad?.modelo ?? ""] ?? ""} · YTD {anio}</div>
        <div className="stamp">Sync {fechaLarga(fresh?.last_sync)} · datos reales devengados</div>
      </header>

      <p className="titular titular-ficha">
        {margenSel >= 0 ? "Deja" : "Pierde"} {eur(Math.abs(margenSel))} de
        margen {verDirecto ? "directo (antes del overhead común)" : "neto"} YTD ({pct(margenSelPct)}) — <span className={estado.cls}>
          {estado.icon} {estado.label}{colchon != null ? `, ${pp(colchon)} sobre el equilibrio` : ""}
        </span>
      </p>

      <Link href={`/simulador?p=${encodeURIComponent(codigo)}`} className="cta-sim cta-ficha">
        <span className="cta-titulo">{ctaLabel}</span>
        <span className="cta-sub">
          {tieneContrato && propiedad?.aviso_fecha
            ? `Baseline real precargado · fecha límite ${fechaCorta(propiedad.aviso_fecha)}`
            : "Baseline real precargado · cálculo al instante"}
        </span>
      </Link>

      <div className="toggle" role="group" aria-label="Margen mostrado en la ficha">
        <Link href={`/p/${encodeURIComponent(codigo)}`}
          className={"toggle-btn" + (!verDirecto ? " active" : "")}
          aria-current={!verDirecto ? "true" : undefined}>Margen neto</Link>
        <Link href={`/p/${encodeURIComponent(codigo)}?margen=directo`}
          className={"toggle-btn" + (verDirecto ? " active" : "")}
          aria-current={verDirecto ? "true" : undefined}>Margen directo</Link>
      </div>

      {alertas.length > 0 && (
        <>
          <div className="section-title">Requiere atención</div>
          <AlertStack rows={alertas} />
        </>
      )}

      {/* ── diagnóstico ── */}
      <div className="section-title">
        Punto de equilibrio · YTD {anio}{verDirecto ? " · sin overhead" : ""}
      </div>
      <div className="card">
        <BulletBreakeven
          necesaria={necesaria}
          real={ocupReal}
          colchon={colchon}
          color={propColor(codigo)}
          etiqueta="real"
        />
        {be && (
          <div className="kpi-sub" style={{ marginTop: 8 }}>
            Costes fijos {verDirecto
              ? `${eur(Number(be.costes_fijos) - Number(coste.overhead))} (sin la cuota de overhead ${eur(coste.overhead)})`
              : eur(be.costes_fijos)} · aporta {eur(be.contribucion_noche)}/noche
          </div>
        )}
      </div>

      <div className="kpi-grid" style={{ marginTop: 12 }}>
        <KpiCard label="Ingreso Samavi YTD" value={eur(r.ingreso_samavi)}
          sub={`Bruto ${eur(r.bruto)} · ${r.reservas} reservas` +
            (Number(r.ingreso_cancelaciones) > 0 ? ` · incluye ${eur(r.ingreso_cancelaciones)} de canceladas` : "")} />
        <KpiCard label="Ocupación YTD" value={pct(r.ocup_pct, 0)}
          sub={`${r.noches} noches de ${r.noches_disponibles} disponibles`} />
        <KpiCard label="ADR / RevPAR" value={eur(r.adr)}
          sub={`RevPAR ${eur(r.revpar)} · ADR portfolio ${eur(portfolioAdr)}`} />
        <KpiCard label="€/noche neto" value={eur(r.eur_noche_neto)}
          sub="Lo que queda limpio por noche vendida" />
        <KpiCard label="Margen directo YTD" value={eur(r.margen_directo)}
          sub="Contribución antes del overhead común" />
        <KpiCard label="Cuota de overhead" value={eur(Math.abs(Number(r.cuota_samavi_gen)))}
          sub={`Deja margen neto ${eur(r.margen_neto)}`} />
      </div>

      <div className="section-title">Waterfall del margen · YTD {anio} · real</div>
      <div className="chart-card">
        <WaterfallChart pasos={pasos} color={propColor(codigo)} />
        {propiedad?.modelo === "comision" && (
          <p className="section-note" style={{ marginTop: 4 }}>
            Caso aparte: el ingreso Samavi es el 30,25 % del bruto; el primer escalón incluye la
            comisión de canal y el Pasivo Madre, no es solo comisión.
          </p>
        )}
      </div>

      <div className="section-title">
        Margen {verDirecto ? "directo" : "neto"} por mes · {anio}
      </div>
      <div className="card">
        <MiniBarrasMes datos={margenMes} color={propColor(codigo)} />
        <p className="section-note" style={{ margin: "8px 0 0" }}>
          {verDirecto
            ? "Margen directo = contribución antes del overhead común (si soltás la propiedad, el overhead no desaparece: se redistribuye)."
            : "Margen neto = con la cuota de overhead prorrateada por peso en el ingreso."}
          {" "}Tocá un mes para ir a su fila.
        </p>
      </div>

      <div className="section-title">Detalle mensual · real {anio}</div>
      <div className="table-wrap">
        <table className="ranking">
          <thead>
            <tr>
              <th>Mes</th><th>Ingreso Samavi</th><th>Noches</th><th>Ocup.</th><th>ADR</th>
              <th>Gastos directos</th><th>Margen directo</th><th>Overhead</th><th>Margen neto</th>
            </tr>
          </thead>
          <tbody>
            {mesesAll.map((f) => (
              <tr key={`${f.anio}-${f.mes}`} id={`mes-${f.mes}`}>
                <td>{MESES[f.mes]} {f.anio}</td>
                <td className="num">{eur(f.ingreso_samavi)}</td>
                <td className="num">{f.noches}</td>
                <td className="num">{pct(f.ocup_pct, 0)}</td>
                <td className="num">{eur(f.adr)}</td>
                <td className="num">{eur(Math.abs(Number(f.total_gastos_directos)))}</td>
                <td className={"num " + (Number(f.margen_directo) >= 0 ? "pos" : "neg")}>{eurSigned(f.margen_directo)}</td>
                <td className="num">{eur(Math.abs(Number(f.cuota_samavi_gen)))}</td>
                <td className={"num " + (Number(f.margen_neto) >= 0 ? "pos" : "neg")}>{eurSigned(f.margen_neto)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="section-title">Mix por canal · YTD {anio}</div>
      <CanalTable rows={only(canalAll)} codigos={[codigo]} />

      <div className="section-title">Ya reservado <span className="badge badge-otb">futuro confirmado</span></div>
      <OnTheBooksTable
        rows={only(otbAll).sort((a, b) => (a.anio - b.anio) || (a.mes - b.mes))}
        codigos={[codigo]}
      />

      <div className="section-title">Desglose de costes · YTD {anio}</div>
      <CostesTable rows={only(costAll)} showTotal={false} />
    </main>
  );
}

const fechaCorta = (iso: string) => {
  const [a, m, d] = iso.split("-");
  return `${d}/${m}/${a}`;
};
