-- 053_renta_alexander_sube.sql — la renta de Alexander sube el 01/10 y el motor no lo sabía.
--
-- ── EL HALLAZGO ─────────────────────────────────────────────────────────────────
-- Leído el contrato firmado (nº 001/2025, 01/10/2025) y la hoja de cuentas del amoblamiento que
-- Stag pasó el 27/07/2026, la renta de Alexander no es lo que el motor cree:
--
--   Renta del contrato (cláusula 4.1)                            1.614,80 €/mes + impuestos
--   Base que Alberto factura hoy                                 1.386,49 €/mes
--   Diferencia                                                     255,31 €/mes
--
-- Esos 255,31 no son un precio pactado: son la DEVOLUCIÓN del amoblamiento. El contrato entregaba
-- el piso vacío ("sin mobiliario, ni enseres", expositivo III) y lo amuebló Samavi:
--
--   Amoblamiento, sin IVA                                         4.774,00
--   + Comisión Stag                                                 358,00
--   − Adelanto de Alberto                                        −1.000,00
--   − Septiembre que pagó Samavi por él (hipoteca 926 +
--     comunidad 115 + seguro 27)                                 −1.068,00
--                                                                ─────────
--   Saldo a favor de Samavi                                       3.064,00  →  ÷12 = 255,31/mes
--
-- **Se agota con la renta de septiembre de 2026.** Desde octubre la renta vuelve a base completa.
-- El motor tiene `renta_base = 1414,22` (la base rebajada + impuestos) y la proyecta hacia adelante
-- como si fuera perpetua, así que el punto de equilibrio, el margen asegurado y el simulador de
-- Alexander están todos calculados con una renta que en tres meses deja de existir.
--
--   Coste de renta en el modelo (base × 1,21, peor caso de IVA no deducible):
--     hoy         1.386,49 × 1,21 = 1.677,65 €/mes
--     desde oct   1.641,80 × 1,21 = 1.986,58 €/mes
--     salto                          +308,93 €/mes = +3.707 €/año
--
-- El margen neto anual de Alexander a run-rate es ≈3.929 €. **La subida se lleva el 94 %.** Y no
-- hace falta que nadie la pida: ocurre sola el mismo día en que el contrato se prorroga.
--
-- Es exactamente el agujero que la migración 045 abrió `avisos` para tapar — un coste que cambia
-- en una fecha conocida, modelado como constante. Sólo que éste es 30 veces el de Movistar.
--
-- ── LOS 27 € QUE NO CUADRAN ─────────────────────────────────────────────────────
-- La hoja de trabajo opera con 1.641,80 de renta; el contrato dice 1.614,80 en letras, en números
-- y en la fianza (3.229,60 = 2 mensualidades). Parece una transposición de dígitos al pasar el
-- número a la planilla — el propio Stag anotó abajo "Diferencia €27,73". Si es así, Samavi lleva
-- ~10 meses pagando 27 €/mes de más (≈270 €). El aviso lo deja escrito para que se verifique con
-- Alberto antes de la renovación; no se corrige nada en el motor hasta confirmarlo.
--
-- ── LO QUE NO SE TOCA ───────────────────────────────────────────────────────────
-- `listings.renta_base` sigue en 1.414,22: es lo que se paga HOY y lo que hay que usar para los
-- meses ya devengados. Cambiarlo ahora falsearía enero–septiembre. Cuando llegue octubre, se
-- actualiza con el importe que se acuerde — que es justo lo que hay que negociar antes del 30/09.

insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '4B_ALEX', date '2026-10-01', 'renta',
       'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.641,80 €/mes',
       -308.93,
       'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste en el modelo: 1.677,65 -> 1.986,58 EUR/mes (+308,93/mes, +3.707/ano), que es el 94% del margen anual de Alexander. OJO: el contrato dice 1.614,80 de renta (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 = 2 mensualidades lo confirma) pero la hoja de trabajo uso 1.641,80: 27 EUR/mes de diferencia que hay que aclarar con Alberto. La palanca es la clausula 4.3, que permite renegociar la contraprestacion cada 12 meses.'
where not exists (
  select 1 from avisos a where a.codigo = '4B_ALEX' and a.fecha = date '2026-10-01' and a.tipo = 'renta');

-- Y el aviso de contrato decía lo que no es: el preaviso NO lo da Samavi.
-- Cláusula 2.2: es LA PROPIEDAD quien puede cortar la prórroga, dentro de los 30 días anteriores
-- al vencimiento (01–30/09/2026). Cláusulas 3.2 y 3.8: Samavi no puede desistir, y las dificultades
-- económicas no son causa mayor. La única puerta de Samavi es la 4.3, renegociar.
-- El detalle vive en este comentario, no en la alerta: se lee en el móvil.
update listings
   set aviso_nota = 'Vence el contrato. Solo Alberto puede cortar la prórroga; la palanca de Samavi es renegociar (cláusula 4.3)'
 where codigo = '4B_ALEX';
