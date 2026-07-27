// 12 mini-barras mensuales tappables de la ficha (02_Prompt §5.6): margen del mes,
// tap → ancla a la fila de ese mes en el detalle. Meses futuros = hueco, no cero.
// Cada barra lleva su importe (pedido de Stag, jul 2026). Anticolisión: si dos meses
// adyacentes del mismo signo quedan casi a la misma altura y sus etiquetas anchas se
// pisarían (caso MARE ene–abr, cuatro negativos parecidos), la segunda se separa
// LABEL_H px. El importe completo sigue en aria-label y en la tabla de detalle.
import { eur, eurCorto, MESES } from "@/lib/format";

export type MesBarra = { mes: number; valor: number };

const H = 52; // px de barra máxima por mitad (positivo/negativo)
const MEDIA = 72; // px de cada mitad (.minibar-cols/2) — deja sitio a la etiqueta
const LABEL_H = 11; // alto aprox. de la etiqueta a 0.62rem

// Ancho aproximado del glifo a 0.62rem bold tabular (es-ES): coma y espacio finos,
// € y − anchos. Solo decide si dos etiquetas vecinas caben a la misma altura (pitch
// ~27 px por columna a 390 px de viewport).
const anchoGlifo = (ch: string) =>
  ch === "," || ch === " " ? 3 : ch === "€" ? 9 : ch === "−" ? 8 : 6.5;
const anchoEtiqueta = (s: string) =>
  Array.from(s).reduce((a, c) => a + anchoGlifo(c), 1);

export function MiniBarrasMes({ datos, color }: { datos: MesBarra[]; color: string }) {
  const porMes = new Map(datos.map((d) => [d.mes, Number(d.valor)]));
  const maxAbs = Math.max(...Array.from(porMes.values()).map(Math.abs), 1);

  let prev: { mes: number; neg: boolean; pos: number; ancho: number } | null = null;
  const meses = Array.from({ length: 12 }, (_, i) => i + 1).map((mes) => {
    const v = porMes.get(mes);
    if (v == null) return { mes, v: null as number | null, h: 0, pos: 0 };
    const h = Math.max(2, Math.round((Math.abs(v) / maxAbs) * H));
    const ancho = anchoEtiqueta(eurCorto(v));
    let pos = h + 3;
    if (
      prev && prev.mes === mes - 1 && prev.neg === v < 0 &&
      Math.abs(pos - prev.pos) < LABEL_H && (ancho + prev.ancho) / 2 > 24
    ) {
      pos = h + 3 + LABEL_H;
      if (Math.abs(pos - prev.pos) < LABEL_H) {
        pos = prev.pos + LABEL_H;
        if (v < 0) pos = Math.min(pos, MEDIA - LABEL_H); // no invadir la fila de meses
      }
    }
    prev = { mes, neg: v < 0, pos, ancho };
    return { mes, v: v as number | null, h, pos };
  });

  return (
    <div className="minibars" role="list" aria-label="Margen por mes">
      {meses.map(({ mes, v, h, pos }) => (
        <a key={mes} role="listitem" href={v == null ? undefined : `#mes-${mes}`}
          className={"minibar" + (v == null ? " vacio" : "")}
          aria-label={v == null ? `${MESES[mes]}: sin datos` : `${MESES[mes]}: ${eur(v)}`}>
          <span className="minibar-cols">
            <span className="minibar-pos">
              {v != null && v >= 0 && (
                <>
                  <span className="minibar-fill" style={{ height: h, background: color }} />
                  <span className="minibar-label" aria-hidden style={{ bottom: pos }}>{eurCorto(v)}</span>
                </>
              )}
            </span>
            <span className="minibar-neg">
              {v != null && v < 0 && (
                <>
                  <span className="minibar-fill" style={{ height: h, background: "var(--critical)" }} />
                  <span className="minibar-label" aria-hidden style={{ top: pos }}>{eurCorto(v)}</span>
                </>
              )}
            </span>
          </span>
          <span className="minibar-mes">{MESES[mes]}</span>
        </a>
      ))}
    </div>
  );
}
