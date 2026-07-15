import Link from "next/link";
import { eur, pct, pp } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type PropCard = {
  codigo: string;
  ingreso_samavi: number;
  margen_neto: number;
  margen_neto_pct: number;
  ocup_pct: number;
  eur_noche_neto: number;
  colchon: number | null;
};

/** Semáforo: nunca por color solo — siempre lleva icono + etiqueta. */
function estado(c: PropCard): { cls: string; label: string; icon: string } {
  if (Number(c.margen_neto) < 0) return { cls: "critical", label: "en pérdida", icon: "⛔" };
  if (c.colchon != null && c.colchon < 0.1) return { cls: "warning", label: "ajustado", icon: "⚠️" };
  return { cls: "good", label: "saludable", icon: "✅" };
}

export function PropiedadCards({ rows }: { rows: PropCard[] }) {
  return (
    <div className="prop-grid">
      {rows.map((c) => {
        const e = estado(c);
        return (
          <Link key={c.codigo} href={`/propiedad/${c.codigo}`} className={"prop-card " + e.cls}>
            <div className="prop-head">
              <span className="dot" style={{ background: propColor(c.codigo) }} />
              <strong>{c.codigo}</strong>
              <span className={"estado " + e.cls}>{e.icon} {e.label}</span>
            </div>
            <div className="prop-value">{eur(c.margen_neto)}</div>
            <div className="prop-label">Margen Neto YTD · {pct(c.margen_neto_pct)}</div>
            <dl className="prop-meta">
              <div><dt>Ocupación</dt><dd>{pct(c.ocup_pct, 0)}</dd></div>
              <div><dt>€/noche neto</dt><dd>{eur(c.eur_noche_neto)}</dd></div>
              <div><dt>Colchón</dt><dd>{c.colchon == null ? "—" : pp(c.colchon)}</dd></div>
            </dl>
          </Link>
        );
      })}
    </div>
  );
}
