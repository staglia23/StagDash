"use client";

// Simulador de escenarios (02_Prompt §5.4) — client component con baseline por props.
// Cálculo 100 % en cliente: cero queries, cero escrituras tras la carga inicial.
// La respuesta es UNA frase + bullet en vivo; todo output va etiquetado "simulado".
import Link from "next/link";
import { useMemo, useState } from "react";
import { propColor } from "@/lib/colors";
import { eur, num, pct, pp } from "@/lib/format";
import { nombreCorto } from "@/lib/headline";
import {
  fraseSimulada, palancasBase, simular, type Palancas, type PropBaseline,
} from "@/lib/simulador";
import { BulletBreakeven } from "./BulletBreakeven";

// §8.4 actualizado (Stag, 16/07/2026): la renta de ALEX sube a 1.614,80 €/mes desde nov-2026
// y queda ahí HASTA NUEVO AVISO (no vuelve a 1.414,22). La proyección usa el run-rate YTD
// (renta media ~1.359), así que NO incorpora esa subida: se advierte, no se corrige.
const GOTCHA_2027: Record<string, string> = {
  "4B_ALEX":
    "La renta sube a 1.614,80 €/mes desde nov-2026 y queda así hasta nuevo aviso. Esta " +
    "proyección extrapola el ritmo YTD (renta media 1.359 €/mes) y no incorpora la subida: " +
    "si tu decisión cruza a 2027, simulá con renta 1.614,80 para ver el escenario real.",
};

function SliderRow(props: {
  id: string; label: string; min: number; max: number; step: number;
  value: number; hoy: number; unidad: string; dec?: number;
  onChange: (v: number) => void;
}) {
  const { id, label, min, max, step, value, hoy, unidad, dec = 0, onChange } = props;
  // clamp al rango, ignora NaN (input vacío) y "snapea" al baseline exacto cuando el paso
  // del slider cae encima del valor real (evita deltas fantasma tipo 92 % vs 91,509 %)
  const emitir = (raw: number) => {
    if (Number.isNaN(raw)) return;
    let v = Math.min(max, Math.max(min, raw));
    if (Math.abs(v - hoy) <= step / 2 + 1e-9) v = hoy;
    onChange(v);
  };
  return (
    <div className="sim-row">
      <div className="sim-row-top">
        <label htmlFor={id}>{label}</label>
        <span className="sim-hoy">hoy: {num(hoy, dec)} {unidad}</span>
        <input
          type="number" className="sim-num" inputMode="decimal"
          min={min} max={max} step={step}
          value={Math.round(value * 100) / 100}
          onChange={(e) => emitir(Number(e.target.value))}
          aria-label={`${label} (valor numérico)`}
        />
        <span className="sim-unidad">{unidad}</span>
      </div>
      <input
        id={id} type="range" className="sim-range"
        min={min} max={max} step={step} value={value}
        onChange={(e) => emitir(Number(e.target.value))}
      />
    </div>
  );
}

/** Fila "real YTD": sale de v_ranking_ytd + v_breakeven_ytd, nunca se recalcula en cliente. */
export type RealYtd = { margen_neto: number; margen_neto_pct: number; ocup_pct: number; colchon: number | null };

