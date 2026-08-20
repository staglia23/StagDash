-- 092_liquida_patas_y_trona.sql — las dos compras de Amazon se le descuentan ya (20/08/2026).
--
-- Stag: "lo de la trona y las patas ya adjudicalo para descontárselo como gasto repercutido".
-- Pasan a LIQUIDADO con fecha de hoy, así que `f_cuenta_duena` las resta en AGOSTO de 2026:
-- su cuenta baja 95,09 y el aviso de "por descontarle" desaparece de la ficha. OJO: agosto es
-- el mes en curso y la tarjeta no suma el mes abierto (llevaría la limpieza entera contra
-- pocos días de alquiler), así que el descuento entra al TOTAL cuando cierre agosto; en el
-- mes a mes se ve desde ya.
--
-- No hay movimiento de caja: a la dueña no se le ha transferido nada nunca, así que esto es
-- el apunte que deja constancia de que esos 95,09 ya no se le deben.
-- Los otros pendientes NO se tocan: son del carril DIRECTO_FAMILIA y se liquidan cuando Stag
-- lo arregle con su madre, no cuando Samavi le liquide el mes.

update recobros
   set estado         = 'LIQUIDADO',
       resuelto_fecha = date '2026-08-20',
       resuelto_nota  = 'Aplicado por decisión de Stag el 20/08/2026: se le descuenta en la '
                        || 'liquidación de agosto como gasto repercutido. Las dos las pagó Samavi '
                        || 'con tarjeta en Amazon; el cargo está en el extracto de agosto y NO se '
                        || 'carga como event (es neutro).'
 where propiedad_codigo = '1A_JACO'
   and estado = 'PENDIENTE'
   and liquidacion = 'CUENTA_DUENA'
   and ((fecha = date '2026-08-14' and importe = 47.98)
     or (fecha = date '2026-08-18' and importe = 47.11));
