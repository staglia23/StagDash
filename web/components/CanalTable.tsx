import { eur, pct, canalNombre } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type CanalRow = { codigo: string; canal: string; reservas: number; ingreso: number };

/** Pivot: filas = canal, columnas = propiedades. Responde "¿de dónde viene la plata?". */
export function CanalTable({ rows, codigos }: { rows: CanalRow[]; codigos: string[] }) {
  const canales = Array.from(new Set(rows.map((r) => r.canal)));
  const get = (canal: string, codigo: string) =>
    rows.find((r) => r.canal === canal && r.codigo === codigo)?.ingreso ?? 0;
  const totalCanal = (canal: string) =>
    rows.filter((r) => r.canal === canal).reduce((a, r) => a + Number(r.ingreso), 0);
  const granTotal = rows.reduce((a, r) => a + Number(r.ingreso), 0);

  // canales ordenados por ingreso (mayor primero)
  canales.sort((a, b) => totalCanal(b) - totalCanal(a));

  return (
    <div className="table-wrap">
      <table className="ranking">
        <thead>
          <tr>
            <th>Canal</th>
            {codigos.map((c) => (
              <th key={c}>
                <span className="dot" style={{ background: propColor(c) }} />
                {c}
              </th>
            ))}
            <th>Total</th>
            <th>% del total</th>
          </tr>
        </thead>
        <tbody>
          {canales.map((canal) => (
            <tr key={canal}>
              <td>{canalNombre(canal)}</td>
              {codigos.map((c) => {
                const v = get(canal, c);
                return <td key={c} className="num">{v ? eur(v) : "—"}</td>;
              })}
              <td className="num"><strong>{eur(totalCanal(canal))}</strong></td>
              <td className="num">{pct(granTotal ? totalCanal(canal) / granTotal : 0)}</td>
            </tr>
          ))}
          <tr className="total">
            <td>TOTAL</td>
            {codigos.map((c) => (
              <td key={c} className="num">
                {eur(rows.filter((r) => r.codigo === c).reduce((a, r) => a + Number(r.ingreso), 0))}
              </td>
            ))}
            <td className="num">{eur(granTotal)}</td>
            <td className="num">100 %</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
