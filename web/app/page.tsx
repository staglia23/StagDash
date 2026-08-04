// Portada = Morning Check (02_Prompt §5.1), variante HÍBRIDA (jul 2026).
//
// Orden deliberado: primero el estado de hoy (titular + salud a 30 días), después el dinero
// que ya está asegurado hasta fin de año, después el año corrido, y solo al final los
// accesos. Todo lo que era diagnóstico (tendencia, comparativas, ya reservado) se fue a
// /analisis: la portada responde "¿qué pasa hoy?", no acumula tablas.
import Link from "next/link";
import { AlertStack, type AlertaV2 } from "@/components/AlertStack";
import { AseguradoLeyenda, AseguradoTable } from "@/components/AseguradoTable";
import type { HealthData } from "@/components/HealthCard";
import { KpiStrip, type KpiItem } from "@/components/KpiStrip";
import { SaludFila } from "@/components/SaludFila";
import { YtdPropiedadTable } from "@/components/YtdPropiedadTable";
import { construirTabla, resumenAsegurado, type AseguradoRow } from "@/lib/asegurado";
import { propColor } from "@/lib/colors";
import { stampCuadre, type CuadreRow } from "@/lib/cuadre";
import { resumenCuentaDuena, type FilaCuenta } from "@/lib/cuentaDuena";
import { eur, fechaLarga, MESES, pct, pp } from "@/lib/format";
import { buildHeadline, nombreCorto } from "@/lib/headline";
import { mtdPorPropiedad, type NocheRow } from "@/lib/mtd";
import { cruceRentabilidad, spreadContribucion, type RentRow } from "@/lib/rentabilidad";
import { estadoSalud, revparEquilibrio } from "@/lib/salud";
import type { Modelo } from "@/lib/simulador";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Kpis = {
  margen_neto_ytd: number; ingreso_samavi_ytd: number; ocupacion_ytd: number;
  adr_ytd: number; revpar_ytd: number; noches_ytd: number;
  margen_neto_pct_ytd: number; last_sync: string | null;
};
// cierre_hasta = hasta qué mes llega la conciliación bancaria (el cierre de verdad).
// costes_cargados_hasta mide la proyección de events, que va hacia adelante: no sirve
// como sello de "cerrado" (ver migración 020).
type Freshness = {
  last_sync: string | null; costes_cargados_hasta: string | null; cierre_hasta: string | null;
};
type TrendRow = { anio: number; mes: number; ingreso_samavi: number; margen_directo: number; margen_neto: number };
type PnlMes = { codigo: string; anio: number; mes: number; dias_mes: number; bruto: number; noches: number };
type RankingRow = RentRow & {
  bruto: number; ingreso_cancelaciones: number; noches_disponibles: number; total_costes?: number;
};
// Las tres capas del motor (migración 025): contribución → operativo → resultado Samavi.
type ResultadoRow = {
  contribucion: number; overhead_operativo: number; margen_operativo: number;
  costes_corporativos: number; resultado_samavi: number;
};
type BreakevenRow = { codigo: string; ocup_breakeven: number | null; colchon: number | null };
type CosteRow = { codigo: string; total_costes: number; pct_sobre_ingreso: number };
type ForwardRow = {
  codigo: string; noches_7: number; noches_14: number; noches_30: number;
  bruto_7: number; bruto_30: number; ingreso_30: number;
};
type ForwardDia = { codigo: string; dia: string; vendida: boolean };
type PickupRow = {
  codigo: string; reservas_7d: number; reservas_15d: number;
  ultima_reserva: string | null; dias_sin_vender: number | null;
};
type PnlNetoMes = { codigo: string; margen_neto: number };
type PropiedadRow = { codigo: string; modelo: Modelo; comision_pct_neta: number };

const hoyMadrid = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid" }).format(new Date());

