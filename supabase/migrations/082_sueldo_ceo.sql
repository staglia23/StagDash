-- 082_sueldo_ceo.sql — el sueldo de Stag pasa de 3.000 a 3.500 € NETOS desde agosto (18/08/2026).
--
-- Decisión de Stag del 18/08/2026, tomada con los números delante.
-- Análisis completo: docs/operativa/RETRIBUCION_CEO.md
--
-- QUÉ SE VERIFICÓ ANTES DE APLICAR (extractos de Drive, mayo/junio/julio):
--   · La provisión vieja era CORRECTA y ahora está probada contra banco, no supuesta:
--     3.333,33 brutos × 0,90 (retención 10 % del modelo 111 2T) = 3.000,00 netos EXACTOS,
--     que son los que salen de Revolut ...7165 el 03/05, el 01/06 y el 01/07 con el
--     concepto literal "Retribución administrador".
--   · RETA clavado en 370,75 (BBVA ...8920, "TGSS. COTIZACION 005 R.E.AUTONOMOS": 29/05,
--     30/06, 31/07). Coste-CEO hasta julio: 3.333,33 + 370,75 = 3.704,08 €/mes.
--   · JULIO NO FUERON 3.500 NETOS. No existe salida de 3.500 hacia Stag en mayo, junio ni
--     julio en ninguna de las dos cuentas de la sociedad; el único 3.500,00 del período es
--     un traspaso INTERNO del 11/06 entre dos cuentas Revolut de la propia Samavi. Por eso
--     esto arranca en AGOSTO y no toca julio, que está cerrado y cuadrado al céntimo.
--     Punto ciego declarado: no hay extracto de la cuenta Revolut "Samavi Invest" en Drive
--     y la carpeta BANCOS EXTRACTOS de agosto estaba vacía el día de la migración.
--
-- EL BRUTO Y SU SUPUESTO: 4.320,99 = 3.500 / 0,81, o sea retención del 19 % del art. 101.2
-- LIRPF (administrador de entidad con INCN < 100.000 €). **El 10 % que aplican hoy no es
-- defendible** bajo ninguna de las dos vías: ni tipo fijo de administrador (35 %/19 %) ni
-- procedimiento general (que para 40.000 € brutos daría 17,94 %). PENDIENTE: que Confisic
-- confirme el INCN de las cuentas 2025 depositadas — si llegó a 100.000 €, el tipo es 35 %
-- y el bruto pasa a 5.384,62. Entre una y otra hay 12.763 €/año para el mismo neto.
-- Ojo: el INCN contable NO es la cifra de ingresos del dashboard (el motor registra JACO
-- por el 25 % neto de comisión y excluye el IVA repercutido).
--
-- LO QUE CUESTA, con los números del motor:
--   · Pool de overhead: 4.337,18 -> 5.324,84 €/mes desde agosto (+987,66; el sueldo pasa a
--     ser el 88 % del pool). Cada piso absorbe un cuarto: +246,92 €/mes.
--   · Resultado Samavi YTD: 11.400,42 -> 10.412,75. Año completo 2026: 11.995,62 -> 7.057,32.
--   · A run-rate de 12 meses cuesta 11.851,89 €/año, y el resultado anual proyectado era
--     11.995,62: **el aumento se come el beneficio entero**. El techo de resultado cero es
--     un neto de 3.510 €/mes. Stag lo decidió sabiéndolo.

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

-- ── Comprobado tras aplicar ──────────────────────────────────────────────────────────
--   f_samavi_gen_mensual: jul 4.538,12 (sin tocar) · ago–dic 5.324,84
--   v_resultado_samavi.resultado_samavi: 10.412,75
--   v_breakeven_ytd.colchon: MARE 5,11 pp · ALEX 5,57 pp · JACO 15,90 pp · NICA 40,40 pp

-- ── PENDIENTE QUE NO ENTRA ACÁ ───────────────────────────────────────────────────────
-- La cuota de RETA sube sola en 2026: la base mínima del autónomo societario pasa a
-- 1.424,40 €/mes y los 370,75 de hoy corresponden a una base de ~1.180, por debajo del
-- mínimo. La TGSS reclamará la diferencia en la regularización anual (~770–935 € de
-- golpe) y la cuota queda en ~435–449 €/mes. NO se carga todavía porque el importe hay
-- que confirmarlo con Confisic.
-- Tampoco puede ir a `avisos`: esa tabla tiene FK a listings(codigo) y sólo admite avisos
-- POR PISO — un cambio de coste de la sociedad entera no tiene dónde escribirse hoy.
