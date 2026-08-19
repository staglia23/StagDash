// Recobros — plata adelantada (por Samavi o del bolsillo de Stag) que se repercute a un
// tercero. Fuera del P&L: neutro mientras sea recobrable (migración 065). La tarjeta
// existe porque lo pagado por fuera (bizum personal, efectivo) no aparece en los
// extractos de Samavi y la conciliación mensual no lo ve.
//
// Desde la 089 se muestran en DOS CARRILES, porque no se cobran igual (decisión de Stag,
// 19/08/2026): lo que puso Samavi se le descuenta a la dueña en su cuenta corriente, y lo
// que puso Stag de su bolsillo lo arreglan madre e hijo entre ellos. Mezclarlos hacía que
// la sociedad se quedara con dinero que había puesto él — pasó con los 83 € de la 077.
import { eur } from "@/lib/format";

export type RecobroRow = {
  id: number; propiedad_codigo: string; fecha: string; concepto: string; importe: number;
  pagado_por: string; pagado_a: string | null; medio: string | null; estado: string;
  liquidacion: string;
  resuelto_fecha: string | null; resuelto_nota: string | null; dias_pendiente: number | null;
};
export type RecobrosPendRow = {
  propiedad_codigo: string; pagos: number; total: number;
  mas_viejo_fecha: string; mas_viejo_dias: number; de_cuenta_personal: number;
  pagos_cuenta: number; total_cuenta: number;
  pagos_directo: number; total_directo: number;
};

const fechaCorta = (iso: string | null) => {
  if (!iso) return "—";
  const [a, m, d] = iso.split("-");
  return `${d}/${m}/${a}`;
};

const ESTADO: Record<string, { icon: string; label: string; cls: string }> = {
  PENDIENTE: { icon: "⏳", label: "Pendiente", cls: "warn" },
  LIQUIDADO: { icon: "✓", label: "Liquidado", cls: "pos" },
  INCOBRABLE: { icon: "✖", label: "Incobrable (pasó a gasto)", cls: "neg" },
};

function Fila({ r }: { r: RecobroRow }) {
  const e = ESTADO[r.estado] ?? { icon: "—", label: r.estado, cls: "muted" };
  return (
    <li className={"recobro" + (r.estado === "PENDIENTE" ? "" : " recobro-resuelto")}>
      <div className="recobro-top">
        <span className="recobro-fecha">{fechaCorta(r.fecha)}</span>
        <span className="recobro-importe">{eur(r.importe, 2)}</span>
      </div>
      <div className="recobro-concepto">{r.concepto}</div>
      <div className="recobro-meta">
        {r.medio ? <span className="chip-rec">{r.medio}{r.pagado_a ? ` → ${r.pagado_a}` : ""}</span> : null}
        <span className="chip-rec">
          {r.pagado_por === "STAG_PERSONAL" ? "cuenta personal de Stag" : "cuenta de Samavi"}
        </span>
        <span className={"recobro-estado " + e.cls}>
          {e.icon} {e.label}
          {r.estado === "PENDIENTE" && r.dias_pendiente != null
            ? ` · ${Math.max(0, r.dias_pendiente) === 0 ? "de hoy" : `${r.dias_pendiente} día${r.dias_pendiente === 1 ? "" : "s"}`}`
            : r.resuelto_fecha ? ` · ${fechaCorta(r.resuelto_fecha)}` : ""}
        </span>
      </div>
    </li>
  );
}

/** Un carril: cómo vuelve ese dinero, cuánto es, y las filas que lo componen. */
function Carril({
  titulo, icono, total, filas, nota,
}: {
  titulo: string; icono: string; total: number; filas: RecobroRow[]; nota: React.ReactNode;
}) {
  if (filas.length === 0) return null;
  return (
    <div className="carril">
      <div className="carril-top">
        <span className="carril-titulo"><span aria-hidden="true">{icono}</span> {titulo}</span>
        <span className="carril-total">{eur(total, 2)}</span>
      </div>
      <p className="carril-nota">{nota}</p>
      <ul className="recobros-lista">{filas.map((r) => <Fila key={r.id} r={r} />)}</ul>
    </div>
  );
}

export function RecobrosCard({ rows, pend }: { rows: RecobroRow[]; pend?: RecobrosPendRow }) {
  if (rows.length === 0) return null;
  const pendientes = rows.filter((r) => r.estado === "PENDIENTE");
  const resueltos = rows.filter((r) => r.estado !== "PENDIENTE");
  const porCuenta = pendientes.filter((r) => r.liquidacion === "CUENTA_DUENA");
  const porDirecto = pendientes.filter((r) => r.liquidacion === "DIRECTO_FAMILIA");

  return (
    <>
      <div className="section-title">
        Recobros — plata adelantada <span className="badge badge-fuera">fuera del P&L</span>
      </div>
      <div className="card">
        <div className="kpi-label">Por recuperar de la dueña</div>
        <div className="kpi-value">{eur(Number(pend?.total ?? 0), 2)}</div>
        <div className="kpi-sub">
          {pend
            ? `${pend.pagos} ${pend.pagos === 1 ? "pago" : "pagos"} · el más viejo lleva ${pend.mas_viejo_dias} ${Number(pend.mas_viejo_dias) === 1 ? "día" : "días"} sin recuperar`
            : "Nada pendiente — no hay plata adelantada sin recuperar."}
        </div>

        <Carril
          titulo="Se le descuenta en su cuenta"
          icono="🧾"
          total={Number(pend?.total_cuenta ?? 0)}
          filas={porCuenta}
          nota={<>Lo puso Samavi y a Samavi vuelve: baja lo que la sociedad le debe. Es la
            única parte que sale en la cuenta de arriba.</>}
        />

        <Carril
          titulo="Lo arreglás vos con ella"
          icono="🤝"
          total={Number(pend?.total_directo ?? 0)}
          filas={porDirecto}
          nota={<><strong>Fuera de Samavi</strong>: salió de tu cuenta personal y te lo
            devuelve ella, en efectivo o compensando. La sociedad ni entra ni sale, y por eso
            no toca su cuenta ni el P&L. Ojo: los extractos de Samavi no lo ven —
            si no queda escrito acá, se pierde.</>}
        />

        {resueltos.length > 0 && (
          <details className="recobros-hist">
            <summary>Historial resuelto ({resueltos.length})</summary>
            <ul className="recobros-lista">{resueltos.map((r) => <Fila key={r.id} r={r} />)}</ul>
          </details>
        )}
      </div>
    </>
  );
}
