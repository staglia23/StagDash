-- 050_correccion_bolsillo_jacobine.sql — dos respuestas de Stag rompen la 049 (26/07/2026).
--
-- La migración 049 cargó un evento de "gastos de bolsillo" de Jacobine en febrero por 53,65 €,
-- sacado de la lista manual de Stag. Preguntadas las dudas, dos de las cuatro respuestas lo
-- invalidan en parte:
--
-- ── 1) LA LAVANDERÍA ESTABA CONTADA DOS VECES (13,00 €) ─────────────────────────────
-- Se preguntó si las secadas de la lista de bolsillo eran plata ADICIONAL a los cargos "My Laundry"
-- del Revolut. Respuesta de Stag: **es la misma**. O sea que los 8,50 y los 4,50 que entraron en la
-- 049 ya estaban en la serie de lavandería que sale del banco (feb 4,50 / mar 9,00 / abr 8,00 /
-- may 13,00 / jun 16,00). Salen.
--
-- La fuente buena es el banco: la lista de Stag es su registro de lo mismo, con otras fechas
-- (él anota cuando le pasan el dato, la tarjeta se carga cuando se carga). Regla para adelante:
-- ante solapamiento entre las dos fuentes, manda el extracto.
--
-- ── 2) "ILSA" NO ERA MENAJE, ERA UN TREN (30,65 €) ──────────────────────────────────
-- Se cargó como reposición del piso por el nombre: ILSA es una marca italiana de menaje. Es otra
-- cosa: **ILSA = Intermodalidad del Levante SA, la operadora de los trenes iryo**. Confirmado por
-- Stag. Es un billete de tren a Sevilla, no una cafetera.
--
-- Y con eso cae bajo la regla que Stag acaba de ratificar el 26/07: el transporte no se imputa a la
-- propiedad, va al overhead corporativo. Se mueve de 1A_JACO a SAMAVI_GEN/CORPORATIVO. El coste
-- existe igual — se pagó fuera del banco, como los 20,00 de la instalación del UPS — pero deja de
-- castigar la rentabilidad de Jacobine.
--
-- ── LO QUE QUEDA EN PIE DE LA 049 ───────────────────────────────────────────────────
-- Todo lo demás sigue: los 28,57 de amenities de enero, los 10,00 de amenities de febrero, la copia
-- de llaves de 46,30, los 210,00 de Claudio en Marechal, los dos NRUA y los dos recobros a la dueña
-- (mini UPS 56,99 y aspiradora 129,98, que salen del P&L porque Samavi ya se los cobró).
--
-- Efecto: Jacobine recupera 43,65 € del semestre (9.680,57 → 9.724,22 de contribución) y el
-- overhead corporativo carga 30,65 €. El portfolio mejora en los 13,00 € que estaban duplicados.

-- 1) El evento de bolsillo de febrero se queda sólo con los amenities.
update events
   set importe  = -10.00,
       notas    = 'Amenities 10,00 del 27/02, de la lista de gastos de bolsillo de Stag; fuera del extracto. Salieron dos cosas que la 049 habia metido mal: las secadas (8,50 + 4,50) son la MISMA plata que los cargos My Laundry del Revolut que ya estaban cargados aparte —confirmado por Stag el 26/07, estaban duplicadas— y los 30,65 de "ILSA" no eran menaje sino un billete de tren de iryo (ILSA = Intermodalidad del Levante SA), que va al overhead corporativo, no a la propiedad.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Gastos de bolsillo (fuera de banco)'
   and importe = -53.65;

-- 2) El billete de iryo entra al overhead corporativo, que es donde Stag quiere el transporte.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, 'SAMAVI_GEN', 'CORPORATIVO', 'Tren iryo a Sevilla (ILSA, fuera de banco)', -30.65,
       'Lista de gastos de bolsillo de Stag, "27/02/2026 ILSA 30,65". ILSA = Intermodalidad del Levante SA, la operadora de iryo: es un billete de tren, confirmado por Stag el 26/07. No aparece en el extracto de febrero, o sea que se pago por fuera de la cuenta. Estaba imputado a Jacobine por la migracion 049 leyendo ILSA como marca de menaje.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Tren iryo a Sevilla (ILSA, fuera de banco)');