export default async function Home({ searchParams }: { searchParams: { orden?: string } }) {
  const porIngreso = searchParams.orden === "ingreso";
  const hoyIso = hoyMadrid();
  const [anio, mes] = hoyIso.split("-").map(Number);
  type CuentaDuenaFila = FilaCuenta & { codigo: string };
  const inicioPrevio = `${anio}-${String(Math.max(mes - 1, 1)).padStart(2, "0")}-01`;

  const [kpisArr, freshArr, alertas, ranking, breakeven, costes, trend, pnlMes, noches,
    forward, forwardDias, pickup, pnlNetoMesActual, propiedades, cuadre, asegurado, resultadoArr,
    cuentaDuena] =
    await Promise.all([
      readView<Kpis>("v_kpis"),
      readView<Freshness>("v_freshness"),
      readView<AlertaV2>("v_alertas"),
      readView<RankingRow>("v_ranking_ytd"),
      readView<BreakevenRow>("v_breakeven_ytd"),
      readView<CosteRow>("v_costes_ytd"),
      readView<TrendRow>("v_trend_mensual", { order: { col: "mes" } }),
      readView<PnlMes>("v_pnl_mensual_propiedad", { order: { col: "mes" } }),
      mes > 1
        // v_noches_mtd, no v_reservation_nights: esta última trae `id` y `bruto_night`, con lo
        // que se reconstruye el ingreso por reserva — la fuga que cerró la migración 033.
        ? readView<NocheRow>("v_noches_mtd", { gte: { night: inicioPrevio }, lt: { night: hoyIso } })
        : Promise.resolve([] as NocheRow[]),
      readView<ForwardRow>("v_forward"),
      readView<ForwardDia>("v_forward_dias", { order: { col: "dia" } }),
      readView<PickupRow>("v_pickup"),
      readView<PnlNetoMes>("v_pnl_neto_propiedad", { eq: { anio, mes } }),
      readView<PropiedadRow>("v_propiedades"),
      readView<CuadreRow>("v_cuadre", { order: { col: "orden" } }),
      readView<AseguradoRow>("v_margen_asegurado", { order: { col: "mes" } }),
      readView<ResultadoRow>("v_resultado_samavi"),
      readView<CuentaDuenaFila>("v_cuenta_duena", { order: { col: "mes" } }),
    ]);

  const k = kpisArr[0];
  const fresh = freshArr[0];
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

  // ── Panel de salud: forward por propiedad, ordenado por severidad (peor primero) ──
  const PESO_SALUD = { critical: 0, warning: 1, good: 2 };
  const health: HealthData[] = ranking.map((r) => {
    const fw = forward.find((x) => x.codigo === r.codigo);
    const pk = pickup.find((x) => x.codigo === r.codigo);
    const be = breakeven.find((x) => x.codigo === r.codigo);
    const co = costes.find((x) => x.codigo === r.codigo);
    const pr = propiedades.find((x) => x.codigo === r.codigo);
    const ingresoNoches = Number(r.ingreso_samavi) - Number(r.ingreso_cancelaciones ?? 0);
    const revparEq = co && pr ? revparEquilibrio({
      modelo: pr.modelo,
      costesTotalesYtd: Math.abs(Number(co.total_costes)),
      diasDisponiblesYtd: Number(r.noches_disponibles),
      feeAparente: Number(r.bruto) > 0 ? 1 - ingresoNoches / Number(r.bruto) : 0,
      comisionModeloPct: Number(pr.comision_pct_neta),
    }) : null;
    const ocup7 = (fw?.noches_7 ?? 0) / 7;
    const ocup30 = (fw?.noches_30 ?? 0) / 30;
    const revparFwd30 = Number(fw?.bruto_30 ?? 0) / 30;
    const margenMes = pnlNetoMesActual.find((x) => x.codigo === r.codigo)?.margen_neto;
    const salud = estadoSalud({
      margenMes: margenMes == null ? null : Number(margenMes),
      ocup7, ocup30,
      ocupBreakeven: be?.ocup_breakeven == null ? null : Number(be.ocup_breakeven),
      revparFwd30, revparEq,
      diasSinVender: pk?.dias_sin_vender == null ? null : Number(pk.dias_sin_vender),
    });
    return {
      codigo: r.codigo, salud,
      dias: forwardDias.filter((d) => d.codigo === r.codigo).map((d) => ({ dia: d.dia, vendida: d.vendida })),
      ocup7, ocup30, revparFwd30, revparEq,
      margenMes: margenMes == null ? null : Number(margenMes),
      mesLabel: MESES[mes].toLowerCase(),
      reservas7d: Number(pk?.reservas_7d ?? 0),
      diasSinVender: pk?.dias_sin_vender == null ? null : Number(pk.dias_sin_vender),
    };
  }).sort((a, b) => (PESO_SALUD[a.salud.cls] - PESO_SALUD[b.salud.cls])
    || ((a.margenMes ?? 0) - (b.margenMes ?? 0)));

  // Línea global del negocio (próximos 30 días agregados)
  const nProps = Math.max(health.length, 1);
  const globalOcup7 = health.reduce((s, h) => s + h.ocup7, 0) / nProps;
  const globalOcup30 = health.reduce((s, h) => s + h.ocup30, 0) / nProps;
  const globalReservas7d = health.reduce((s, h) => s + h.reservas7d, 0);

  // ── Margen asegurado + YTD: las dos tablas comparten el orden de filas ──────
  const resultado = resultadoArr[0];
  const rowsYtd = [...ranking]
    .map((r) => ({
      codigo: r.codigo,
      ingreso_samavi: Number(r.ingreso_samavi),
      contribucion: Number(r.contribucion),
      contribucion_pct: Number(r.contribucion_pct),
      margen_neto: Number(r.margen_neto),
    }))
    .sort((a, b) => porIngreso
      ? b.ingreso_samavi - a.ingreso_samavi
      : b.contribucion - a.contribucion);

  const tabla = construirTabla(
    asegurado.map((r) => ({ ...r, margen_neto: Number(r.margen_neto), ocup_vendida: Number(r.ocup_vendida) })),
    Object.fromEntries(breakeven.map((b) => [b.codigo, b.ocup_breakeven == null ? null : Number(b.ocup_breakeven)])),
    rowsYtd.map((r) => r.codigo),
  );
  // Si no hay un cruce real que contar, la horquilla de eficiencia sí dice algo siempre.
  const cruce = cruceRentabilidad(rowsYtd) ?? spreadContribucion(rowsYtd);

  const cierreHasta = fresh?.cierre_hasta
    ? `${MESES[Number(fresh.cierre_hasta.split("-")[1])]} ${fresh.cierre_hasta.split("-")[0]}`
    : "—";

  return (
    <main className="container">
      <header className="header mc-header">
        <h1>Morning Check</h1>
        <div className="sub">{fechaLargaDia(hoyIso)} · Samavi Global Vision SL</div>
        <div className="stamp">
          Sync {fechaLarga(fresh?.last_sync ?? k?.last_sync)} · banco conciliado hasta {cierreHasta}
          {stampCuadre(cuadre) && (<>
            {" · "}
            <Link href="/cuadre"
              className={"stamp-cuadre " + (stampCuadre(cuadre)!.includes("✓") ? "pos" : "neg")}>
              {stampCuadre(cuadre)}
            </Link>
          </>)}
        </div>
      </header>

      {!supabaseConfigured ? (
        <div className="notice">
          Configurá <code>NEXT_PUBLIC_SUPABASE_URL</code> y <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </div>
      ) : null}

      {/* 1 · el titular ES la respuesta */}
      <p className="titular">{titular}</p>

      {/* 2 · salud: qué pasa en los próximos 30 días, propiedad por propiedad */}
      {forward.length > 0 && (<>
        <div className="section-title">Salud · próximos 30 días</div>
        <p className="global-linea">
          Negocio: <strong>{pct(globalOcup30, 0)}</strong> vendido a 30 días
          ({pct(globalOcup7, 0)} la semana entrante) · {globalReservas7d} reservas nuevas en 7 días
        </p>
        <div className="salud-filas">
          {health.map((h) => <SaludFila key={h.codigo} h={h} />)}
          <div className="tira30-leyenda">
            <span>lleno = noche vendida · hueco = libre</span>
            <span>hoy → 30 días</span>
          </div>
        </div>
      </>)}

      {/* 3 · el dinero que ya está puesto de aquí a fin de año */}
      {tabla.filas.length > 0 && (<>
        <div className="section-title">
          Margen neto asegurado · hasta diciembre
          <span className="toggle toggle-inline">
            <Link href="/" className={"toggle-btn" + (!porIngreso ? " active" : "")}>por aporte</Link>
            <Link href="/?orden=ingreso" className={"toggle-btn" + (porIngreso ? " active" : "")}>por ingreso</Link>
          </span>
        </div>
        <AseguradoTable tabla={tabla} mesActual={mes} />
        <AseguradoLeyenda tabla={tabla} resumen={resumenAsegurado(tabla)}
          sinEquilibrio={breakeven.length === 0} />

        <div className="section-title">Por propiedad · YTD {anio}</div>
        <YtdPropiedadTable rows={rowsYtd} anio={anio}
          corporativos={Number(resultado?.costes_corporativos ?? 0)}
          resultado={Number(resultado?.resultado_samavi ?? 0)} />
        {cruce ? <p className="cruce">{cruce}</p> : null}
      </>)}

      {/* 4 · vital signs del año corrido */}
      <div className="section-title">Vital signs · YTD {anio}</div>
      <KpiStrip items={kpiItems} />

      {/* 5 · qué requiere acción */}
      <div className="section-title">Requiere atención</div>
      <AlertStack rows={alertas} />

      {/* 6 · a dónde ir desde acá */}
      <div className="section-title">Ir a</div>
      <div className="tiles">
        <Link href="/analisis" className="tile">
          <span className="tile-ic" aria-hidden="true">📈</span>
          <span><span className="tile-t">Análisis</span>
            <span className="tile-s">tendencia y comparativas</span></span>
        </Link>
        <Link href="/simulador" className="tile">
          <span className="tile-ic" aria-hidden="true">🎚️</span>
          <span><span className="tile-t">Simulador</span>
            <span className="tile-s">¿y si muevo renta o precio?</span></span>
        </Link>
        <Link href="/cuadre" className="tile">
          <span className="tile-ic" aria-hidden="true">✓</span>
          <span><span className="tile-t">Cuadre</span>
            <span className="tile-s">integridad del modelo y banco</span></span>
        </Link>
        <Link href={`/p/${encodeURIComponent(health[0]?.codigo ?? "1A_NICA")}`} className="tile">
          <span className="tile-ic" aria-hidden="true">
            <span className="dot" style={{ background: propColor(health[0]?.codigo ?? "1A_NICA"), marginRight: 0 }} />
          </span>
          <span><span className="tile-t">{nombreCorto(health[0]?.codigo ?? "1A_NICA")}</span>
            <span className="tile-s">la que más atención pide</span></span>
        </Link>
        {cuentaDuena.length > 0 && (
          <Link href={`/p/${encodeURIComponent(cuentaDuena[0].codigo)}#cuenta-duena`} className="tile">
            <span className="tile-ic" aria-hidden="true">🧾</span>
            <span><span className="tile-t">Cuenta de la dueña</span>
              <span className="tile-s">
                a favor {eur(resumenCuentaDuena(cuentaDuena).neto)} · {nombreCorto(cuentaDuena[0].codigo)}
              </span></span>
          </Link>
        )}
      </div>

      <form action="/auth/signout" method="post" className="salir">
        <button type="submit" className="salir-btn">Cerrar sesión</button>
      </form>
    </main>
  );
}

/** "2026-07-16" → "jueves, 16 de julio de 2026" (sin depender del TZ del server) */
function fechaLargaDia(iso: string) {
  const [a, m, d] = iso.split("-").map(Number);
  return new Intl.DateTimeFormat("es-ES", { dateStyle: "full", timeZone: "UTC" })
    .format(new Date(Date.UTC(a, m - 1, d)));
}
