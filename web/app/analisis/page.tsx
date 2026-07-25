// /analisis — el diagnóstico de un minuto que antes vivía al pie de la portada.
// La portada responde "¿qué pasa hoy?"; esta página responde "¿por qué?": tendencia del
// margen, comparación entre las 4 propiedades y el futuro ya confirmado.
// Sale de la portada por los accesos "Ir a" (02_Prompt §5.1: la portada no acumula tablas).
import Link from "next/link";
import { BreakevenTable, type BreakevenRow } from "@/components/BreakevenTable";
import { BulletBreakeven } from "@/components/BulletBreakeven";
import { CanalTable, type CanalRow } from "@/components/CanalTable";
import { CostesTable, type CosteRow } from "@/components/CostesTable";
import { DelMargenALaCaja } from "@/components/DelMargenALaCaja";
import { OnTheBooksTable, type OtbRow } from "@/components/OnTheBooksTable";
import { RankingTable, type RankingRow } from "@/components/RankingTable";
import { Tabs } from "@/components/Tabs";
import { TrendChart } from "@/components/TrendChart";
import { propColor } from "@/lib/colors";
import { pct } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import { readView } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type TrendRow = { anio: number; mes: number; ingreso_samavi: number; margen_directo: number; margen_neto: number };
type ResultadoRow = {
  contribucion: number; overhead_operativo: number; margen_operativo: number;
  costes_corporativos: number; resultado_samavi: number;
};

export default async function Analisis({ searchParams }: { searchParams: { margen?: string } }) {
  const verDirecto = searchParams.margen === "directo";
  const anio = new Date().getFullYear();

  const [trend, ranking, breakeven, costes, canal, otb, resultadoArr] = await Promise.all([
    readView<TrendRow>("v_trend_mensual", { order: { col: "mes" } }),
    readView<RankingRow & { margen_directo: number; bruto: number; ingreso_cancelaciones: number; noches_disponibles: number; margen_neto: number; iva_repercutido: number }>("v_ranking_ytd"),
    readView<BreakevenRow>("v_breakeven_ytd"),
    readView<CosteRow & { renta_iva: number }>("v_costes_ytd"),
    readView<CanalRow>("v_canal_ytd"),
    readView<OtbRow>("v_on_the_books"),
    readView<ResultadoRow>("v_resultado_samavi"),
  ]);
  const resultado = resultadoArr[0];

  const codigos = ranking.map((r) => r.codigo);
  const ivaRepercutido = ranking.reduce((s, r) => s + Number(r.iva_repercutido ?? 0), 0);
  const ivaSoportadoRenta = costes.reduce((s, c) => s + Number((c as { renta_iva?: number }).renta_iva ?? 0), 0);

  // Mix de canal: la dependencia de Airbnb es señal permanente (§6.2)
  const ingresoCanal = (pred: (r: CanalRow) => boolean) =>
    canal.filter(pred).reduce((s, r) => s + Number(r.ingreso), 0);
  const totalCanal = ingresoCanal(() => true);
  const pctAirbnb = totalCanal > 0 ? ingresoCanal((r) => r.canal.startsWith("airbnb")) / totalCanal : 0;
  const jacoAirbnb = ingresoCanal((r) => r.codigo === "1A_JACO" && r.canal.startsWith("airbnb"));
  const jacoTotal = ingresoCanal((r) => r.codigo === "1A_JACO");

  return (
    <main className="container">
      <header className="header">
        <Link href="/" className="volver">← Morning Check</Link>
        <h1>Análisis</h1>
        <div className="sub">Por qué el negocio está donde está · real devengado {anio}</div>
      </header>

      <div className="section-title">Del margen a la caja · YTD {anio}</div>
      <DelMargenALaCaja
        contribucion={Number(resultado?.contribucion ?? 0)}
        overheadOperativo={Number(resultado?.overhead_operativo ?? 0)}
        margenOperativo={Number(resultado?.margen_operativo ?? 0)}
        costesCorporativos={Number(resultado?.costes_corporativos ?? 0)}
        resultado={Number(resultado?.resultado_samavi ?? 0)}
        ivaRepercutido={ivaRepercutido} ivaSoportadoRenta={ivaSoportadoRenta} anio={anio} />

      <div className="section-title">
        Tendencia margen {verDirecto ? "directo" : "neto"} mensual
        <span className="toggle toggle-inline">
          <Link href="/analisis" className={"toggle-btn" + (!verDirecto ? " active" : "")}>neto</Link>
          <Link href="/analisis?margen=directo" className={"toggle-btn" + (verDirecto ? " active" : "")}>directo</Link>
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
        ]}
      />

      <div className="section-title">Ya reservado · futuro confirmado</div>
      <OnTheBooksTable
        rows={[...otb].sort((a, b) => (a.anio - b.anio) || (a.mes - b.mes))}
        codigos={codigos}
      />
    </main>
  );
}
