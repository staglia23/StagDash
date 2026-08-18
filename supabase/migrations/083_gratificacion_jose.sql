-- 083_gratificacion_jose.sql — gratificación de 250 € a José por las 5 estrellas de Jacobine
-- (18/08/2026, indicado por Stag).
--
-- Stag: "le voy a pagar 250 € a José en concepto de gratificación por 5 estrellas en el
-- anuncio de Jacobine, el pago se lo hago hoy". Se carga como coste directo de 1A_JACO en
-- agosto, siguiendo el precedente de todo lo que José gasta o cobra en Sevilla (lavandería,
-- amenities, toallas): lo asume Samavi, no se refactura a la dueña. Lo único que la dueña
-- paga en Jacobine son los 700 €/mes de limpieza.
--
-- ⚑ SIN RESPALDO BANCARIO TODAVÍA: el pago es de hoy y el cierre conciliado llega hasta
--    julio (v_freshness.cierre_hasta = 2026-07-01). Verificar contra el extracto de agosto
--    cuando Stag lo suba: debe aparecer una salida de 250,00 € hacia José Modesto Salgado
--    Salinas (IBAN ...4334, el mismo de la nómina).
--
-- ⚠ AVISO LABORAL, para Confisic — esto NO se resuelve acá:
--    José está en RÉGIMEN GENERAL (nómina 484,00 + TGSS 204,86/mes, verificado en la 052).
--    Una gratificación a un trabajador por cuenta ajena es SALARIO (art. 26.1 ET) y forma
--    parte de la base de cotización (art. 147 LGSS): debería ir por nómina, cotizar y llevar
--    retención de IRPF. Pagada como transferencia suelta no cotiza ni se declara en el
--    111/190. Si se regulariza, el coste real para Samavi no son 250 € sino ~325 € (la SS a
--    cargo de la empresa añade en torno al 30 %), y a José le llegarían menos de 250 si se
--    le retiene. Se carga por el importe que sale del banco (250) porque es lo que el motor
--    modela; el complemento se cargará cuando Confisic diga cómo se instrumenta.

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 8, '1A_JACO', 'OTROS',
       'Gratificación a José por reseñas de 5 estrellas', -250.00,
       'Indicado por Stag el 18/08/2026: gratificacion por las 5 estrellas conseguidas en el anuncio de Jacobine. Pago anunciado para hoy desde Revolut. Lo asume Samavi (precedente: amenities, lavanderia y toallas de Sevilla), no se refactura a la duena. ⚑ PENDIENTE de verificar contra el extracto de agosto: debe haber una salida de 250,00 hacia Jose Modesto. ⚠ Jose esta en regimen general: una gratificacion es salario (art. 26.1 ET) y cotiza (art. 147 LGSS) - deberia ir por nomina. Si se regulariza, el coste real sube a ~325 con la SS a cargo de empresa. Consultar a Confisic.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 8 and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Gratificación a José por reseñas de 5 estrellas');
