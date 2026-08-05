-- 073_recobros_bizums_retroactivos.sql — bizums 2025 a Agustín + corrección de nota (05/08/2026).
--
-- Stag pasó el 05/08/2026 la lista retrospectiva de bizums a Agustín desde su cuenta
-- personal (el pendiente nº 1 de la sesión 04-05/08). Verificado contra producción antes
-- de cargar:
--   · sep y oct de 2025 tienen descuentos 0,00 en v_cuenta_duena → estos tres pagos NO
--     se le descontaron nunca a la dueña: entran como PENDIENTES.
--   · el 4º de la lista (20,00 del 01/03/2026, "mini UPS instalación") es el MISMO pago
--     que ya vive dentro del recobro LIQUIDADO de 77,00 de feb-2026 (Amazon 56,99 +
--     20,00 a Agustín): NO se inserta — solo se corrige la nota, que decía "efectivo
--     02/03" y era bizum del 01/03. Insertarlo de nuevo cobraría 20 € dos veces.
--   · OJO pendiente de confirmar con Stag: 53,00 + 30,00 = 83,00, el MISMO importe que
--     el descuento LIQUIDADO de nov-2025 ("Reparación lavadora y puerta corredera").
--     Conceptos distintos, suma exacta. PENDIENTE no mueve la cuenta, así que no hay
--     doble cobro posible hasta la liquidación — pero antes de liquidar estos dos hay
--     que descartar que sean la misma plata con otro nombre en la planilla.

insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, v.pagado_por, v.pagado_a,
       v.medio, v.estado, v.resuelto_fecha, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2025-09-29',
   'Reparación (sin detalle)',
   25.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Lista retrospectiva pasada por Stag el 05/08/2026. Sep-2025 tiene descuentos 0,00 en la cuenta de la dueña: nunca descontado.'),
  ('1A_JACO', date '2025-10-10',
   'Arreglo de la luz del salón',
   53.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Lista retrospectiva del 05/08/2026. OJO antes de liquidar: 53+30 (15/10) = 83,00, mismo importe que el descuento LIQUIDADO de nov-2025 "Reparación lavadora y puerta corredera" — concepto distinto, suma exacta; confirmar con Stag que no sea la misma plata.'),
  ('1A_JACO', date '2025-10-15',
   'Arreglos varios: cables de la caja de conexiones, router y cerradura inteligente',
   30.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Lista retrospectiva del 05/08/2026. OJO antes de liquidar: 30+53 (10/10) = 83,00, mismo importe que el descuento LIQUIDADO de nov-2025 — ver nota del recobro del 10/10.')
) as v(cod, fecha, concepto, importe, pagado_por, pagado_a, medio, estado, resuelto_fecha, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);

-- Corrección de la nota del mini UPS (77,00, feb-2026): el pago de 20,00 a Agustín fue
-- BIZUM del 01/03/2026 (lista de Stag del 05/08), no "efectivo 02/03" como decía la 065.
update recobros
   set notas = 'Amazon 56,99 (Revolut tarjeta Virtual, 12/02) + 20,00 a Agustin por BIZUM desde la cuenta personal de Stag (01/03/2026; la 065 lo anoto como efectivo 02/03 — corregido con la lista de bizums del 05/08/2026) = 76,99; a la duena se le descontaron 77,00 (1 centimo de redondeo de Stag). Estaba cargado por error como coste de Nicasio hasta la migracion 049. El bizum de 20,00 del 01/03 NO es un recobro nuevo: ya esta dentro de este importe liquidado.'
 where propiedad_codigo = '1A_JACO'
   and fecha = date '2026-02-12'
   and importe = 77.00;
