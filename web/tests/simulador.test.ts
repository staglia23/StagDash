import { describe, expect, it } from "vitest";
import {
  DIAS_ANIO, comisionRealPct, fraseDirecto, fraseSimulada, palancasBase, simular, type PropBaseline,
} from "../lib/simulador";

// Fixture: datos reales de producción (27/07/2026) de v_ranking_ytd + v_costes_ytd +
// v_propiedades (ingresoYtd sin cancelaciones retenidas, como arma el baseline la page).
// Regla vigente desde el 27/07/2026 (decisión Stag): el overhead se reparte por DÍAS bajo
// gestión, igual que el motor — la cuota YTD es idéntica para los 4 (7.696,30) y las
// palancas NO la mueven. Antes iba por peso en el ingreso y el baseline neto no cuadraba
// con la ficha (JACO aparecía +6.9k €/año mejor; NICA −5.2k peor).
const NICA: PropBaseline = {
  codigo: "1A_NICA", modelo: "titular", meses: 7,
  ingresoYtd: 32916.59, brutoYtd: 40016.96, nochesYtd: 196, disponiblesYtd: 212,
  rentaYtd: 0, limpiezaYtd: 3073.22, suministrosYtd: 856.62, comunidadYtd: 2317.84, otrosYtd: 5145.32,
  overheadYtd: 7696.30, rentaBaseMes: 0, comisionModeloPct: 0, comisionCanalYtd: 7275.38,
};
const JACO: PropBaseline = {
  codigo: "1A_JACO", modelo: "comision", meses: 7,
  ingresoYtd: 11204.97, brutoYtd: 44941.32, nochesYtd: 174, disponiblesYtd: 212,
  rentaYtd: 0, limpiezaYtd: 0, suministrosYtd: 0, comunidadYtd: 0, otrosYtd: 891.52,
  overheadYtd: 7696.30, rentaBaseMes: 0, comisionModeloPct: 0.25, comisionCanalYtd: 0,
};
const MARE: PropBaseline = {
  codigo: "3G_MARE", modelo: "subarriendo", meses: 7,
  ingresoYtd: 23276.10, brutoYtd: 28594.01, nochesYtd: 196, disponiblesYtd: 212,
  rentaYtd: 6138.48, limpiezaYtd: 2538.02, suministrosYtd: 891.30, comunidadYtd: 0, otrosYtd: 4101.41,
  overheadYtd: 7696.30, rentaBaseMes: 1100, comisionModeloPct: 0, comisionCanalYtd: 5317.91,
};
const ALEX: PropBaseline = {
  codigo: "4B_ALEX", modelo: "subarriendo", meses: 7,
  ingresoYtd: 27178.17, brutoYtd: 33776.48, nochesYtd: 194, disponiblesYtd: 212,
  rentaYtd: 11280.06, limpiezaYtd: 2747.03, suministrosYtd: 897.65, comunidadYtd: 0, otrosYtd: 2265.02,
  overheadYtd: 7696.30, rentaBaseMes: 1414.22, comisionModeloPct: 0, comisionCanalYtd: 6312.29,
};
const TODAS = [NICA, JACO, MARE, ALEX];

describe("palancasBase — el baseline sale del YTD real", () => {
  it("ALEX: ADR, ocupación y comisión aparente coinciden con v_ranking_ytd", () => {
    const p = palancasBase(ALEX);
    expect(p.adr).toBeCloseTo(33776.48 / 194, 1);
    expect(p.ocup).toBeCloseTo(0.9151, 3);
    expect(p.comisionCanalPct).toBeCloseTo(1 - 27178.17 / 33776.48, 4);
    // la renta baseline es COSTE P&L (media YTD con factor IVA/retención): 1.611,44/mes
    expect(p.rentaMes).toBeCloseTo(11280.06 / 7, 2);
  });

  it("JACO (modelo comisión): sin comisión de canal como palanca", () => {
    expect(palancasBase(JACO).comisionCanalPct).toBe(0);
  });
});

describe("simular — baseline reproduce el run-rate real", () => {
  const r = simular(TODAS, "4B_ALEX", palancasBase(ALEX));

  it("proyección 2026 de ALEX a ritmo actual ≈ margen neto YTD anualizado", () => {
    // margen_neto_ytd 2.292,11 anualizado ≈ 3.930–3.950; el sim mezcla ×365/212 (noches)
    // con ×12/7 (fijos) y da ~4.110. Con la cuota por días el baseline ya cuadra con la ficha.
    expect(r.target.margenNetoAnual).toBeGreaterThan(3700);
    expect(r.target.margenNetoAnual).toBeLessThan(4500);
  });

  it("ingreso anual de ALEX = ingreso YTD × 365/212", () => {
    expect(r.target.ingresoAnual).toBeCloseTo(27178.17 * (DIAS_ANIO / 212), 0);
  });

  it("break-even baseline ≈ v_breakeven_ytd (82,9 % necesario, colchón 8,6 pp)", () => {
    expect(r.target.ocupNecesaria!).toBeGreaterThan(0.81);
    expect(r.target.ocupNecesaria!).toBeLessThan(0.845);
    expect(r.target.colchon!).toBeGreaterThan(0.07);
    expect(r.target.colchon!).toBeLessThan(0.105);
  });

  it("el reparto por días asigna la misma cuota a los 4 y suma el pool exacto", () => {
    for (const p of r.props) {
      expect(p.cuotaOverheadAnual).toBeCloseTo(r.overheadAnual / 4, 6);
    }
    const suma = r.props.reduce((s, p) => s + p.cuotaOverheadAnual, 0);
    expect(suma).toBeCloseTo(r.overheadAnual, 6);
  });
});

