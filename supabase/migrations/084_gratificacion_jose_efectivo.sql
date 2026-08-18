-- 084_gratificacion_jose_efectivo.sql — la gratificación de José se paga en EFECTIVO
-- (18/08/2026, precisión de Stag).
--
-- La 083 la cargó como si fuera a salir del banco. No es así: Stag cobró una reserva en
-- efectivo por fuera y de ese efectivo le da 250 € a José; el resto se lo queda él.
--
-- Consecuencias para el modelo, todas de forma:
--   · NO va a aparecer en el extracto de agosto. Se retira la marca ⚑ "pendiente de
--     verificar contra banco" que puso la 083: ese pago no tiene respaldo bancario **por
--     diseño**, igual que los otros pagos en efectivo del negocio (CASUISTICAS §1.4, punto 1).
--   · El efectivo de una reserva cobrada así queda en poder de Stag → cuenta con el socio
--     (mismo carril que la reserva directa de JACO de julio, 520 €, ver la 074). Pagar con
--     ese efectivo un gasto de Samavi reduce ese saldo en 250 €. Lo regulariza Confisic.
--   · El importe y la imputación no cambian: sigue siendo −250,00 € de coste directo de
--     1A_JACO en agosto.
--
-- PENDIENTE (dato que falta, no bloquea): qué reserva es y por cuánto. Hace falta para
-- saber si su ingreso ya está devengado en el motor o si entró por fuera de Guesty — de eso
-- depende que el margen de Jacobine en agosto esté completo o le falte la pata del ingreso.

update events
   set notas = 'Indicado por Stag el 18/08/2026: gratificacion por las 5 estrellas conseguidas en el anuncio de Jacobine. PAGADO EN EFECTIVO, no por banco: Stag cobro una reserva en efectivo por fuera y de ese dinero le da 250 a Jose; el resto se lo queda el. NO tiene ni va a tener respaldo bancario, por diseno (mismo caso que los demas pagos en efectivo, CASUISTICAS 1.4). El efectivo cobrado queda en poder de Stag -> cuenta con el socio (mismo carril que la reserva directa de JACO de julio, 520, migracion 074); pagar con el un gasto de Samavi baja ese saldo en 250. Lo asume Samavi y no se refactura a la duena, igual que amenities, lavanderia y toallas de Sevilla. PENDIENTE: identificar la reserva y su importe (084).'
 where anio = 2026 and mes = 8 and propiedad_codigo = '1A_JACO'
   and concepto = 'Gratificación a José por reseñas de 5 estrellas';
