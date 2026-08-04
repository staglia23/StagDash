// Cuenta de la dueña (modelo comisión, hoy solo Jacobine) — migraciones 066/067.
// Es la cuenta DEVENGADA del año: lo que le pertenece por noche dormida, menos la
// refactura de limpieza y los recobros ya liquidados. NO resta las transferencias que
// ya se le hicieron (los pagos viven en los bancos, no en el motor) — el UI lo declara.
//
// Forma de recibo, no tabla suelta: la pregunta que responde es "cuánto le debo y por
// qué se le descuenta", y una cascada de 4 líneas se lee de un vistazo en el móvil.
import { propColor } from "@/lib/colors";
import { resumenCuentaDuena, type FilaCuenta } from "@/lib/cuentaDuena";
import { eur, MESES } from "@/lib/format";

export type CuentaDuenaRow = FilaCuenta & { codigo: string };

export function CuentaDuena({
  rows, codigo, pendienteTotal, pendientePagos,
}: {
  rows: CuentaDuenaRow[];
  codigo: string;
  pendienteTotal: number;
  pendientePagos: number;
}) {
  if (rows.length === 0) return null;
  const anio = rows[0].anio;
  const r = resumenCuentaDuena(rows);
  const { cerrados, enCurso } = r;
  const hayCerrados = cerrados.length > 0;
  const color = propColor(codigo);

  const rango = hayCerrados
    ? (cerrados.length === 1
      ? `${MESES[cerrados[0].mes]}`
      : `${MESES[cerrados[0].mes]}–${MESES[cerrados[cerrados.length - 1].mes]}`)
    : "";

  // Proporciones de la barra: sobre lo devengado, cuánto queda para ella y cuánto se va
  const pct = (v: number) => (r.devengado > 0 ? Math.max(0, (v / r.devengado) * 100) : 0);
  const anchoNeto = pct(r.neto);
  const anchoLimpieza = pct(Math.abs(r.limpieza));
  const anchoGastos = pct(Math.abs(r.descuentos));

  return (
    <>
      <div className="section-title" id="cuenta-duena">
        Cuenta de la dueña · {anio} <span className="badge badge-real">real · devengado</span>
      </div>

      <div className="card cuenta-card">
        <div className="kpi-label">
          A favor de la dueña{hayCerrados ? ` · ${rango} ${anio}` : ""}
        </div>
        <div className="kpi-value" style={{ color: hayCerrados ? undefined : "var(--muted)" }}>
          {hayCerrados ? eur(r.neto, 2) : "—"}
        </div>

        {hayCerrados ? (
          <>
            {/* Barra de composición: qué parte de lo devengado se queda ella y qué se le
                descuenta. Cada segmento lleva su cifra en el recibo de abajo (nunca color solo). */}
            <div className="cuenta-barra" role="img"
              aria-label={`De ${eur(r.devengado, 2)} devengados, ${eur(r.neto, 2)} quedan a favor de la dueña, ${eur(Math.abs(r.limpieza), 2)} son limpieza y ${eur(Math.abs(r.descuentos), 2)} gastos repercutidos`}>
              <span className="cb-seg cb-neto" style={{ width: `${anchoNeto}%`, background: color }} />
              <span className="cb-seg cb-limp" style={{ width: `${anchoLimpieza}%` }} />
              <span className="cb-seg cb-gast" style={{ width: `${anchoGastos}%` }} />
            </div>

            <dl className="recibo">
              <div>
                <dt>Alquiler devengado</dt>
                <dd className="pos">+{eur(r.alquiler, 2)}</dd>
              </div>
              {r.cancelaciones > 0 && (
                <div>
                  <dt>Cancelaciones retenidas <span className="recibo-nota">su parte, ya descontada tu comisión</span></dt>
                  <dd className="pos">+{eur(r.cancelaciones, 2)}</dd>
                </div>
              )}
              <div>
                <dt>Limpieza <span className="recibo-nota">{eur(700)}/mes × {cerrados.length}</span></dt>
                <dd className="neg">−{eur(Math.abs(r.limpieza), 2)}</dd>
              </div>
              <div>
                <dt>Gastos repercutidos <span className="recibo-nota">reparaciones y reposiciones</span></dt>
                <dd className="neg">
                  {r.descuentos === 0 ? "—" : `−${eur(Math.abs(r.descuentos), 2)}`}
                </dd>
              </div>
              <div className="recibo-total">
                <dt>A favor de la dueña</dt>
                <dd className={r.neto >= 0 ? "pos" : "neg"}>
                  {r.neto >= 0 ? "" : "−"}{eur(Math.abs(r.neto), 2)}
                </dd>
              </div>
            </dl>
          </>
        ) : (
          <div className="kpi-sub">
            {enCurso ? `${MESES[enCurso.mes]} en curso` : "Año recién empezado"} — todavía sin
            mes completo que liquidar.
          </div>
        )}

        {pendienteTotal > 0 && (
          <div className="cuenta-pend">
            ⏳ <strong>{eur(pendienteTotal, 2)}</strong> más por descontarle cuando liquides
            los {pendientePagos === 1 ? "el recobro pendiente" : `${pendientePagos} recobros pendientes`} de abajo
          </div>
        )}

        <p className="section-note cuenta-nota">
          Es lo que le corresponde por las noches del año, no lo que queda por transferirle:
          esta cuenta no resta los pagos que ya le hiciste. El saldo anterior a {anio} vive en
          el proyecto de Admin &amp; Fiscal.
        </p>
      </div>

      <details className="cuenta-detalle">
        <summary>Ver mes a mes ({rows.length} {rows.length === 1 ? "mes" : "meses"})</summary>
        <div className="table-wrap">
          <table className="ranking">
            <thead>
              <tr>
                <th>Mes</th><th>Alquiler</th><th>Cancelaciones</th>
                <th>Limpieza</th><th>Gastos</th><th>Neto dueña</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((f) => (
                <tr key={`${f.anio}-${f.mes}`}>
                  <td>
                    {MESES[f.mes]} {f.anio}
                    {enCurso === f ? <span className="tag"> · en curso</span> : ""}
                  </td>
                  <td className="num">{eur(Number(f.pasivo_alquiler), 2)}</td>
                  <td className="num">{Number(f.pasivo_cancelaciones) > 0 ? eur(Number(f.pasivo_cancelaciones), 2) : "—"}</td>
                  <td className="num">−{eur(Math.abs(Number(f.limpieza)), 2)}</td>
                  <td className="num">{Number(f.descuentos) !== 0 ? `−${eur(Math.abs(Number(f.descuentos)), 2)}` : "—"}</td>
                  <td className={"num " + (Number(f.neto) >= 0 ? "pos" : "neg")}>
                    {Number(f.neto) >= 0 ? "+" : "−"}{eur(Math.abs(Number(f.neto)), 2)}
                  </td>
                </tr>
              ))}
              {hayCerrados && (
                <tr className="total">
                  <td>Total {rango}</td>
                  <td className="num">{eur(r.alquiler, 2)}</td>
                  <td className="num">{r.cancelaciones > 0 ? eur(r.cancelaciones, 2) : "—"}</td>
                  <td className="num">−{eur(Math.abs(r.limpieza), 2)}</td>
                  <td className="num">−{eur(Math.abs(r.descuentos), 2)}</td>
                  <td className={"num " + (r.neto >= 0 ? "pos" : "neg")}>
                    {r.neto >= 0 ? "+" : "−"}{eur(Math.abs(r.neto), 2)}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </details>
    </>
  );
}
