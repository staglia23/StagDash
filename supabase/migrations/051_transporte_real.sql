-- 051_transporte_real.sql — el transporte del día a día entra uno a uno (Stag, 26/07/2026).
--
-- ── EL AGUJERO ──────────────────────────────────────────────────────────────────────
-- La migración 024 borró la línea fija de "Viajes corporativos (transporte)" (200 €/mes) el
-- 25/07/2026 con este argumento: "era una provisión fija que nunca se consumía, mientras los viajes
-- REALES entran como events conciliados contra banco".
--
-- El argumento era al revés. El barrido bancario del 23/07 NO había cargado los taxis y los trenes
-- precisamente porque la regla vigente decía que esa línea los cubría. Dos días después se borró la
-- línea porque "no aparecían viajes reales como eventos"... y nadie volvió a cargarlos. Quedaron sin
-- provisión y sin evento: error circular.
--
-- Lo único cargado hasta hoy eran los tres cargos grandes de la tarjeta 0084 (feb 1.447,64 ·
-- mar 600,73 · jun 66,04). Todo el transporte de la cuenta de Revolut faltaba: 1.389,84 € en el
-- semestre, MÁS que los 1.200 € que habría provisionado la línea borrada.
--
-- ── LA DECISIÓN ─────────────────────────────────────────────────────────────────────
-- Stag, 26/07/2026: son todos de empresa (incluidos los dos Vueling de marzo y los dos trenes
-- suizos SBB de febrero), y **se cargan uno a uno, sin volver a provisionar**. Van a CORPORATIVO,
-- que es donde ya estaban los tres viajes de tarjeta: no se prorratea entre las cuatro propiedades,
-- se resta al resultado de Samavi. La rentabilidad por propiedad no se mueve.
--
-- Un evento por mes con el detalle completo en las notas — misma forma que "Comidas de negocio
-- (real bancos)". Todos los importes salen del extracto de Revolut, cargo por cargo.
--
--   feb  332,34   mar  786,29   abr  201,37   may   16,93   jun   52,91     enero: sin cargos
--
-- En marzo hay un reembolso de iryo de +53,12 (liquidado el 01/03) que se resta: los cargos brutos
-- del mes suman 839,41.

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, 'SAMAVI_GEN', 'CORPORATIVO', 'Transporte (real bancos)', v.importe, v.notas
from (values
  (2026, 2, -332.34,
   'Iryo 83,77 (09/02) + SBB Suiza 86,59 y 106,33 (25/02) + Renfe 38,75 (26/02) + Uber 8,96 y 7,94 (27/02). Extracto Revolut febrero 2026. Todos confirmados como gasto de empresa por Stag el 26/07.'),
  (2026, 3, -786.29,
   'Cabify 6,96 (02/03) + Uber 20,95 (08/03) + Licencia 431 (taxi) 12,30 (16/03) + Uber 9,93, 20,91 y 13,90 (17/03) + iryo 87,63 y Uber 14,96 (19/03) + iryo 103,96 y Vueling 135,66 (23/03) + iryo 54,26 (25/03) + Vueling 311,09, FreeNow 8,00 y Uber 23,95 (26/03) + Uber 14,95 (27/03) = 839,41 brutos, MENOS el reembolso de iryo de 53,12 liquidado el 01/03. Extracto Revolut marzo 2026.'),
  (2026, 4, -201.37,
   'Iryo 149,59 y Uber 8,96 (liquidados el 01-02/04, iniciados el 31/03) + Uber 6,94 (01/04) + Uber 10,93 y 8,00 (04/04) + Uber 16,95 (13/04). Extracto Revolut abril 2026.'),
  (2026, 5, -16.93,
   'Uber 16,93 (29/05). Unico cargo de transporte del mes. Extracto Revolut mayo 2026.'),
  (2026, 6, -52.91,
   'Cabify 22,99 (10/06) + Uber 13,93 (24/06) + Cabify 15,99 (28/06). Extracto Revolut junio 2026.')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Transporte (real bancos)');

-- ── Y UNA MARCA DE PROCEDENCIA ──────────────────────────────────────────────────────
-- Stag avisó el 26/07 de que la planilla manual que pasó es como se manejaba ANTES del dashboard y
-- puede tener errores: hay que contrastar contra documentación real o contra su confirmación, no
-- asumir. Revisadas las cargas de la migración 049 una por una, seis apuntes descansan SÓLO en esa
-- planilla — no hay cargo bancario ni factura detrás, porque se pagaron en efectivo o por fuera:
--
--   3G_MARE  ene   60,00   cristales (Claudio)
--   3G_MARE  mar  150,00   arreglo de bañera (Claudio)
--   1A_NICA  feb   32,73   NRUA registro
--   4B_ALEX  feb   28,67   NRUA registro
--   1A_JACO  ene   28,57   amenities
--   1A_JACO  feb   10,00   amenities
--
-- Se quedan cargados —es el criterio de peor caso que el repo ya usa (022, 031, 034, 044)— pero la
-- nota lo dice, para que nadie los lea como conciliados. La reimputación de la copia de llaves
-- (46,30, de Nicasio a Jacobine) también sale de la planilla, aunque el cargo bancario sí existe.

update events
   set notas = notas || ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.'
 where anio = 2026
   and concepto in ('Cristales (Claudio, efectivo)', 'Arreglo de bañera (Claudio, efectivo)',
                    'NRUA — registro único de alojamiento', 'Gastos de bolsillo (fuera de banco)')
   and notas not like '%FUENTE: solo la planilla manual%';

update events
   set notas = notas || ' ⚑ La REIMPUTACION a Jacobine sale solo de la planilla manual de Stag; el cargo bancario si existe. Pendiente de confirmar que la copia de llaves era del piso de Sevilla y no de uno de Madrid.'
 where anio = 2026 and mes = 2 and propiedad_codigo = '1A_JACO'
   and concepto = 'Copia de llaves (Ferretería Diego de León)'
   and notas not like '%REIMPUTACION a Jacobine sale solo%';
