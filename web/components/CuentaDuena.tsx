// Cuenta de la dueña (modelo comisión, hoy solo Jacobine) — migraciones 066/067.
// Es la cuenta DEVENGADA del año: lo que le pertenece por noche dormida, menos la
// refactura de limpieza y los recobros ya liquidados. NO resta las transferencias que
// ya se le hicieron (los pagos viven en los bancos, no en el motor) — el UI lo declara.
//
// Forma de recibo, no tabla suelta: la pregunta que responde es "cuánto le debo y por
// qué se le descuenta", y una cascada de 4 líneas se lee de un vistazo en el móvil.
import { propColor } from "@/lib/colors";
import { desgloseLiquidacion, resumenCuentaDuena, type FilaCuenta } from "@/lib/cuentaDuena";
import { eur, MESES } from "@/lib/format";

export type CuentaDuenaRow = FilaCuenta & { codigo: string };

export function CuentaDuena({
  rows, codigo, nombre, pendienteTotal, pendientePagos, bizumsDirectos = 0,
}: {
  rows: CuentaDuenaRow[];
  codigo: string;
  /** Nombre de display: en pantalla nunca aparece el código de la propiedad. */
  nombre: string;
  pendienteTotal: number;
  pendientePagos: number;
  /** Bizums pendientes que ella le debe a Stag (carril directo, 089). */
  bizumsDirectos?: number;
}) {
  if (rows.length === 0) return null;
  const r = resumenCuentaDuena(rows);
  const { cerrados, enCurso, porAnio } = r;
  const hayCerrados = cerrados.length > 0;
  const color = propColor(codigo);
  const anio = rows[rows.length - 1].anio;

  const liq = desgloseLiquidacion(r.neto, bizumsDirectos);
  const rango = hayCerrados
    ? `${MESES[cerrados[0].mes]} ${cerrados[0].anio} – ${MESES[cerrados[cerrados.length - 1].mes]} ${cerrados[cerrados.length - 1].anio}`
    : "";

  // Proporciones de la barra: sobre lo devengado, cuánto queda para ella y cuánto se va
  const pct = (v: number) => (r.devengado > 0 ? Math.max(0, (v / r.devengado) * 100) : 0);
  const anchoNeto = pct(r.neto);
  const anchoLimpieza = pct(Math.abs(r.limpieza));
  const anchoGastos = pct(Math.abs(r.descuentos));

  return (
    <>
      <div className="section-title" id="cuenta-duena">
        Cuenta de la dueña <span className="badge badge-real">real · devengado</span>
      </div>

      <div className="card cuenta-card">
        <div className="kpi-label">
          A favor de la dueña de {nombre}{hayCerrados ? ` · ${rango}` : ""}
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

            {/* Un bloque por año: la cuenta es acumulativa y 2025 sigue vivo porque no se
                le ha transferido nada. Sin esto, el total no se sabe de dónde sale. */}
            {porAnio.length > 1 && (
              <dl className="recibo recibo-anios">
                {porAnio.map((a) => (
                  <div key={a.anio}>
                    <dt>
                      Saldo {a.anio}
                      <span className="recibo-nota">{a.meses} {a.meses === 1 ? "mes" : "meses"}</span>
                    </dt>
                    <dd className={a.neto >= 0 ? "pos" : "neg"}>
                      {a.neto >= 0 ? "+" : "−"}{eur(Math.abs(a.neto), 2)}
                    </dd>
                  </div>
                ))}
              </dl>
            )}

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
                <dt>Limpieza
                  <span className="recibo-nota">
                    {cerrados.length} meses · a coste real hasta oct-2025, {eur(700)}/mes desde nov-2025
                  </span>
                </dt>
                <dd className="neg">−{eur(Math.abs(r.limpieza), 2)}</dd>
              </div>
              <div>
                <dt>Gastos repercutidos <span className="recibo-nota">reparaciones y reposiciones</span></dt>
                <dd className="neg">
                  {r.descuentos === 0 ? "—" : `−${eur(Math.abs(r.descuentos), 2)}`}
                </dd>
              </div>
              <div className={liq.bizums > 0 ? "recibo-sub" : "recibo-total"}>
                <dt>A favor de la dueña</dt>
                <dd className={r.neto >= 0 ? "pos" : "neg"}>
                  {r.neto >= 0 ? "" : "−"}{eur(Math.abs(r.neto), 2)}
                </dd>
              </div>

              {/* El reparto que pidió Stag (20/08/2026): de lo que Samavi le debe, cuánto se
                  tapa con los bizums que ella le debe a él y cuánto queda por transferir.
                  Son deudas entre partes distintas: por eso dice "si lo compensás". */}
              {liq.bizums > 0 && (
                <>
                  <div>
                    <dt>
                      Bizums que ella te debe a vos
                      <span className="recibo-nota">
                        los pusiste de tu bolsillo · se arreglan por fuera de Samavi
                      </span>
                    </dt>
                    <dd className="neg">−{eur(liq.bizums, 2)}</dd>
                  </div>
                  <div className="recibo-total">
                    <dt>
                      A transferirle
                      <span className="recibo-nota">si lo compensás al liquidarle</span>
                    </dt>
                    <dd className={liq.aTransferir >= 0 ? "pos" : "neg"}>
                      {liq.aTransferir >= 0 ? "" : "−"}{eur(Math.abs(liq.aTransferir), 2)}
                    </dd>
                  </div>
                </>
              )}
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
            {pendientePagos === 1 ? " el recobro pendiente" : ` los ${pendientePagos} recobros pendientes`}
            {" "}de abajo que pagó Samavi
          </div>
        )}

        <p className="section-note cuenta-nota">
          Acumulado desde que arrancó el piso, imputado por noche dormida. <strong>No resta
          pagos</strong>: si le transferís algo, hay que registrarlo aparte para que este
          número deje de ser la deuda entera.
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
