-- 091_recobro_bizum_pintura.sql — primer recobro nacido de una nota dictada (20/08/2026).
--
-- Estreno del circuito completo: Stag dictó la nota en /anotar desde el iPhone el 19/08 a
-- las 23:45 (hora de Madrid), y de ahí sale este recobro. Texto tal cual lo dictó:
--
--   "Bizum hecho el día 19 de agosto de 2026 por un precio de 40 €. A Agustín En Jacobine
--    Por pintura más arreglo en baño más. Arreglo en habitación secundaria. Salió de mi
--    cuenta. Personal"
--
-- Traía las cinco cosas que hacen falta y no hubo que preguntar nada: qué, cuánto, qué piso,
-- de qué bolsillo salió y a quién se le pagó. "Salió de mi cuenta personal" es lo que decide
-- el carril → DIRECTO_FAMILIA (089/090): se lo cobra él a su madre, no pasa por Samavi.
--
-- Contexto: es el tercer pago a Agustín en un mes (40,00 del 23/07 y 60,00 del 04/08 fueron
-- los muebles de baño y los rieles de ducha; esto es pintura y otros dos arreglos). Con éste,
-- lo que Stag lleva puesto de su bolsillo en Jacobine son 268,00 € en 7 bizums.

do $$
declare
  v_recobro bigint;
begin
  select id into v_recobro
    from recobros
   where propiedad_codigo = '1A_JACO' and fecha = date '2026-08-19' and importe = 40.00;

  if v_recobro is null then
    insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                          medio, estado, liquidacion, resuelto_fecha, resuelto_nota, notas)
    values ('1A_JACO', date '2026-08-19',
            'Pintura y arreglos en baño y habitación secundaria — mano de obra',
            40.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
            'PENDIENTE', 'DIRECTO_FAMILIA', null, null,
            'Bizum desde la cuenta personal de Stag, sin factura. ORIGEN: nota dictada por el en'
            || ' /anotar el 19/08/2026 a las 23:45 (Madrid) - la primera que estrena el circuito'
            || ' bandeja -> recobro. Dicho por el: "Bizum hecho el dia 19 de agosto de 2026 por un'
            || ' precio de 40 EUR. A Agustin En Jacobine Por pintura mas arreglo en bano mas.'
            || ' Arreglo en habitacion secundaria. Salio de mi cuenta. Personal". Al salir de su'
            || ' bolsillo se cobra por el carril DIRECTO_FAMILIA: se lo devuelve su madre, no'
            || ' Samavi. Tercer pago a Agustin en un mes (23/07 y 04/08 fueron muebles y rieles).')
    returning id into v_recobro;
  end if;

  -- La nota deja de estar pendiente y apunta a lo que salió de ella: sin esto, la bandeja
  -- no sirve de registro y Stag no puede ver si lo suyo se cargó o se perdió.
  update notas_inbox
     set estado       = 'REGISTRADA',
         procesado_en = now(),
         resultado    = 'recobro #' || v_recobro || ' · 40,00 € a cobrarle a tu madre'
   where estado = 'SIN_PROCESAR'
     and texto like 'Bizum hecho el día 19 de agosto de 2026%';
end $$;