describe("simular — palancas", () => {
  it("bajar la renta 200 €/mes suma 2.400 €/año al margen neto de ALEX y no toca a las otras 3", () => {
    const base = simular(TODAS, "4B_ALEX", palancasBase(ALEX));
    const p = { ...palancasBase(ALEX), rentaMes: palancasBase(ALEX).rentaMes - 200 };
    const sim = simular(TODAS, "4B_ALEX", p);
    expect(sim.target.margenNetoAnual - base.target.margenNetoAnual).toBeCloseTo(2400, 6);
    for (const codigo of ["1A_NICA", "1A_JACO", "3G_MARE"]) {
      const antes = base.props.find((x) => x.codigo === codigo)!;
      const despues = sim.props.find((x) => x.codigo === codigo)!;
      expect(despues.margenNetoAnual).toBeCloseTo(antes.margenNetoAnual, 6);
    }
  });

  it("subir el ADR de ALEX NO toca a las otras 3: la cuota es fija por días, como el motor", () => {
    // Regla Stag 27/07/2026: antes (peso por ingreso) subir el ADR de uno bajaba la cuota
    // de los demás — un efecto colateral que el dashboard real no tiene.
    const base = simular(TODAS, "4B_ALEX", palancasBase(ALEX));
    const sim = simular(TODAS, "4B_ALEX", { ...palancasBase(ALEX), adr: 220 });
    for (const codigo of ["1A_NICA", "1A_JACO", "3G_MARE"]) {
      const antes = base.props.find((x) => x.codigo === codigo)!;
      const despues = sim.props.find((x) => x.codigo === codigo)!;
      expect(despues.cuotaOverheadAnual).toBeCloseTo(antes.cuotaOverheadAnual, 6);
      expect(despues.margenNetoAnual).toBeCloseTo(antes.margenNetoAnual, 6);
    }
    const suma = sim.props.reduce((s, p) => s + p.cuotaOverheadAnual, 0);
    expect(suma).toBeCloseTo(sim.overheadAnual, 6);
  });

  it("JACO: el ingreso es el 25 % del bruto (comisión NETA de IVA) y la de canal no aplica", () => {
    const p = palancasBase(JACO);
    const a = simular(TODAS, "1A_JACO", p);
    expect(a.target.ingresoAnual).toBeCloseTo(a.target.brutoAnual * 0.25, 6);
    const b = simular(TODAS, "1A_JACO", { ...p, comisionCanalPct: 0.2 });
    expect(b.target.ingresoAnual).toBeCloseTo(a.target.ingresoAnual, 6);
  });

  it("con meses heterogéneos (alta a mitad de año) el overhead anual sigue siendo el pool × 12/meses del año", () => {
    // MARE con solo 3 meses de actividad: su cuota YTD es menor, pero el pool mensual
    // de la empresa no cambia → overheadAnual = Σcuotas × 12/7 (meses del año), nunca ×12/3.
    const mare3 = { ...MARE, meses: 3, overheadYtd: 3000 };
    const escenario = [NICA, JACO, mare3, ALEX];
    const r = simular(escenario, "4B_ALEX", palancasBase(ALEX));
    const poolYtd = NICA.overheadYtd + JACO.overheadYtd + 3000 + ALEX.overheadYtd;
    expect(r.overheadAnual).toBeCloseTo(poolYtd * (12 / 7), 6);
  });

  it("margen directo (toggle sin overhead): el break-even excluye la cuota", () => {
    const con = simular(TODAS, "4B_ALEX", palancasBase(ALEX), { conOverhead: true });
    const sin = simular(TODAS, "4B_ALEX", palancasBase(ALEX), { conOverhead: false });
    expect(sin.target.ocupNecesaria!).toBeLessThan(con.target.ocupNecesaria!);
    expect(sin.target.margenNetoAnual).toBeCloseTo(con.target.margenNetoAnual, 6);
  });
});

