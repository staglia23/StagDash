// Tarjeta de salud por propiedad — el panel de visión periférica del operador.
// Regla de oro: estado con icono+texto+motivo (nunca color solo), números con su "¿y qué?".
import Link from "next/link";
import { propColor } from "@/lib/colors";
import { eur, pct } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import type { Salud } from "@/lib/salud";
import { Salud30, type DiaForward } from "./Salud30";

export type HealthData = {
  codigo: string;
  salud: Salud;
  dias: DiaForward[];
  ocup7: number;
  ocup30: number;
  revparFwd30: number;
  revparEq: number | null;
  margenMes: number | null;
  mesLabel: string;          // "jul"
  reservas7d: number;
  diasSinVender: number | null;
};

export function HealthCard({ h }: { h: HealthData }) {
  const color = propColor(h.codigo);
  const revparOk = h.revparEq != null && h.revparFwd30 >= h.revparEq;
  return (
    <Link href={`/p/${encodeURIComponent(h.codigo)}`} className={"hcard " + h.salud.cls}>
      <div className="hcard-head">
        <span className="dot" style={{ background: color }} />
        <strong className="hcard-nombre">{nombreCorto(h.codigo)}</strong>
        <span className={"estado " + h.salud.cls}>{h.salud.icon} {h.salud.label}</span>
      </div>

      <Salud30 dias={h.dias} color={color} />

      <dl className="hstats">
        <div>
          <dt>Vendido 7d · 30d</dt>
          <dd>{pct(h.ocup7, 0)} · {pct(h.ocup30, 0)}</dd>
        </div>
        <div>
          <dt>RevPAR 30d vs eq.</dt>
          <dd className={revparOk ? "pos" : "neg"}>
            {revparOk ? "▲" : "▼"} {eur(h.revparFwd30)}
            <span className="hstats-eq"> / {h.revparEq == null ? "—" : eur(h.revparEq)}</span>
          </dd>
        </div>
        <div>
          <dt>Margen {h.mesLabel} (vendido)</dt>
          <dd className={h.margenMes == null ? "muted" : h.margenMes >= 0 ? "pos" : "neg"}>
            {h.margenMes == null ? "—" : `${h.margenMes >= 0 ? "+" : "−"}${eur(Math.abs(h.margenMes))}`}
          </dd>
        </div>
      </dl>

      <div className={"hmotivo " + h.salud.cls}>
        {h.salud.icon} {h.salud.motivo}
        {h.reservas7d > 0 && h.salud.cls === "good"
          ? ` · ${h.reservas7d} reserva${h.reservas7d === 1 ? "" : "s"} en 7d`
          : ""}
      </div>
    </Link>
  );
}
