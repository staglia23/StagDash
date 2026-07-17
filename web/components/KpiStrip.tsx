// Tira de KPIs de la portada (02_Prompt §5.1): margen neto, ingreso, ocupación, ADR,
// cada uno con sparkline mensual y su "¿y qué?" en texto (ningún número sin contexto).
import { Sparkline } from "./Sparkline";

export type KpiItem = {
  label: string;
  value: string;
  spark: number[];
  sub: string; // la comparación o consecuencia — obligatoria
};

export function KpiStrip({ items }: { items: KpiItem[] }) {
  return (
    <div className="kpi-strip">
      {items.map((k) => (
        <div key={k.label} className="kpi-mini card">
          <div className="kpi-mini-top">
            <div>
              <div className="kpi-label">{k.label}</div>
              <div className="kpi-mini-value">{k.value}</div>
            </div>
            <Sparkline values={k.spark} />
          </div>
          <div className="kpi-sub">{k.sub}</div>
        </div>
      ))}
    </div>
  );
}
