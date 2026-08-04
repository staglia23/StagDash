// Cuenta de la dueña (modelo comisión, hoy solo Jacobine) — migración 066.
// Es la cuenta DEVENGADA del año: lo que le pertenece por noche dormida, menos la
// refactura de limpieza y los recobros ya liquidados. NO resta las transferencias que
// ya se le hicieron (los pagos viven en los bancos, no en el motor) — el UI lo declara.
import { eur, MESES } from "@/lib/format";

export type CuentaDuenaRow = {
  codigo: string; anio: number; mes: number;
  pasivo_alquiler: number; pasivo_cancelaciones: number;
  limpieza: number; descuentos: number; neto: number;
};

export function CuentaDuena({
  rows, pendienteTotal, pendientePagos,
}: {
  rows: CuentaDuenaRow[];
  pendienteTotal: number;
  pendientePagos: number;
}) {
  if (rows.length === 0) return null;
  const anio = rows[0].anio;

  // El mes en curso se muestra pero no entra al titular: lleva la limpieza completa
  // contra pocos días de alquiler devengado y desfiguraría el total (rango a mes completo).
  // "Hoy" en hora de Madrid, no del dispositivo (mismo criterio que page.tsx / format.ts).
  const [hoyY, hoyM] = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Madrid", year: "numeric", month: "2-digit",
  }).format(new Date()).split("-").map(Number);
  const esEnCurso = (r: CuentaDuenaRow) => r.anio === hoyY && r.mes === hoyM;
  const cerrados = rows.filter((r) => !esEnCurso(r));
  const enCurso = rows.find(esEnCurso);

  const suma = (sel: (r: CuentaDuenaRow) => number) =>
    cerrados.reduce((s, r) => s + Number(sel(r)), 0);
  const alquiler = suma((r) => r.pasivo_alquiler);
  const cancel = suma((r) => r.pasivo_cancelaciones);
  const limpieza = suma((r) => r.limpieza);
  const descuentos = suma((r) => r.descuentos);
  const neto = suma((r) => r.neto);

  return (
    <>
      <div className="section-title">
        Cuenta de la dueña · {anio} <span className="badge badge-real">real · devengado</span>
      </div>
      <div className="card">
        <div className="kpi-label">A favor de la dueña · meses completos de {anio}</div>
        <div className="kpi-value">{cerrados.length > 0 ? eur(neto, 2) : "—"}</div>
        {cerrados.length > 0 ? (
          <div className="kpi-sub">
            Le pertenece {eur(alquiler + cancel, 2)}
            {cancel > 0 ? ` (incluye ${eur(cancel, 2)} de cancelaciones retenidas)` : ""} ·
            limpieza −{eur(Math.abs(limpieza), 2)} · gastos descontados −{eur(Math.abs(descuentos), 2)}
          </div>
        ) : (
          <div className="kpi-sub">
            {enCurso ? `${MESES[enCurso.mes]} en curso` : "Año recién empezado"} — todavía
            sin mes completo que liquidar.
          </div>
        )}
        {pendienteTotal > 0 && (
          <div className="kpi-sub cuenta-pend">
            ⏳ Por descontar cuando se liquiden: {eur(pendienteTotal, 2)} ({pendientePagos}{" "}
            {pendientePagos === 1 ? "recobro pendiente" : "recobros pendientes"})
          </div>
        )}
        <p className="section-note cuenta-nota">
          Cuenta devengada del año: no resta lo ya transferido a la dueña. El saldo
          anterior a {anio} vive en el proyecto de Admin &amp; Fiscal.
        </p>
      </div>

      <div className="table-wrap" style={{ marginTop: 12 }}>
        <table className="ranking">
          <thead>
            <tr>
              <th>Mes</th><th>Alquiler</th><th>Cancelaciones</th>
              <th>Limpieza</th><th>Descuentos</th><th>Neto dueña</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={`${r.anio}-${r.mes}`}>
                <td>
                  {MESES[r.mes]} {r.anio}
                  {enCurso === r ? <span className="tag"> · en curso</span> : ""}
                </td>
                <td className="num">{eur(r.pasivo_alquiler, 2)}</td>
                <td className="num">{Number(r.pasivo_cancelaciones) > 0 ? eur(r.pasivo_cancelaciones, 2) : "—"}</td>
                <td className="num">−{eur(Math.abs(Number(r.limpieza)), 2)}</td>
                <td className="num">{Number(r.descuentos) !== 0 ? `−${eur(Math.abs(Number(r.descuentos)), 2)}` : "—"}</td>
                <td className={"num " + (Number(r.neto) >= 0 ? "pos" : "neg")}>
                  {Number(r.neto) >= 0 ? "+" : "−"}{eur(Math.abs(Number(r.neto)), 2)}
                </td>
              </tr>
            ))}
            {cerrados.length > 0 && (
              <tr className="total">
                <td>Total meses completos</td>
                <td className="num">{eur(alquiler, 2)}</td>
                <td className="num">{cancel > 0 ? eur(cancel, 2) : "—"}</td>
                <td className="num">−{eur(Math.abs(limpieza), 2)}</td>
                <td className="num">−{eur(Math.abs(descuentos), 2)}</td>
                <td className={"num " + (neto >= 0 ? "pos" : "neg")}>{neto >= 0 ? "+" : "−"}{eur(Math.abs(neto), 2)}</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
