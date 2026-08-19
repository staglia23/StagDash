// /cobros — por dónde entra el dinero. Pedido de Stag (18/08/2026).
//
// OJO con la métrica: acá el importe es el del PAGO, no el ingreso Samavi. Esta pantalla
// responde "¿por dónde entró la plata?" (caja), no "¿cuánto ganamos?" (P&L) — en Jacobine un
// cobro de 520 € deja 130 € a Samavi. Por eso todo se etiqueta como **cobrado** y la pantalla
// vive separada del ranking. La clasificación es dato duro: sale de guesty_payment_methods
// (migración 087), no de interpretar el texto de las notas. Ver docs/operativa/COBROS.md.
import Link from "next/link";
import CobrosDonut from "@/components/CobrosDonut";
import { porSanear, resumen, type CobroRow } from "@/lib/cobros";
import { eur, fechaLarga } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import { readView, supabaseConfigured } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Freshness = { last_sync: string | null };

const ANIO = new Date().getFullYear();

export default async function Cobros() {
  const [rows, freshArr] = await Promise.all([
    readView<CobroRow>("v_cobros", {
      gte: { checkin_local: `${ANIO}-01-01` },
      lt: { checkin_local: `${ANIO + 1}-01-01` },
    }),
    readView<Freshness>("v_freshness"),
  ]);

  if (!supabaseConfigured) {
    return (
      <main className="container">
        <Link className="backlink" href="/">← Morning Check</Link>
        <p className="empty">Sin conexión a datos.</p>
      </main>
    );
  }

  const r = resumen(rows);
  const sanear = porSanear(rows);

  return (
    <main className="container">
      <Link className="backlink" href="/">← Morning Check</Link>
      <header className="header">
        <h1>Cobros</h1>
        <div className="sub">
          Por dónde entra la plata en {ANIO}. Es <b>caja, no margen</b>: el importe es lo que
          cobraste, no lo que le queda a Samavi.
        </div>
        <div className="stamp">Con el dato de las {fechaLarga(freshArr[0]?.last_sync)}</div>
      </header>

      <div className="kpi-grid">
        <div className="card">
          <div className="kpi-label">Cobrado en {ANIO}</div>
          <div className="kpi-value">{eur(r.total)}</div>
          <div className="kpi-sub">{r.nCobros} cobros de reservas confirmadas</div>
        </div>
        <div className="card">
          <div className="kpi-label">No aparece en el banco español</div>
          <div className="kpi-value">{eur(r.fueraDeBanco)}</div>
          <div className="kpi-sub">
            Efectivo y cuenta USD de Argentina → cuenta con el socio. En el cuadre mensual no
            hay que buscarlos.
          </div>
        </div>
        <div className="card">
          <div className="kpi-label">Cobros previstos, todavía sin entrar</div>
          <div className="kpi-value">{eur(r.previsto)}</div>
          <div className="kpi-sub">
            {r.nPrevisto} pago{r.nPrevisto === 1 ? "" : "s"} programado
            {r.nPrevisto === 1 ? "" : "s"} de reservas futuras. No cuentan como cobrado.
          </div>
        </div>
      </div>

      <h2 className="section-title">El reparto</h2>
      <div className="card">
        <CobrosDonut rows={rows} />
      </div>

      {sanear.length > 0 && (
        <>
          <h2 className="section-title">Falta la nota en Guesty</h2>
          <div className="card">
            <p className="cobros-hint" style={{ marginTop: 0 }}>
              <b>{eur(r.sinNota)}</b> en {r.nSinNota} cobro{r.nSinNota === 1 ? "" : "s"} sin nota:
              no se puede saber si ese dinero aparece en un extracto español o no. Se arregla
              abriendo la reserva en Guesty y escribiendo la nota con su prefijo
              (<code>EFECTIVO —</code>, <code>GALICIA-USD —</code>, <code>REVOLUT —</code>,{" "}
              <code>BBVA —</code>).
            </p>
            <div className="table-wrap">
              <table className="ranking cobros-tabla">
                <thead>
                  <tr><th>Piso</th><th>Entrada</th><th>Cobrado</th><th>Cobro</th><th>Reserva</th></tr>
                </thead>
                <tbody>
                  {sanear.map((f, i) => (
                    <tr key={(f.confirmation_code ?? "") + i}>
                      <td>{nombreCorto(f.codigo)}</td>
                      <td>{f.checkin_local.slice(8, 10)}/{f.checkin_local.slice(5, 7)}</td>
                      <td>{eur(f.importe, 2)}</td>
                      <td>{f.metodo}</td>
                      <td className="mono">{f.confirmation_code ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </main>
  );
}