export function Simulador({ baselines, inicial, real }: {
  baselines: PropBaseline[]; inicial: string; real: Record<string, RealYtd>;
}) {
  const target = baselines.find((b) => b.codigo === inicial) ?? baselines[0];
  const base = useMemo(() => palancasBase(target), [target]);
  const [p, setP] = useState<Palancas>(base);
  const [conOverhead, setConOverhead] = useState(true);

  const resultado = useMemo(
    () => simular(baselines, target.codigo, p, { conOverhead }),
    [baselines, target.codigo, p, conOverhead],
  );
  const baseline = useMemo(
    () => simular(baselines, target.codigo, base, { conOverhead }),
    [baselines, target.codigo, base, conOverhead],
  );

  const margen = (r: typeof resultado) =>
    conOverhead ? r.target.margenNetoAnual : r.target.margenDirectoAnual;
  const delta = margen(resultado) - margen(baseline);
  const casi = (a: number, b: number) => Math.abs(a - b) < 1e-9;
  const enBaseline = casi(p.rentaMes, base.rentaMes) && casi(p.adr, base.adr)
    && casi(p.ocup, base.ocup) && casi(p.comisionCanalPct, base.comisionCanalPct);
  const r = real[target.codigo];

  const set = (patch: Partial<Palancas>) => setP((prev) => ({ ...prev, ...patch }));

  return (
    <div className="sim">
      {/* selector de propiedad — el estado vive en la URL (?p=), no en un modal */}
      <nav className="chips" aria-label="Propiedad a simular">
        {baselines.map((b) => (
          <Link key={b.codigo}
            aria-current={b.codigo === target.codigo ? "page" : undefined}
            href={`/simulador?p=${encodeURIComponent(b.codigo)}`}
            className={"chip" + (b.codigo === target.codigo ? " active" : "")}>
            <span className="dot" style={{ background: propColor(b.codigo) }} />
            {nombreCorto(b.codigo)}
          </Link>
        ))}
      </nav>

      {/* respuesta primero */}
      <div className="card sim-respuesta">
        <div className="badges">
          <span className="badge badge-sim">simulado</span>
          <div className="toggle" role="group" aria-label="Margen a reportar">
            <button type="button" className={"toggle-btn" + (conOverhead ? " active" : "")}
              aria-pressed={conOverhead} onClick={() => setConOverhead(true)}>
              Margen neto
            </button>
            <button type="button" className={"toggle-btn" + (!conOverhead ? " active" : "")}
              aria-pressed={!conOverhead} onClick={() => setConOverhead(false)}>
              Margen directo
            </button>
          </div>
        </div>
        <p className="sim-frase">{fraseSimulada(target, p, resultado, conOverhead)}</p>
        <div className="sim-delta">
          {enBaseline ? "Este es el escenario actual (baseline real)." : (
            <>vs hoy: <strong className={delta >= 0 ? "pos" : "neg"}>
              {delta >= 0 ? "+" : "−"}{eur(Math.abs(delta))}/año
            </strong></>
          )}
        </div>
        <BulletBreakeven
          necesaria={resultado.target.ocupNecesaria}
          real={p.ocup}
          colchon={resultado.target.colchon}
          color={propColor(target.codigo)}
          etiqueta="simulada"
        />
        <button type="button" className="sim-reset" onClick={() => setP(base)} disabled={enBaseline}>
          ↺ Volver a hoy
        </button>
      </div>

      {/* palancas según modelo de ingreso */}
      <div className="card sim-palancas">
        <div className="section-title" style={{ margin: "0 0 10px" }}>
          Palancas — {target.modelo === "subarriendo" ? "subarriendo (paga renta)"
            : target.modelo === "titular" ? "titular (no paga renta)"
            : "comisión (ingreso = 30,25 % del bruto; la renta no aplica)"}
        </div>
        {target.modelo === "subarriendo" && (
          <SliderRow id="renta" label="Renta mensual" unidad="€/mes"
            min={0} max={Math.max(2500, Math.ceil((base.rentaMes * 2) / 100) * 100)} step={10}
            value={p.rentaMes} hoy={base.rentaMes}
            onChange={(v) => set({ rentaMes: v })} />
        )}
        <SliderRow id="adr" label="ADR (precio por noche)" unidad="€"
          min={40} max={Math.max(300, Math.ceil((base.adr * 1.8) / 10) * 10)} step={1}
          value={p.adr} hoy={base.adr}
          onChange={(v) => set({ adr: v })} />
        <SliderRow id="ocup" label="Ocupación" unidad="%" dec={1}
          min={0} max={100} step={1}
          value={Math.round(p.ocup * 100)} hoy={base.ocup * 100}
          onChange={(v) => set({ ocup: v / 100 })} />
        {target.modelo !== "comision" && (
          <SliderRow id="comision" label="Comisión de canal" unidad="%" dec={1}
            min={0} max={30} step={0.5}
            value={Math.round(p.comisionCanalPct * 1000) / 10} hoy={base.comisionCanalPct * 100}
            onChange={(v) => set({ comisionCanalPct: v / 100 })} />
        )}
      </div>

      {/* efecto colateral del prorrateo — se muestra, no se oculta */}
      <div className="card sim-colateral">
        <div className="section-title" style={{ margin: "0 0 8px" }}>
          Efecto en las otras 3 <span className="badge badge-sim">simulado</span>
        </div>
        <p className="section-note" style={{ margin: "0 0 10px" }}>
          El overhead ({eur(resultado.overheadAnual)}/año) no desaparece: se re-prorratea por peso
          en el Ingreso Samavi simulado.
        </p>
        <ul className="colateral-lista">
          {resultado.props.filter((x) => x.codigo !== target.codigo).map((x) => {
            const antes = baseline.props.find((b) => b.codigo === x.codigo)!;
            const d = x.margenNetoAnual - antes.margenNetoAnual;
            return (
              <li key={x.codigo}>
                <span className="dot" style={{ background: propColor(x.codigo) }} />
                <span className="colateral-prop">{nombreCorto(x.codigo)}</span>
                <span className="colateral-valor">{eur(x.margenNetoAnual)}/año</span>
                <span className={"colateral-delta " + (d >= 0.005 ? "pos" : d <= -0.005 ? "neg" : "muted")}>
                  {Math.abs(d) < 0.005 ? "sin cambio" : `${d > 0 ? "+" : "−"}${eur(Math.abs(d))}`}
                </span>
              </li>
            );
          })}
        </ul>
      </div>

      {/* referencia real — nunca se mezcla sin etiqueta */}
      {r && (
        <div className="card sim-real">
          <span className="badge badge-real">real YTD</span>{" "}
          {nombreCorto(target.codigo)}: margen neto {eur(r.margen_neto)} ({pct(r.margen_neto_pct)}) ·
          ingreso {eur(target.ingresoYtd)} · ocupación {pct(r.ocup_pct)} ·
          colchón {r.colchon == null ? "—" : pp(r.colchon)}
        </div>
      )}

      <div className="sim-notas">
        <p>
          Convención: proyección del año calendario 2026 extrapolando el ritmo actual
          (run-rate YTD). Todo importe de esta pantalla es <strong>simulado</strong>, no real.
        </p>
        {target.modelo === "subarriendo" && target.rentaBaseMes > 0 && (
          <p>Renta contractual vigente: {eur(target.rentaBaseMes, 2)}/mes (la media YTD cargada
            es {eur(base.rentaMes)}/mes por eventos puntuales).</p>
        )}
        {GOTCHA_2027[target.codigo] && <p className="warn">⚠ {GOTCHA_2027[target.codigo]}</p>}
      </div>
    </div>
  );
}
