// El embudo "ya vendido hoy vs cómo CERRÓ ese mes el año pasado" — mismo lenguaje
// visual que el bullet del break-even: barra de color = vendido, pista gris = el
// cierre del año previo. Server puro (HTML+CSS), sin Recharts.
//
// "no existía" ≠ 0: sin STLY válido no hay pista y se dice en texto (cicatriz 064).
// El delta de ADR se calla con menos de 5 noches (lo decide lib/yoy.filasPace).
import { MESES } from "@/lib/format";
import type { FilaPace } from "@/lib/yoy";

const MAX_NOCHES = 31;

export function PaceYoy({ filas, color }: { filas: FilaPace[]; color: string }) {
  return (
    <div className="pace-lista">
      {filas.map((f) => {
        const delta = f.adrDeltaPct;
        const chip = delta == null
          ? null
          : `${delta >= 0 ? "+" : "−"}${Math.abs(Math.round(delta * 100))} %`;
        const titulo = f.ly == null
          ? `${MESES[f.mes]} ${f.anio}: ${f.otb} noches vendidas · sin referencia (el piso no existía)`
          : `${MESES[f.mes]} ${f.anio}: ${f.otb} noches ya vendidas de las ${f.ly} que cerró el año pasado`;
        return (
          <div className="pace-fila" key={`${f.anio}-${f.mes}`} title={titulo}>
            <span className="pace-mes">{MESES[f.mes]}</span>
            {f.ly == null ? (
              <div className="pace-track sin">
                <div className="pace-otb" style={{ background: color, width: `${(f.otb / MAX_NOCHES) * 100}%` }} />
              </div>
            ) : (
              <div className="pace-track">
                <div className="pace-ly" style={{ width: `${(f.ly / MAX_NOCHES) * 100}%` }} />
                <div className="pace-otb" style={{ background: color, width: `${(f.otb / MAX_NOCHES) * 100}%` }} />
              </div>
            )}
            <span className="pace-num">
              <b>{f.otb}</b>
              {f.ly != null ? `/${f.ly}` : ""} ·{" "}
              {f.ly == null
                ? <span className="pace-noexiste">no existía</span>
                : chip == null
                  ? <span className="muted">—</span>
                  : <span className={"chip-delta " + ((delta ?? 0) >= 0 ? "pos" : "neg")}>{chip}</span>}
            </span>
          </div>
        );
      })}
    </div>
  );
}
