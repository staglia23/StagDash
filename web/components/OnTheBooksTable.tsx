import { eur, MESES } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type OtbRow = { anio: number; mes: number; codigo: string; noches: number; ingreso: number };

/** Ingreso YA confirmado (no es proyección): noches futuras de reservas reales. */
export function OnTheBooksTable({ rows, codigos }: { rows: OtbRow[]; codigos: string[] }) {
  const meses = Array.from(new Set(rows.map((r) => `${r.anio}-${r.mes}`)))
    .map((k) => ({ anio: Number(k.split("-")[0]), mes: Number(k.split("-")[1]) }))
    .sort((a, b) => a.anio - b.anio || a.mes - b.mes);

  const get = (anio: number, mes: number, codigo: string) =>
    rows.find((r) => r.anio === anio && r.mes === mes && r.codigo === codigo)?.ingreso ?? 0;
  const totalMes = (anio: number, mes: number) =>
    rows.filter((r) => r.anio === anio && r.mes === mes).reduce((a, r) => a + Number(r.ingreso), 0);
  const nochesMes = (anio: number, mes: number) =>
    rows.filter((r) => r.anio === anio && r.mes === mes).reduce((a, r) => a + Number(r.noches), 0);
  const granTotal = rows.reduce((a, r) => a + Number(r.ingreso), 0);

  if (!meses.length) return <div className="notice">Sin reservas futuras cargadas.</div>;

  return (
    <div className="table-wrap">
      <table className="ranking">
        <thead>
          <tr>
            <th>Mes</th>
            {codigos.map((c) => (
              <th key={c}>
                <span className="dot" style={{ background: propColor(c) }} />
                {c}
              </th>
            ))}
            <th>Total</th>
            <th>Noches</th>
          </tr>
        </thead>
        <tbody>
          {meses.map(({ anio, mes }) => (
            <tr key={`${anio}-${mes}`}>
              <td>{MESES[mes]} {anio}</td>
              {codigos.map((c) => {
                const v = get(anio, mes, c);
                return <td key={c} className="num">{v ? eur(v) : "—"}</td>;
              })}
              <td className="num"><strong>{eur(totalMes(anio, mes))}</strong></td>
              <td className="num">{nochesMes(anio, mes)}</td>
            </tr>
          ))}
          <tr className="total">
            <td>TOTAL comprometido</td>
            {codigos.map((c) => (
              <td key={c} className="num">
                {eur(rows.filter((r) => r.codigo === c).reduce((a, r) => a + Number(r.ingreso), 0))}
              </td>
            ))}
            <td className="num">{eur(granTotal)}</td>
            <td className="num">{rows.reduce((a, r) => a + Number(r.noches), 0)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
