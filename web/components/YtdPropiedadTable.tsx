// Tabla "Por propiedad · YTD" — las tres capas del motor en una sola vista (migración 025):
//   Ingreso → Contribución → Margen operativo, y debajo el puente hasta el resultado de Samavi.
//
// Por qué las tres y no solo el margen: cada columna responde una pregunta distinta.
//   · Contribución  → ¿vale la pena tener este piso? (si se va, el overhead NO se va)
//   · Operativo     → ¿paga su parte de la estructura?
//   · Resultado     → ¿la empresa gana plata?
// Mostrar solo la última fue lo que hacía parecer que Alexander perdía dinero.
//
// Nota de nomenclatura: "Ingreso" es Ingreso Samavi, no facturación. En el modelo comisión
// (Jacobine) lo que entra es el 25 % del bruto neto de IVA, no el bruto.
import Link from "next/link";
import { propColor } from "@/lib/colors";
import { num } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import type { RentRow } from "@/lib/rentabilidad";

// Sin símbolo de € en las celdas (va en la cabecera): con cuatro columnas de cinco cifras,
// los " €" desbordaban la tabla a 390 px y escondían la columna que más importa.
const Signo = ({ v }: { v: number }) => (
  <span className={v >= 0 ? "pos" : "neg"}>
    {v >= 0 ? "+" : "−"}{num(Math.round(Math.abs(v)))}
  </span>
);

export function YtdPropiedadTable({ rows, anio, corporativos, resultado }: {
  rows: RentRow[]; anio: number; corporativos: number; resultado: number;
}) {
  if (rows.length === 0) return null;
  const totIngreso = rows.reduce((s, r) => s + Number(r.ingreso_samavi), 0);
  const totContrib = rows.reduce((s, r) => s + Number(r.contribucion), 0);
  const totOperativo = rows.reduce((s, r) => s + Number(r.margen_neto), 0);

  return (
    <div className="table-wrap">
      <table className="as-table ytd-table">
        <caption className="sr-only">
          Ingreso, contribución ("aporte") y margen operativo por propiedad, real devengado {anio},
          con el puente hasta el resultado de Samavi
        </caption>
        <thead>
          <tr>
            <th scope="col">Propiedad · €</th>
            <th scope="col">Ingreso</th>
            <th scope="col">Aporte</th>
            <th scope="col">Operativo</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.codigo}>
              <th scope="row">
                <Link href={`/p/${encodeURIComponent(r.codigo)}`} className="as-nombre">
                  <span className="dot" style={{ background: propColor(r.codigo) }} />
                  {nombreCorto(r.codigo)}
                </Link>
              </th>
              <td className="as-mo">{num(Math.round(Number(r.ingreso_samavi)))}</td>
              <td className="as-mo"><Signo v={Number(r.contribucion)} /></td>
              <td className="as-mo"><Signo v={Number(r.margen_neto)} /></td>
            </tr>
          ))}
          <tr className="as-total">
            <th scope="row">Total pisos</th>
            <td className="as-mo">{num(Math.round(totIngreso))}</td>
            <td className="as-mo"><Signo v={totContrib} /></td>
            <td className="as-mo"><Signo v={totOperativo} /></td>
          </tr>
          <tr className="ytd-puente">
            <th scope="row">
              Estructura <span className="tag">no asignable</span>
            </th>
            <td className="as-mo muted">—</td>
            <td className="as-mo muted">—</td>
            <td className="as-mo"><Signo v={-Math.abs(corporativos)} /></td>
          </tr>
          <tr className="as-total ytd-resultado">
            <th scope="row">Resultado Samavi</th>
            <td className="as-mo muted">—</td>
            <td className="as-mo muted">—</td>
            <td className="as-mo"><Signo v={resultado} /></td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
