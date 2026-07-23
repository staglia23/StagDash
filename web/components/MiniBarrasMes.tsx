// 12 mini-barras mensuales tappables de la ficha (02_Prompt §5.6): margen del mes,
// tap → ancla a la fila de ese mes en el detalle. Meses futuros = hueco, no cero.
// Etiquetas selectivas (doctrina dataviz: endpoint + extremo, nunca todas): el último
// mes con dato siempre; además el peor mes si es negativo. El resto queda en aria-label
// y en la tabla de detalle.
import { eur, eurCorto, MESES } from "@/lib/format";

export type MesBarra = { mes: number; valor: number };

export function MiniBarrasMes({ datos, color }: { datos: MesBarra[]; color: string }) {
  const porMes = new Map(datos.map((d) => [d.mes, Number(d.valor)]));
  const vals = Array.from(porMes.values());
  const maxAbs = Math.max(...vals.map(Math.abs), 1);
  const H = 56; // px de media altura (positivo/negativo)

  const conDato = Array.from(porMes.keys());
  const ultimo = conDato.length ? Math.max(...conDato) : null;
  const peor = datos.reduce<MesBarra | null>(
    (min, d) => (Number(d.valor) < 0 && (min == null || Number(d.valor) < min.valor) ? d : min),
    null,
  );

  return (
    <div className="minibars" role="list" aria-label="Margen por mes">
      {Array.from({ length: 12 }, (_, i) => i + 1).map((mes) => {
        const v = porMes.get(mes);
        const h = v == null ? 0 : Math.max(2, Math.round((Math.abs(v) / maxAbs) * H));
        const etiquetado = v != null && (mes === ultimo || (peor != null && mes === peor.mes));
        return (
          <a key={mes} role="listitem" href={v == null ? undefined : `#mes-${mes}`}
            className={"minibar" + (v == null ? " vacio" : "")}
            aria-label={v == null ? `${MESES[mes]}: sin datos` : `${MESES[mes]}: ${eur(v)}`}>
            <span className="minibar-cols">
              <span className="minibar-pos">
                {v != null && v >= 0 && <span className="minibar-fill" style={{ height: h, background: color }} />}
                {etiquetado && v != null && v >= 0 && (
                  <span className="minibar-label" aria-hidden style={{ bottom: h + 3 }}>{eurCorto(v)}</span>
                )}
              </span>
              <span className="minibar-neg">
                {v != null && v < 0 && <span className="minibar-fill" style={{ height: h, background: "var(--critical)" }} />}
                {etiquetado && v != null && v < 0 && (
                  <span className="minibar-label" aria-hidden style={{ top: h + 3 }}>{eurCorto(v)}</span>
                )}
              </span>
            </span>
            <span className="minibar-mes">{MESES[mes]}</span>
          </a>
        );
      })}
    </div>
  );
}