describe("fraseSimulada — la respuesta es UNA frase con la gramática del titular", () => {
  const p = palancasBase(ALEX);
  const r = simular(TODAS, "4B_ALEX", p);

  it("subarriendo: nombra renta y ADR, reporta margen neto y colchón", () => {
    const f = fraseSimulada(ALEX, p, r, true);
    expect(f).toMatch(/^Con renta .+\/mes y ADR .+, Alexander deja .+\/año de margen neto \(colchón .+\)$/);
  });

  it("con el toggle en directo lo dice", () => {
    const rd = simular(TODAS, "4B_ALEX", p, { conOverhead: false });
    expect(fraseSimulada(ALEX, p, rd, false)).toContain("margen directo (sin overhead)");
  });

  it("margen negativo → 'pierde'", () => {
    const caro = { ...p, rentaMes: 4000 };
    const rc = simular(TODAS, "4B_ALEX", caro);
    expect(fraseSimulada(ALEX, caro, rc, true)).toContain("Alexander pierde");
  });

  it("titular (NICA): sin renta — usa ADR y ocupación", () => {
    const pn = palancasBase(NICA);
    const rn = simular(TODAS, "1A_NICA", pn);
    expect(fraseSimulada(NICA, pn, rn, true)).toMatch(/^Con ADR .+ y ocupación \d+ %, Nicasio/);
  });
});

// La palanca de canal directo (migración 033 + 037). Lo que se juega acá es que el simulador NO
// diga "pasá todo a directo y ganás 32.000 €": vender por directo no sube el precio, solo ahorra
// la comisión — y captar la noche cuesta algo. Por eso el ahorro va SIEMPRE con su umbral.
describe("palanca de canal directo", () => {
  const plano = (s: string | null) => s?.replace(/\s/g, " ") ?? null;

  it("en 0 no toca nada: el baseline sigue reconciliando con el YTD real", () => {
    expect(palancasBase(ALEX).directoPct).toBe(0);
    const r = simular(TODAS, "4B_ALEX", palancasBase(ALEX));
    expect(r.target.ahorroDirectoAnual).toBe(0);
    expect(fraseDirecto(ALEX, palancasBase(ALEX), r)).toBeNull();
  });

  it("el umbral de captación ES el coste del canal por noche, no un target inventado", () => {
    // adr × comisiónReal = (bruto/noches) × (comisión/bruto) = comisión/noches. Se simplifica.
    const r = simular(TODAS, "4B_ALEX", palancasBase(ALEX));
    expect(r.target.costeMaxDirectoNoche).toBeCloseTo(6312.29 / 194, 2);
  });

  it("al 100 % el ahorro es exactamente la comisión evitada, ni un euro más", () => {
    const p = { ...palancasBase(ALEX), directoPct: 1 };
    const r = simular(TODAS, "4B_ALEX", p);
    expect(r.target.ahorroDirectoAnual)
      .toBeCloseTo(r.target.costeMaxDirectoNoche * r.target.nochesAnual, 6);
  });

  it("mueve el margen justo en el ahorro, sin efectos mágicos en los costes", () => {
    const base = palancasBase(ALEX);
    const conDirecto = { ...base, directoPct: 0.2 };
    const r0 = simular(TODAS, "4B_ALEX", base, { conOverhead: false });
    const r1 = simular(TODAS, "4B_ALEX", conDirecto, { conOverhead: false });
    expect(r1.target.margenDirectoAnual - r0.target.margenDirectoAnual)
      .toBeCloseTo(r1.target.ahorroDirectoAnual, 6);
  });

  it("es lineal: el 50 % vale la mitad que el 100 %", () => {
    const mitad = simular(TODAS, "4B_ALEX", { ...palancasBase(ALEX), directoPct: 0.5 });
    const todo = simular(TODAS, "4B_ALEX", { ...palancasBase(ALEX), directoPct: 1 });
    expect(mitad.target.ahorroDirectoAnual * 2).toBeCloseTo(todo.target.ahorroDirectoAnual, 6);
  });

  it("en Jacobine NO hace nada, y la frase explica por qué", () => {
    // Modelo comisión: Samavi factura sobre el bruto, así que la comisión del canal la soporta
    // la dueña. Vender por directo le mejora el bolsillo a ella, no a Samavi.
    expect(comisionRealPct(JACO)).toBe(0);
    const p = { ...palancasBase(JACO), directoPct: 1 };
    const r = simular(TODAS, "1A_JACO", p);
    expect(r.target.ahorroDirectoAnual).toBe(0);
    expect(plano(fraseDirecto(JACO, p, r)))
      .toBe("En Jacobine el directo no le cambia nada a Samavi: la comisión del canal la paga la dueña.");
  });

  it("la frase lleva SIEMPRE la condición: sin ella el número miente", () => {
    const p = { ...palancasBase(ALEX), directoPct: 0.2 };
    const f = plano(fraseDirecto(ALEX, p, simular(TODAS, "4B_ALEX", p)))!;
    expect(f).toContain("Pasar 20 % de las noches a directo suma");
    expect(f).toContain("siempre que captar cada una cueste menos de");
  });
});
