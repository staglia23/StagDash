// Tabla "Margen neto asegurado" — propiedad × mes, del mes en curso a diciembre.
// Lee la tabla ya armada por lib/asegurado.ts (toda la lógica de estado vive ahí).
//
// Accesibilidad: el estado NUNCA va solo por color. El signo (+/−) distingue positivo de
// negativo, y los meses todavía a medio vender llevan "↗" además del gris, con su leyenda
// debajo y un title por celda.
import Link from "next/link";
import { propColor } from "@/lib/colors";
import type { Celda, TablaAsegurado } from "@/lib/asegurado";
import { MESES, num } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";

const CLASE: Record<Celda["estado"], string> = {
  pos: "pos", neg: "neg", llenando: "llenando",
};

/**
 * Compacto sin símbolo (el € va en la cabecera): "677" · "3,0k" · "1,2k".
 * Existe para que los 6 meses entren en 390 px sin scroll horizontal — un mes escondido
 * fuera de cuadro es un mes que nadie mira.
 */
const compacto = (n: number) => {
  const abs = Math.abs(n);
  if (abs < 1000) return num(Math.round(abs));
  return `${(abs / 1000).toLocaleString("es-ES", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}k`;
};

function Valor({ c, mesActual }: { c: Celda; mesActual: number }) {
  const signo = c.margen >= 0 ? "+" : "−";
  const titulo = c.estado === "llenando"
    ? `${MESES[c.mes]}: ${num(Math.round(c.margen))} € con el ${Math.round(c.ocupVendida * 100)} % del mes vendido — todavía por debajo de su ocupación de equilibrio, sube con cada reserva`
    : c.estado === "neg"
      ? `${MESES[c.mes]}: ${num(Math.round(c.margen))} € pese a haber superado ya la ocupación de equilibrio`
      : `${MESES[c.mes]}: ${num(Math.round(c.margen))} €`;
  return (
    <td className={"as-mo " + CLASE[c.estado] + (c.mes === mesActual ? " hoy" : "")} title={titulo}>
      {signo}{compacto(c.margen)}
      {c.estado === "llenando" ? <span className="as-llenando" aria-hidden="true">↗</span> : null}
    </td>
  );
}

export function AseguradoTable({ tabla, mesActual }: { tabla: TablaAsegurado; mesActual: number }) {
  if (tabla.filas.length === 0) return null;
  return (
    <div className="table-wrap">
      <table className="as-table">
        <caption className="sr-only">
          Margen neto ya asegurado por propiedad y mes, en euros, con las reservas confirmadas a día de hoy
        </caption>
        <thead>
          <tr>
            <th scope="col">Propiedad · €</th>
            {tabla.meses.map((m) => (
              <th key={`${m.anio}-${m.mes}`} scope="col" className={m.mes === mesActual ? "hoy" : ""}>
                {MESES[m.mes]}{m.mes === mesActual ? <span className="as-hoy-tag"> hoy</span> : null}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {tabla.filas.map((f) => (
            <tr key={f.codigo}>
              <th scope="row">
                <Link href={`/p/${encodeURIComponent(f.codigo)}`} className="as-nombre">
                  <span className="dot" style={{ background: propColor(f.codigo) }} />
                  {nombreCorto(f.codigo)}
                </Link>
              </th>
              {f.celdas.map((c) => <Valor key={`${c.anio}-${c.mes}`} c={c} mesActual={mesActual} />)}
            </tr>
          ))}
          <tr className="as-total">
            <th scope="row">Total</th>
            {tabla.totales.map((c) => <Valor key={`${c.anio}-${c.mes}`} c={c} mesActual={mesActual} />)}
          </tr>
        </tbody>
      </table>
    </div>
  );
}

/** Leyenda + la frase que explica por qué los meses lejanos están en gris y no en rojo. */
export function AseguradoLeyenda({ tabla, resumen, sinEquilibrio = false }: {
  tabla: TablaAsegurado; resumen: string; sinEquilibrio?: boolean;
}) {
  // Sin ocupación de equilibrio no se puede separar "mes a medio vender" de "mes malo":
  // decirlo es mejor que dejar que se lea como alarma (pasa si falla la lectura de la vista).
  if (sinEquilibrio) {
    return (
      <p className="section-note as-leyenda">
        ⚠️ Sin datos de equilibrio en esta carga: los meses todavía a medio vender no se
        distinguen de los que van mal de verdad. Recargá en unos segundos.
      </p>
    );
  }
  return (
    <p className="section-note as-leyenda">
      Es lo <strong>ya reservado</strong>: un piso que sube con cada reserva. {resumen}
      {tabla.total < 0 ? (
        <> Los {tabla.meses.length} juntos dan hoy {num(Math.round(tabla.total))} €, porque los
        últimos meses del año están casi sin vender.</>
      ) : null}
      <br />
      <span className="pos">verde</span> = el mes cubre sus costes ·{" "}
      <span className="llenando">gris ↗</span> = todavía no vendió ni su ocupación de equilibrio,
      así que sube solo · <span className="neg">rojo</span> = ya la superó y aun así pierde.
    </p>
  );
}
