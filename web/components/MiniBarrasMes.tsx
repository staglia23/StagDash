// 12 mini-barras mensuales tappables de la ficha (02_Prompt §5.6): margen del mes,
// tap → ancla a la fila de ese mes en el detalle. Meses futuros = hueco, no cero.
import { eur, MESES } from "@/lib/format";

export type MesBarra = { mes: number; valor: number };

export function MiniBarrasMes({ datos, color }: { datos: MesBarra[]; color: string }) {
  const porMes = new Map(datos.map((d) => [d.mes, Number(d.valor)]));
  const vals = Array.from(porMes.values());
  const maxAbs = Math.max(...vals.map(Math.abs), 1);
  const H = 56; // px de media altura (positivo/negativo)

  return (
    <div className="minibars" role="list" aria-label="Margen por mes">
      {Array.from({ length: 12 }, (_, i) => i + 1).map((mes) => {
        const v = porMes.get(mes);
        const h = v == null ? 0 : Math.max(2, Math.round((Math.abs(v) / maxAbs) * H));
        return (
          <a key={mes} role="listitem" href={v == null ? undefined : `#mes-${mes}`}
            className={"minibar" + (v == null ? " vacio" : "")}
            aria-label={v == null ? `${MESES[mes]}: sin datos` : `${MESES[mes]}: ${eur(v)}`}>
            <span className="minibar-cols">
              <span className="minibar-pos">
                {v != null && v >= 0 && <span className="minibar-fill" style={{ height: h, background: color }} />}
              </span>
              <span className="minibar-neg">
                {v != null && v < 0 && <span className="minibar-fill" style={{ height: h, background: "var(--critical)" }} />}
              </span>
            </span>
            <span className="minibar-mes">{MESES[mes]}</span>
          </a>
        );
      })}
    </div>
  );
}
