-- 044_auditoria_marechal.sql — el aire acondicionado estaba compensado de más (Stag, 26/07/2026).
--
-- ── LA INTERVENCIÓN COSTÓ 1.834,50, NO 1.754,50 ─────────────────────────────────
-- Del correo del 21/04/2026 a José Luis Angulo, que él aceptó el 04/05 ("me parece bien hacerlo
-- tal como indicas descontando las cantidades mencionadas"):
--
--   Factura nº 235 · Nico Chaban (A/C Ferroli)   base 1.450,00 + IVA 304,50 = 1.754,50 €
--   Claudio (portero) · reparación y pintura                                       80,00 €
--                                                                                ─────────
--   Total de la intervención                                                    1.834,50 €
--
-- Y la compensación pactada, que es exactamente ese total:
--   mayo   — no se gira la renta                          1.100,00
--   junio  — se giran 365,50, se compensan                  734,50
--                                                        ─────────
--                                                        1.834,50
--
-- El motor tenía cargada la compensación COMPLETA (1.834,50) pero sólo el coste de la factura
-- de Chaban (1.754,50). Marechal aparecía 80,00 € mejor de lo que era.
--
-- El correo explica por qué faltaban: "al no emitir factura formal se imputa directamente a la
-- propiedad vía compensación de rentas, sin pasar por la contabilidad de Samavi". Eso es cierto
-- a efectos fiscales, pero este dashboard mide RENTABILIDAD, no deducibilidad — ya carga por
-- criterio de peor caso costes cuyo IVA no se recupera (022, 031, 034). Confirmado por Stag el
-- 26/07/2026: los 80 € los puso Samavi en efectivo. Son coste de Marechal.
--
-- Se imputan a abril, junto a la factura de Chaban, para que el coste y su compensación cuenten
-- la misma historia en el mismo trimestre.
--
-- ── Y UNA NOTA QUE SE CONTRADECÍA SOLA ──────────────────────────────────────────
-- El evento de renta de junio decía en el concepto "renta pagada: 365,50" (correcto: está en el
-- extracto de Revolut del 08/06) y en las notas "renta efectiva 600". Los 600 no salen de
-- ningún cálculo. Segunda nota mentirosa que aparece en dos auditorías seguidas — la primera
-- fue la del termo de Nicasio (041). El importe siempre estuvo bien; el texto no.

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 4, '3G_MARE', 'OTROS', 'Reparación y pintura tras el A/C (Claudio, efectivo)', -80.00,
       'Segundo tramo de la intervencion del aire acondicionado: 1.754,50 (factura 235 Nico Chaban) + 80,00 (Claudio, portero, en efectivo) = 1.834,50, que es exactamente lo compensado en las rentas de mayo y junio. Sin factura formal; pagado en efectivo por Samavi, confirmado por Stag 26/07/2026.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 4 and e.propiedad_codigo = '3G_MARE'
     and e.concepto = 'Reparación y pintura tras el A/C (Claudio, efectivo)');

update events
   set notas = 'Renta transferida: 365,50 el 08/06, verificado en el extracto de Revolut. Compensacion 734,50 del plan de aire acondicionado acordado con Jose Luis el 21/04 y aceptado el 04/05.'
 where propiedad_codigo = '3G_MARE' and anio = 2026 and mes = 6
   and categoria = 'RENTA' and notas like '%renta efectiva 600%';
