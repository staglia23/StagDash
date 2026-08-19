-- 086_recobros_patas_y_trona.sql — dos compras de Amazon para Jacobine, a cuenta de la
-- dueña (19/08/2026).
--
-- Indicado por Stag: las dos son gasto del PROPIETARIO, no de Samavi.
--   · 14/08/2026 — patas ajustables 47,98 €: soportes para los muebles de lavabo de los
--     dos baños, que se estaban descolgando de la pared. Cierran el trabajo que Agustín
--     empezó en julio (recobros PENDIENTES de 40,00 del 23/07 y 60,00 del 04/08): la 065
--     ya dejó anotado "faltan las patas, generará otro recobro". Este es ese recobro.
--   · 18/08/2026 — trona 47,11 €: equipamiento del piso (mismo criterio que la aspiradora
--     de mar-2026 y el mini UPS de feb-2026, ambos descontados a la dueña).
--
-- Las dos las pagó SAMAVI con tarjeta en Amazon → a diferencia de los bizums de Agustín,
-- ESTAS SÍ VAN A APARECER EN EL EXTRACTO DE AGOSTO. ⚑ Al conciliar agosto, los dos cargos
-- de Amazon (47,98 y 47,11) NO se cargan como `events`: un recobro es neutro para Samavi
-- (entra y sale) y meterlo en el P&L lo contaría dos veces mal — como coste que Samavi no
-- tuvo y, al cobrarlo, como ingreso que no existe (regla de CASUISTICAS §3, cicatriz 049).
--
-- Quedan PENDIENTES hasta que Stag le liquide el mes a la dueña. Pendientes tras esta
-- migración: 5 pagos, 220,09 € (25,00 + 40,00 + 60,00 + 47,98 + 47,11); de ellos 125,00
-- salieron de la cuenta personal de Stag y 95,09 de la de Samavi.

insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, v.pagado_por, v.pagado_a,
       v.medio, v.estado, v.resuelto_fecha, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2026-08-14',
   'Patas ajustables para los muebles de los 2 baños',
   47.98, 'SAMAVI', 'Amazon', 'tarjeta',
   'PENDIENTE', null::date, null,
   'Indicado por Stag el 19/08/2026. Soporte inferior de los muebles de lavabo de los dos banos, que se descolgaban de la pared. Cierra la compra que la 065 dejo anotada como pendiente ("faltan las patas, generara otro recobro") y completa la mano de obra de Agustin (recobros de 40,00 del 23/07 y 60,00 del 04/08). Pagado por SAMAVI con tarjeta: el cargo de Amazon CAE EN EL EXTRACTO DE AGOSTO - no cargarlo como event, es neutro (CASUISTICAS 3).'),
  ('1A_JACO', date '2026-08-18',
   'Trona (equipamiento del piso)',
   47.11, 'SAMAVI', 'Amazon', 'tarjeta',
   'PENDIENTE', null::date, null,
   'Indicado por Stag el 19/08/2026: gasto de la propietaria, no lo asume Samavi. Mismo criterio que la aspiradora (130,00, mar-2026) y el mini UPS (77,00, feb-2026), ambos descontados en la cuenta corriente de la duena. Pagado por SAMAVI con tarjeta: el cargo de Amazon CAE EN EL EXTRACTO DE AGOSTO - no cargarlo como event, es neutro (CASUISTICAS 3).')
) as v(cod, fecha, concepto, importe, pagado_por, pagado_a, medio, estado, resuelto_fecha, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);
