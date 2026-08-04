// Fila de salud de la portada híbrida: una línea por propiedad, con la tira de 30 días.
// Sustituye a la tarjeta (HealthCard) en la portada — más densa, cuatro propiedades sin
// scroll a 390 px. La ficha completa sigue estando a un tap.
//
// Regla del prompt CEO: el estado va con icono + texto (nunca color solo) y todo número
// lleva su consecuencia — de ahí "13 libres" (lo accionable) y el motivo en una línea.
import Link from "next/link";
import { propColor } from "@/lib/colors";
import { eur } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import type { HealthData } from "./HealthCard";
import { Salud30 } from "./Salud30";

export function SaludFila({ h }: { h: HealthData }) {
  const color = propColor(h.codigo);
  const libres = h.dias.filter((d) => !d.vendida).length;
  const revparOk = h.revparEq != null && h.revparFwd30 >= h.revparEq;

  return (
    <Link href={`/p/${encodeURIComponent(h.codigo)}`} className="sfila">
      <div className="sfila-top">
        <span className="sfila-nombre">
          <span className="dot" style={{ background: color }} />
          {nombreCorto(h.codigo)}
        </span>
        <span className={"estado " + h.salud.cls}>{h.salud.icon} {h.salud.label}</span>
        <span className="sfila-cifra">
          <strong>{libres}</strong> libres
          <span className="sfila-revpar">
            {" · RevPAR "}
            <span className={revparOk ? "pos" : "neg"}>{eur(h.revparFwd30)}</span>
            {h.revparEq != null ? <span className="muted"> / eq. {eur(h.revparEq)}</span> : null}
          </span>
        </span>
      </div>

      <Salud30 dias={h.dias} color={color} hoyIso={h.hoyIso} />

      <div className={"sfila-motivo " + h.salud.cls}>{h.salud.motivo}</div>
    </Link>
  );
}
