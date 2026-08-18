-- 085_gratificacion_jose_reserva.sql — se ata la gratificación de José a la reserva que la
-- financió (18/08/2026). Cierra el pendiente que dejó abierto la 084.
--
-- SÍ SE PUEDE VER EL PAGO EN LA API. El sync de Guesty guarda el objeto `money` entero en
-- `reservations.money_raw` (jsonb), y ahí vive el array `payments[]` con nota, importe,
-- fecha, estado y método. Para esta reserva:
--
--   confirmation_code  GY-yPcHaPx6   (id 6a626aa51cdc3e04d3e60f42)
--   1A_JACO · 24→27/07/2026 · 3 noches · source "manual" · confirmed
--   bruto 520,00 · hostPayout 520,00 · totalPaid 520,00 · isFullyPaid true · balanceDue 0
--   payments[0]: amount 520, paidAt 2026-07-23T19:25Z, status SUCCEEDED,
--                note "Entregado a Jose en mano",
--                paymentMethodId 58a1931c0000000000000e87
--
-- Ese paymentMethodId es el que Guesty usa para los cobros marcados FUERA de la pasarela:
-- aparece en todos los pagos en efectivo/mano del histórico ("Pago en efectivo" NICA 665,
-- "Entregado a Claudio en efectivo" MARE 240, "Cash Claudio" NICA 1.054,52). El detalle real
-- de cada uno vive en la nota que Stag escribe, no en un campo tipado.
--
-- EL INGRESO YA ESTÁ DEVENGADO, no falta ninguna pata. Las 3 noches (24, 25 y 26/07) caen
-- enteras en julio, y v_reservation_income da para esta reserva:
--   ingreso Samavi 130,00 (25 % de 520) + IVA repercutido 27,30 + pasivo madre 362,70 = 520,00
-- O sea: el ingreso está en JULIO y el pago a José en AGOSTO. Es correcto por devengo — no
-- son el mismo mes y no tienen por qué serlo.
--
-- REPARTO DEL EFECTIVO: de los 520,00 cobrados, 250,00 van a José (event de agosto) y los
-- 270,00 restantes se los queda Stag. Ese saldo vive en la cuenta con el socio (Confisic).

update events
   set notas = 'Indicado por Stag el 18/08/2026: gratificacion por las 5 estrellas conseguidas en el anuncio de Jacobine. PAGADO EN EFECTIVO, no por banco. ORIGEN IDENTIFICADO (085): reserva GY-yPcHaPx6 de 1A_JACO, 24-27/07/2026, 3 noches, source manual, bruto 520,00 cobrado en efectivo; en Guesty el pago figura con la nota "Entregado a Jose en mano" (23/07/2026, metodo de cobro fuera de pasarela). De esos 520: 250 para Jose y 270 se los queda Stag -> cuenta con el socio. El INGRESO de esa reserva ya esta devengado en JULIO (ingreso Samavi 130,00 + IVA repercutido 27,30 + pasivo madre 362,70): el gasto cae en agosto y el ingreso en julio, correcto por devengo. NO tiene ni va a tener respaldo bancario, por diseno (CASUISTICAS 1.4). Lo asume Samavi y no se refactura a la duena.'
 where anio = 2026 and mes = 8 and propiedad_codigo = '1A_JACO'
   and concepto = 'Gratificación a José por reseñas de 5 estrellas';
