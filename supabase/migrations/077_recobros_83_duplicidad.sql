-- 077_recobros_83_duplicidad.sql — los bizums de oct-2025 eran el descuento de nov (11/08/2026).
--
-- Stag confirmó ("sí, creo que es duplicidad, así que cerrá eso"): los bizums a Agustín
-- del 10/10/2025 (53,00, luz del salón) y 15/10/2025 (30,00, cables/router/cerradura)
-- son la MISMA plata que el descuento de 83,00 que la planilla le hizo a la dueña en
-- nov-2025 con el concepto "Reparación lavadora y puerta corredera" (la alarma de la 073
-- era correcta: concepto distinto, suma exacta). Pasan a LIQUIDADO cruzados a ese
-- descuento — cobrarlos de nuevo duplicaba. Como salieron de la cuenta PERSONAL de Stag
-- y Samavi ya cobró los 83,00 en nov-2025, Samavi le debe 83,00 a Stag (cuenta con
-- socio, carril Confisic). Pendientes de recobro quedan 3: 25,00 + 40,00 + 60,00 = 125,00.
update recobros
   set estado = 'LIQUIDADO',
       resuelto_fecha = date '2025-11-30',
       resuelto_nota = 'Duplicidad CONFIRMADA por Stag (11/08/2026): 53+30 = 83,00 es el mismo dinero que el descuento de nov-2025 "Reparacion lavadora y puerta corredera" (la planilla lo anoto con otro concepto). NO se descuenta de nuevo a la duena. Como los bizums salieron de la cuenta PERSONAL de Stag y Samavi ya cobro los 83,00 en nov-2025, Samavi le debe 83,00 a Stag: cuenta con socio (Confisic).'
 where propiedad_codigo = '1A_JACO'
   and estado = 'PENDIENTE'
   and ((fecha = date '2025-10-10' and importe = 53.00)
     or (fecha = date '2025-10-15' and importe = 30.00));
