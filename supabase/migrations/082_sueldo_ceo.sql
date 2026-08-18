-- 082_sueldo_ceo.sql — el sueldo de Stag pasa de 3.000 a 3.500 € NETOS (18/08/2026).
--
-- ⚠⚠ NO APLICAR TODAVÍA. Faltan los dos datos que fijan los números de abajo.
--    Análisis completo: docs/operativa/RETRIBUCION_CEO.md
--
-- QUÉ SE VERIFICÓ ANTES DE ESCRIBIR ESTO (18/08/2026, extractos de Drive):
--   · La provisión vieja era CORRECTA y ahora está probada contra banco, no supuesta:
--     3.333,33 brutos × 0,90 (retención 10 % del modelo 111 2T) = 3.000,00 netos EXACTOS,
--     que son los que salen de Revolut ...7165 el 03/05, el 01/06 y el 01/07 con el
--     concepto literal "Retribución administrador".
--   · RETA clavado en 370,75 (BBVA ...8920, "TGSS. COTIZACION 005 R.E.AUTONOMOS": 29/05,
--     30/06, 31/07). Coste-CEO real hoy: 3.333,33 + 370,75 = 3.704,08 €/mes.
--   · JULIO NO FUERON 3.500 NETOS. No existe salida de 3.500 hacia Stag en mayo, junio ni
--     julio en ninguna de las dos cuentas. El único 3.500,00 del período es un traspaso
--     INTERNO del 11/06 entre dos cuentas Revolut de la propia Samavi. Por eso esta
--     migración arranca en AGOSTO y no toca julio, que está cerrado y cuadrado.
--     Punto ciego declarado: no hay extracto de la cuenta Revolut "Samavi Invest" en Drive
--     y la carpeta BANCOS EXTRACTOS de agosto está vacía.
--
-- LOS DOS DATOS QUE FALTAN:
--   (1) DESDE QUÉ MES. Acá va agosto (lo antes posible sin reescribir un mes cerrado).
--   (2) EL BRUTO, que depende del tipo de retención — y el 10 % de hoy no es defendible
--       (art. 101.2 LIRPF: administrador = 35 %, o 19 % si el INCN del ejercicio anterior
--       es < 100.000 €). El dato que decide es el INCN de las cuentas 2025 depositadas, y
--       lo tiene Confisic. NO es la cifra de ingresos del dashboard.
--
--          neto 3.500 con retención 19 %  ->  bruto 4.320,99  (el que va escrito abajo)
--          neto 3.500 con retención 35 %  ->  bruto 5.384,62
--          3.500 LIMPIOS tras la renta    ->  bruto 4.531,86
--
-- LO QUE CUESTA (proyección de año completo 2026; resultado Samavi hoy = 11.995,62):
--   19 % -> +11.851,89 €/año -> resultado 143,73. El aumento se come el beneficio ENTERO.
--   Y arrastra a Alexander, Marechal y Jacobine por debajo de su punto de equilibrio.
--   Es una decisión legítima de Stag, pero hay que tomarla sabiendo eso.

-- ── 1) Cerrar la vigencia de la provisión verificada ─────────────────────────────────
-- El motor evalúa la vigencia contra el día 1 de cada mes (f_samavi_gen_mensual):
-- con hasta = 31/07 el último mes que la cobra es julio.
update general_expenses
   set hasta = date '2026-07-31'
 where concepto = 'Sueldo Stag bruto'
   and importe_mes = 3333.33
   and hasta is null;

-- ── 2) Abrir la nueva ────────────────────────────────────────────────────────────────
-- Misma etiqueta a propósito: es el mismo gasto en otro período de vigencia, que es
-- exactamente para lo que existen `desde`/`hasta`. No hay unique por concepto.
insert into general_expenses (concepto, importe_mes, desde, hasta, es_corporativo)
select 'Sueldo Stag bruto', 4320.99, date '2026-08-01', null, false
where not exists (
  select 1 from general_expenses
   where concepto = 'Sueldo Stag bruto'
     and desde = date '2026-08-01');

-- ── 3) Comprobación (dejar el resultado en el commit) ────────────────────────────────
-- select concepto, importe_mes, desde, hasta from general_expenses
--  where concepto in ('Sueldo Stag bruto','TGSS RETA Stag') order by desde nulls first;
-- select * from f_samavi_gen_mensual('2026-07-01','2026-09-30');   -- jul 4.538,12 -> ago +987,66
-- select * from v_breakeven_ytd order by codigo;

-- ── PENDIENTE QUE NO ENTRA ACÁ ───────────────────────────────────────────────────────
-- La cuota de RETA sube sola en 2026: la base mínima del autónomo societario pasa a
-- 1.424,40 €/mes y los 370,75 de hoy corresponden a una base de ~1.180, por debajo del
-- mínimo. La TGSS reclamará la diferencia en la regularización anual (~770–935 € de
-- golpe) y la cuota queda en ~435–449 €/mes. NO se carga todavía porque el importe hay
-- que confirmarlo con Confisic.
-- Tampoco puede ir a `avisos`: esa tabla tiene FK a listings(codigo) y sólo admite avisos
-- POR PISO — un cambio de coste de la sociedad entera no tiene dónde escribirse hoy.
