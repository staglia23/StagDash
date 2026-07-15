import { eur, pct } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type CosteRow = {
  codigo: string;
  renta: number;
  limpieza: number;
  suministros: number;
  comunidad: number;
  otros: number;
  total_directos: number;
  overhead: number;
  total_costes: number;
  pct_sobre_ingreso: number;
};

const suma = (rows: CosteRow[], k: keyof CosteRow) =>
  rows.reduce((a, r) => a + (Number(r[k]) || 0), 0);

/** showTotal=false en la ficha de una sola propiedad (la fila TOTAL sería redundante). */
export function CostesTable({ rows, showTotal = true }: { rows: CosteRow[]; showTotal?: boolean }) {
  return (
    <div className="table-wrap">
      <table className="ranking">
        <thead>
          <tr>
            <th>Propiedad</th>
            <th>Renta</th>
            <th>Limpieza</th>
            <th>Suministros</th>
            <th>Comunidad</th>
            <th>Otros</th>
            <th>Total directos</th>
            <th>Overhead</th>
            <th>Total costes</th>
            <th>% s/ Ingreso</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.codigo}>
              <td>
                <span className="dot" style={{ background: propColor(r.codigo) }} />
                {r.codigo}
              </td>
              <td className="num">{r.renta ? eur(r.renta) : "—"}</td>
              <td className="num">{r.limpieza ? eur(r.limpieza) : "—"}</td>
              <td className="num">{r.suministros ? eur(r.suministros) : "—"}</td>
              <td className="num">{r.comunidad ? eur(r.comunidad) : "—"}</td>
              <td className="num">{r.otros ? eur(r.otros) : "—"}</td>
              <td className="num">{eur(r.total_directos)}</td>
              <td className="num">{eur(r.overhead)}</td>
              <td className="num"><strong>{eur(r.total_costes)}</strong></td>
              <td className="num">{pct(r.pct_sobre_ingreso)}</td>
            </tr>
          ))}
          {showTotal && (
            <tr className="total">
              <td>TOTAL</td>
              <td className="num">{eur(suma(rows, "renta"))}</td>
              <td className="num">{eur(suma(rows, "limpieza"))}</td>
              <td className="num">{eur(suma(rows, "suministros"))}</td>
              <td className="num">{eur(suma(rows, "comunidad"))}</td>
              <td className="num">{eur(suma(rows, "otros"))}</td>
              <td className="num">{eur(suma(rows, "total_directos"))}</td>
              <td className="num">{eur(suma(rows, "overhead"))}</td>
              <td className="num">{eur(suma(rows, "total_costes"))}</td>
              <td className="num">—</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
