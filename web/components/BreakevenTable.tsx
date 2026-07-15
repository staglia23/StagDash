import { eur, pct, pp } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type BreakevenRow = {
  codigo: string;
  costes_fijos: number;
  contribucion_noche: number;
  noches_necesarias: number | null;
  ocup_breakeven: number | null;
  ocup_actual: number;
  colchon: number | null;
};

/** El colchón nunca va por color solo: siempre icono + etiqueta. */
function Colchon({ v }: { v: number | null }) {
  if (v == null) return <span className="muted">—</span>;
  const negativo = v < 0;
  const ajustado = v < 0.1;
  const cls = negativo ? "neg" : ajustado ? "warn" : "pos";
  const icon = negativo ? "▼" : ajustado ? "⚠" : "▲";
  const label = negativo ? "en pérdida" : ajustado ? "ajustado" : "holgado";
  return (
    <span className={cls}>
      {icon} {pp(v)} <span className="tag">{label}</span>
    </span>
  );
}

export function BreakevenTable({ rows }: { rows: BreakevenRow[] }) {
  return (
    <div className="table-wrap">
      <table className="ranking">
        <thead>
          <tr>
            <th>Propiedad</th>
            <th>Costes fijos</th>
            <th>Aporta / noche</th>
            <th>Noches p/ cubrir</th>
            <th>Ocup. equilibrio</th>
            <th>Ocup. real</th>
            <th>Colchón</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.codigo}>
              <td>
                <span className="dot" style={{ background: propColor(r.codigo) }} />
                {r.codigo}
              </td>
              <td className="num">{eur(r.costes_fijos)}</td>
              <td className="num">{eur(r.contribucion_noche)}</td>
              <td className="num">{r.noches_necesarias ?? "—"}</td>
              <td className="num">{r.ocup_breakeven == null ? "—" : pct(r.ocup_breakeven)}</td>
              <td className="num">{pct(r.ocup_actual)}</td>
              <td className="num"><Colchon v={r.colchon} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
