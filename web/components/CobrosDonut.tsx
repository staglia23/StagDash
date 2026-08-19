"use client";
// Donut + lista de cobros, con detalle al abrir una porción.
//
// Por qué donut Y lista: con Airbnb al 96 % las otras porciones son rayitas de dos píxeles.
// El donut da la referencia de un vistazo (que es lo que se pidió) y la lista es la que se lee
// de verdad. La lista hace además de leyenda con etiqueta directa, así que la identidad nunca
// depende del color solo.
import { useState } from "react";
import { agrupar, SIN_CLASIFICAR, type CobroRow, type Eje, type Grupo } from "@/lib/cobros";
import { eur, pct } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";

// Color = entidad, orden fijo. El gris es "no hay dato", no una categoría más.
const COLOR: Record<string, string> = {
  "Airbnb": "var(--cobro-1)",
  "Booking.com": "var(--cobro-2)",
  "Directa": "var(--cobro-3)",
  "Pasarela Airbnb": "var(--cobro-1)",
  "Efectivo": "var(--cobro-2)",
  "Transferencia": "var(--cobro-3)",
  [SIN_CLASIFICAR]: "var(--cobro-0)",
};

const arco = (r0: number, r1: number, a0: number, a1: number) => {
  const p = (r: number, a: number) => [50 + r * Math.cos(a), 50 + r * Math.sin(a)];
  const large = a1 - a0 > Math.PI ? 1 : 0;
  const [x1, y1] = p(r0, a0), [x2, y2] = p(r0, a1);
  const [x3, y3] = p(r1, a1), [x4, y4] = p(r1, a0);
  return `M${x1} ${y1}A${r0} ${r0} 0 ${large} 1 ${x2} ${y2}L${x3} ${y3}A${r1} ${r1} 0 ${large} 0 ${x4} ${y4}Z`;
};

const fechaCorta = (iso: string | null) =>
  iso ? `${iso.slice(8, 10)}/${iso.slice(5, 7)}` : "—";

export default function CobrosDonut({ rows }: { rows: CobroRow[] }) {
  const [eje, setEje] = useState<Eje>("canal");
  const [abierto, setAbierto] = useState<string | null>(null);

  const grupos = agrupar(rows, eje);
  const total = grupos.reduce((a, g) => a + g.total, 0);

  const cambiarEje = (e: Eje) => { setEje(e); setAbierto(null); };
  const toggle = (k: string) => setAbierto(abierto === k ? null : k);

  // Separador de 2px entre segmentos (spec de marcas).
  const GAP = 0.022;
  let ang = -Math.PI / 2;
  const slices = grupos.map((g) => {
    const span = (total > 0 ? g.total / total : 0) * Math.PI * 2;
    const a0 = ang + GAP / 2, a1 = ang + span - GAP / 2;
    ang += span;
    return { g, d: a1 > a0 ? arco(46, 31, a0, a1) : null };
  });

  return (
    <div className="cobros">
      <div className="seg" role="group" aria-label="Cómo agrupar">
        <button type="button" onClick={() => cambiarEje("canal")}
          aria-pressed={eje === "canal"}>Por canal</button>
        <button type="button" onClick={() => cambiarEje("familia")}
          aria-pressed={eje === "familia"}>Por forma de cobro</button>
      </div>

      <p className="cobros-hint">
        {eje === "canal"
          ? "De dónde vino la reserva."
          : "Cómo entró la plata. No es lo mismo: una reserva de Booking se puede cobrar en efectivo."}
      </p>

      <div className="cobros-row">
        <div className="donutwrap">
          <svg viewBox="0 0 100 100" role="img"
            aria-label={grupos.map((g) => `${g.clave}: ${pct(g.pct)}`).join(", ")}>
            {slices.map(({ g, d }) => d && (
              <path key={g.clave} d={d} fill={COLOR[g.clave] ?? "var(--cobro-0)"}
                className={"slice" + (abierto && abierto !== g.clave ? " dim" : "")}
                tabIndex={0} role="button" aria-label={`${g.clave}, ${pct(g.pct)}, ${eur(g.total)}`}
                onClick={() => toggle(g.clave)}
                onKeyDown={(ev) => {
                  if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); toggle(g.clave); }
                }} />
            ))}
          </svg>
          <div className="donut-center">
            <div className="donut-big">{eur(total)}</div>
            <div className="donut-lbl">cobrado</div>
          </div>
        </div>

        <ul className="cobros-legend">
          {grupos.map((g) => (
            <li key={g.clave}>
              <button className="cobro-row" onClick={() => toggle(g.clave)}
                aria-expanded={abierto === g.clave}>
                <span className="cobro-sw" style={{ background: COLOR[g.clave] ?? "var(--cobro-0)" }} />
                <span className="cobro-name">
                  <span className="cobro-chev" aria-hidden="true">▶</span>{g.clave}
                </span>
                <span className="cobro-pct">{pct(g.pct)}</span>
                <span className="cobro-amt">{eur(g.total)}</span>
              </button>
              <div className="cobro-bar">
                <i style={{ width: `${(g.pct * 100).toFixed(2)}%`,
                            background: COLOR[g.clave] ?? "var(--cobro-0)" }} />
              </div>
              {abierto === g.clave && <Detalle g={g} />}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function Detalle({ g }: { g: Grupo }) {
  const filas = [...g.filas].sort((a, b) => b.importe - a.importe);
  const hayNota = filas.some((f) => f.nota);
  return (
    <div className="cobro-detalle">
      <div className="table-wrap">
        <table className="ranking cobros-tabla">
          <thead>
            <tr>
              <th>Piso</th><th>Entrada</th><th>Cobrado</th><th>Cobro</th>
              <th>Reserva</th>{hayNota && <th>Nota</th>}
            </tr>
          </thead>
          <tbody>
            {filas.map((f, i) => (
              <tr key={(f.confirmation_code ?? "") + i}>
                <td>{nombreCorto(f.codigo)}</td>
                <td>{fechaCorta(f.checkin_local)}</td>
                <td>{eur(f.importe, 2)}</td>
                <td>
                  {f.metodo}
                  {f.entra_en_banco_es === false && (
                    <span className="chip-fuera" title="No aparece en el extracto español">
                      fuera del banco
                    </span>
                  )}
                  {f.entra_en_banco_es === null && (
                    <span className="chip-falta" title="Falta la nota: no se puede saber">
                      falta nota
                    </span>
                  )}
                </td>
                <td className="mono">{f.confirmation_code ?? "—"}</td>
                {hayNota && <td className="cobro-nota">{f.nota ?? "—"}</td>}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="cobro-pie">{filas.length} cobro{filas.length === 1 ? "" : "s"} · {eur(g.total)}</p>
    </div>
  );
}
