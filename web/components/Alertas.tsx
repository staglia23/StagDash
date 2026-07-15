import Link from "next/link";
import { propColor } from "@/lib/colors";

export type AlertaRow = { tipo: string; codigo: string; severidad: string; mensaje: string };

const PESO: Record<string, number> = { critical: 0, warning: 1 };

export function Alertas({ rows }: { rows: AlertaRow[] }) {
  if (!rows.length) {
    return (
      <div className="alerta ok">
        ✅ <span className="alerta-msg">Nada que requiera acción ahora mismo.</span>
      </div>
    );
  }
  const orden = [...rows].sort((a, b) => (PESO[a.severidad] ?? 9) - (PESO[b.severidad] ?? 9));

  return (
    <ul className="alertas">
      {orden.map((a, i) => (
        <li key={i} className={"alerta " + a.severidad}>
          <span aria-hidden>{a.severidad === "critical" ? "⛔" : "⚠️"}</span>
          <span className="dot" style={{ background: propColor(a.codigo) }} />
          <Link href={`/propiedad/${a.codigo}`} className="alerta-prop">{a.codigo}</Link>
          <span className="alerta-msg">{a.mensaje}</span>
        </li>
      ))}
    </ul>
  );
}
