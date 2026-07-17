// Sparkline SVG inline (02_Prompt §5.3): hasta 12 puntos — los meses transcurridos del año.
// Los meses futuros se omiten, no se muestran vacíos. Recharts es overkill aquí.
// Decorativa (aria-hidden): el dato y su comparación van SIEMPRE en texto al lado.

const W = 120;
const H = 32;
const PAD = 3;

export function Sparkline({ values, color = "var(--series-1)" }: { values: number[]; color?: string }) {
  const vals = values.slice(0, 12).map(Number);
  if (vals.length < 2) return null;

  const min = Math.min(...vals, 0);
  const max = Math.max(...vals, 0);
  const range = max - min || 1;
  const x = (i: number) => PAD + (i * (W - 2 * PAD)) / (vals.length - 1);
  const y = (v: number) => H - PAD - ((v - min) * (H - 2 * PAD)) / range;
  const puntos = vals.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  const cruzaCero = min < 0 && max > 0;

  return (
    <svg className="spark" viewBox={`0 0 ${W} ${H}`} aria-hidden focusable="false">
      {cruzaCero && (
        <line x1={PAD} x2={W - PAD} y1={y(0)} y2={y(0)}
          stroke="var(--baseline)" strokeWidth={1} strokeDasharray="3 3" />
      )}
      <polyline points={puntos} fill="none" stroke={color} strokeWidth={1.8}
        strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={x(vals.length - 1)} cy={y(vals[vals.length - 1])} r={2.4} fill={color} />
    </svg>
  );
}
