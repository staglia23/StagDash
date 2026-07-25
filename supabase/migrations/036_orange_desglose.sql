-- 036_orange_desglose.sql — la línea de Orange se abre en sus partes reales (Stag, 25/07/2026).
--
-- ── QUÉ HABÍA DENTRO ────────────────────────────────────────────────────────────
-- Leídas las seis facturas del semestre (E10010659440 a E10011149399), la línea de 271,67 €/mes
-- resultó ser tres cosas con naturaleza distinta metidas en un solo número:
--
--   factura   total    telecom   apps Apple   dispositivos a plazos
--   ene      429,71    274,02      39,93           115,76
--   feb      285,32    133,62      35,94           115,76
--   mar      463,69    345,71      19,98            98,00
--   abr      264,81    118,85      47,96            98,00
--   may      254,82    118,85      37,97            98,00
--   jun      283,24    147,27      37,97            98,00
--   media    330,27    189,72      36,63           103,92
--
-- (La media incluye la fibra de Nicasio, ya extraída en 028, y el roaming, ya extraído en 029.
-- Lo que queda dentro de esta línea son 271,67 €/mes, y ese total NO cambia acá: solo se abre.)
--
-- ── LO IMPORTANTE: LAS CUOTAS SE TERMINAN ───────────────────────────────────────
-- El desglose exacto de "compra de dispositivos a plazos" (literal en las facturas de abril a
-- junio, con número de cuota):
--
--   iPhone 16 Pro Max 512GB   cuota  6/24   68,89 €/mes   → última cuota: octubre 2027
--   Apple Watch Ultra 3       cuota 40/48   18,95 €/mes   → última cuota: diciembre 2026
--   AirPods Pro               cuota  6/24   10,16 €/mes   → última cuota: octubre 2027
--                                           ─────────
--                                            98,00 €/mes
--
-- Modelarlas como una línea plana perpetua hace que el forward (margen asegurado, punto de
-- equilibrio) asuma que se pagan para siempre: 1.176 €/año de coste fantasma a partir de 2028,
-- y un equilibrio hoy más alto del que corresponde en las cuatro propiedades. `general_expenses`
-- ya tiene vigencia `desde`/`hasta` (migración 010) — se usa.
--
-- Es el mismo patrón que Klarna en Alexander: financiación de hardware que parece gasto
-- recurrente hasta que se termina.
--
-- ── LA CLASIFICACIÓN, DECIDIDA ──────────────────────────────────────────────────
-- Preguntado a Stag el 25/07/2026: los dispositivos a plazos y las apps de Apple son
-- OPERATIVOS — herramienta de gestión de los pisos y suscripciones del negocio. Se quedan en el
-- overhead que se prorratea a las cuatro por días bajo gestión, mismo criterio que los móviles
-- en la 029. O sea que las cuatro líneas van con `es_corporativo = false` y el total del año no
-- se mueve; lo único que cambia es que las cuotas ahora tienen fecha de fin.
-- (Corporativo, hasta hoy, es solo lo que no es gestión de pisos: viajes de desarrollo de
-- negocio —026 y 027— y roaming internacional —029.)
--
-- Dato suelto NO resuelto: la factura de marzo trae 150,00 € de "cargo por compromiso de
-- permanencia". Es un one-off y hoy queda diluido en el promedio. Sacarlo a un event de marzo
-- sería más preciso, pero la línea de 137,04 € se derivó por diferencia sobre un promedio que
-- YA lo contiene: habría que bajarla en la misma proporción o se cuenta dos veces. Se deja como
-- está a propósito, y se resuelve solo cuando Orange pase a leerse factura a factura (como la
-- limpieza en 031 y los suministros en 034) en vez de como una línea plana anual.

-- La línea vieja se convierte en la de móviles, que es lo que realmente le queda.
update general_expenses
   set importe_mes = 137.04,
       concepto    = 'Orange — móviles corporativos'
 where concepto = 'Orange — móviles y dispositivos';

insert into general_expenses (concepto, importe_mes, desde, hasta, es_corporativo)
select * from (values
  ('Apps y servicios de terceros (Apple vía Orange)', 36.63, null::date, null::date,       false),
  ('iPhone + AirPods a plazos (Orange)',              79.05, null::date, '2027-10-31'::date, false),
  ('Apple Watch Ultra a plazos (Orange)',             18.95, null::date, '2026-12-31'::date, false)
) as v(concepto, importe_mes, desde, hasta, es_corporativo)
where not exists (select 1 from general_expenses g where g.concepto = v.concepto);
