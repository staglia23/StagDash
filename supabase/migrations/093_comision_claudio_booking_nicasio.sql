-- 093_comision_claudio_booking_nicasio.sql — comisión de 100 € a Claudio por la reserva de
-- Booking cobrada en efectivo en Nicasio. Segunda nota dictada que se convierte (29/08/2026).
--
-- Texto de la nota (v_notas_inbox id 10, dictada en /anotar el 24/08/2026 a las 22:19 UTC y
-- editada un minuto después para agregar la fecha del pago):
--   "De lo cobrado en efectivo de una reserva de Booking.com en el apartamento Nicasio recibí
--    1055 € de los cuales 100 € se los di a Claudio en concepto de comisión el día 25/08/26"
--
-- LA RESERVA es BC-68wENnWVl (1A_NICA, 16→23/08/2026, 7 noches, Booking.com): bruto 1.054,52
-- (alojamiento 994,52 + limpieza 60), cobrada FUERA de la pasarela — en money_raw.payments
-- figura "Cash Claudio", 1.054,52 €, paidAt 11/08/2026, paymentMethodId
-- 58a1931c0000000000000e87 (el de todo lo cobrado fuera de pasarela, CASUISTICAS §1.4 punto 4).
-- Stag dice 1.055: es el redondeo del billete (+0,48 €, no se registra).
--
-- TRATAMIENTO, el mismo que la 084/085 (efectivo de la reserva de José en Jacobine):
--   · El INGRESO ya está devengado por el motor (las 7 noches caen en agosto, host_payout
--     1.054,52): no se toca nada de ingresos ni de bank_deposits. Nunca va a tener depósito
--     bancario y eso es lo esperado, no un agujero (pendientes: cierre de agosto, punto 11).
--   · Los 100 € a Claudio son un GASTO de 1A_NICA en agosto, pagado en efectivo → event
--     negativo. Claudio es el portero de Segovia 8; precedentes de pagos suyos en efectivo:
--     events 107, 109 y 98 (2026) y la migración 049. Sin factura y sin respaldo bancario
--     por diseño: NO buscarlo en el extracto de agosto.
--   · El resto del efectivo (1.054,52 − 100 = 954,52) queda en poder de Stag → cuenta con el
--     socio (la regulariza Confisic). Con los 270 de la reserva de JACO de julio (085), el
--     efectivo de reservas en manos de Stag en 2026 suma 1.224,52.
--
-- CLASIFICACIÓN: OTROS, como los demás pagos a Claudio. NO es comisión de canal (Booking cobra
-- la suya aparte, por factura: event 97): es la retribución al portero por gestionar el cobro
-- y la entrada de esa reserva.

do $$
declare
  v_event bigint;
begin
  select id into v_event
    from events
   where anio = 2026 and mes = 8 and propiedad_codigo = '1A_NICA'
     and concepto = 'Comisión a Claudio por la reserva Booking BC-68wENnWVl (efectivo)';

  if v_event is null then
    insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
    values (2026, 8, '1A_NICA', 'OTROS',
            'Comisión a Claudio por la reserva Booking BC-68wENnWVl (efectivo)', -100.00,
            'ORIGEN: nota dictada por Stag en /anotar el 24/08/2026 (id 10): "De lo cobrado en'
            || ' efectivo de una reserva de Booking.com en el apartamento Nicasio recibi 1055 EUR'
            || ' de los cuales 100 EUR se los di a Claudio en concepto de comision el dia'
            || ' 25/08/26". La reserva es BC-68wENnWVl (16-23/08/2026, 7 noches, bruto 1.054,52,'
            || ' cobrada fuera de pasarela con la nota "Cash Claudio" el 11/08). PAGADO EN'
            || ' EFECTIVO el 25/08/2026 a Claudio (portero de Segovia 8), sin factura y sin'
            || ' respaldo bancario por diseno: no buscarlo en el extracto (CASUISTICAS 1.4). El'
            || ' ingreso de la reserva ya esta devengado en agosto por el motor. Los 954,52'
            || ' restantes quedan en poder de Stag -> cuenta con el socio (mismo carril que los'
            || ' 270 de la reserva de JACO de julio, 085). Los 0,48 de redondeo del billete no'
            || ' se registran.')
    returning id into v_event;
  end if;

  -- La nota deja de estar pendiente y apunta a lo que salió de ella.
  update notas_inbox
     set estado       = 'REGISTRADA',
         procesado_en = now(),
         resultado    = 'event #' || v_event || ' · −100,00 € Nicasio ago-2026 (comisión a Claudio,'
                        || ' efectivo). Los 954,52 € restantes quedan en tu poder → cuenta con el socio'
   where id = 10 and estado = 'SIN_PROCESAR';
end $$;
