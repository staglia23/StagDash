// Panel de conciliación bancaria de /cuadre (datos: vista v_cuadre_banco).
// Por cuenta bancaria: cuánto pagó Airbnb vs cuánto entró al banco en el período con
// extractos cargados. La "diferencia acumulada" es el dinero EN TRÁNSITO (Airbnb paga
// ~5 días después del check-in) — es normal que sea != 0; lo que importa es que se
// mantenga chica. Verde si el en-tránsito es < 15 % de lo que pagó Airbnb.
//
// Mes-borde (migración 057, decisión Stag 27/07/2026): el primer mes de la ventana
// arrastra payouts de estancias ANTERIORES al período (Revolut ene: +2.656,55 de
// dic-2025) — arranque, no tránsito. El semáforo usa diferencia_acum_ajustada (excluye
// ese mes) y el % se calcula contra lo pagado desde el 2º mes; si la vista no trae la
// columna (datos viejos), cae al acumulado clásico.

export type BancoRow = {
  iban: string; cuenta: string; anio: number; mes: number;
  airbnb_pago: number | string; banco_recibio: number | string;
  depositos: number | string; diferencia_mes: number | string; diferencia_acum: number | string;
  mes_borde?: boolean | null;
  diferencia_acum_ajustada?: number | string | null;
};

export type ResumenCuenta = {
  iban: string; cuenta: string;
  airbnb: number; banco: number; enTransito: number;
  meses: number; ok: boolean;
  /** true si el semáforo excluyó el mes-borde (la vista trae la columna ajustada) */
  bordeExcluido: boolean;
};

const n = (v: number | string) => Number(v);

export const UMBRAL_TRANSITO = 0.15; // en tránsito aceptable como fracción de lo pagado

export function resumenBanco(rows: BancoRow[]): ResumenCuenta[] {
  const porIban = new Map<string, BancoRow[]>();
  for (const r of rows) {
    const arr = porIban.get(r.iban);
    if (arr) arr.push(r);
    else porIban.set(r.iban, [r]);
  }
  const out: ResumenCuenta[] = [];
  for (const [iban, rs] of porIban) {
    const ord = [...rs].sort((a, b) => (a.anio - b.anio) || (a.mes - b.mes));
    const airbnb = ord.reduce((s, r) => s + n(r.airbnb_pago), 0);
    const banco = ord.reduce((s, r) => s + n(r.banco_recibio), 0);
    const ultimo = ord[ord.length - 1];
    const bordeExcluido = ultimo?.diferencia_acum_ajustada != null && ord.length > 1;
    const enTransito = bordeExcluido
      ? n(ultimo!.diferencia_acum_ajustada!)
      : n(ultimo?.diferencia_acum ?? 0);
    // el % se mide contra el mismo período que el numerador: sin el mes-borde si se excluyó
    const base = bordeExcluido
      ? ord.filter((r) => !r.mes_borde).reduce((s, r) => s + n(r.airbnb_pago), 0)
      : airbnb;
    const ok = base === 0 ? true : Math.abs(enTransito) / base < UMBRAL_TRANSITO;
    out.push({ iban, cuenta: ord[0].cuenta, airbnb, banco, enTransito, meses: ord.length, ok, bordeExcluido });
  }
  return out.sort((a, b) => a.iban.localeCompare(b.iban));
}

/** ¿Todas las cuentas dentro de tolerancia? */
export const bancoTodoOk = (r: ResumenCuenta[]) => r.length > 0 && r.every((c) => c.ok);
