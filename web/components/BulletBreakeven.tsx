// Bullet chart de break-even (02_Prompt §5.3): barra gris = ocupación necesaria,
// barra de color = ocupación real, colchón en pp como TEXTO (nunca color solo).
// Puro y client-safe: el simulador lo mueve en vivo.
import { pct, pp } from "@/lib/format";

export type BulletProps = {
  necesaria: number | null; // 0..1 (puede superar 1 → inalcanzable)
  real: number;             // 0..1
  colchon: number | null;   // pp (real − necesaria)
  color: string;
  etiqueta?: string;        // "real YTD" | "simulada"
};

export function BulletBreakeven({ necesaria, real, colchon, color, etiqueta = "real" }: BulletProps) {
  const clamp = (v: number) => Math.max(0, Math.min(1, v));
  const inalcanzable = necesaria != null && necesaria > 1;
  const estado = colchon == null ? { icon: "—", label: "sin dato", cls: "muted" }
    : colchon < 0 ? { icon: "▼", label: "en pérdida", cls: "neg" }
    : colchon < 0.1 ? { icon: "⚠", label: "ajustado", cls: "warn" }
    : { icon: "▲", label: "holgado", cls: "pos" };

  return (
    <div className="bullet">
      <div className="bullet-track">
        {necesaria != null && (
          <div className="bullet-necesaria" style={{ width: `${clamp(necesaria) * 100}%` }} />
        )}
        <div className="bullet-real" style={{ width: `${clamp(real) * 100}%`, background: color }} />
        {necesaria != null && !inalcanzable && (
          <div className="bullet-marca" style={{ left: `${clamp(necesaria) * 100}%` }} />
        )}
      </div>
      <div className="bullet-leyenda">
        <span>necesita {necesaria == null ? "—" : inalcanzable ? ">100 %" : pct(necesaria)}</span>
        <span>· ocupación {etiqueta} {pct(real)}</span>
        <span className={estado.cls}> · colchón {estado.icon} {colchon == null ? "—" : pp(colchon)} <span className="tag">{estado.label}</span></span>
      </div>
    </div>
  );
}
