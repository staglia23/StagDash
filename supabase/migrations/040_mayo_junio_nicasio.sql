-- 040_mayo_junio_nicasio.sql — cierra el último hueco de suministros del semestre (Stag, 25/07/2026).
--
-- ── POR QUÉ ESTABA ABIERTO ──────────────────────────────────────────────────────
-- La 034 lo dejó anotado: "NICA no tiene NINGUNA factura desde el 11.05 (dos ciclos del piso
-- más caro)". Era cierto ese día: el contrato dual de Nicasio facturaba cada DOS meses, así
-- que el ciclo 11.05–11.07 todavía no se había emitido. Ya se emitió.
--
-- ── EL CONTRATO SE PARTIÓ EN DOS ────────────────────────────────────────────────
-- TotalEnergies desdualizó el contrato en julio: "si tienes contratadas varias energías, a
-- partir de ahora recibirás tus facturas de luz y de gas por separado. La factura de luz la
-- recibirás una vez al mes y la de gas, cada dos meses". O sea que el ciclo bimensual de
-- Nicasio ya no existe y desde julio entra una factura de luz por mes, como ALEX y MARE.
-- Consecuencia práctica: a partir del cierre de agosto, Nicasio se lee igual que los otros dos.
--
-- ── LAS PIEZAS ──────────────────────────────────────────────────────────────────
-- CUPS luz ES0022000007651492DT1P · CUPS gas ES0217020096053489XQ · "SEGOVIA 8, 1º, A"
--
--   luz  11.03–11.05  153,09 €  1NSN260500251449 (PDF en Confisic)
--   luz  12.05–11.06   95,15 €  aviso TotalEnergies del 18/07/2026
--   luz  12.06–12.07  130,05 €  aviso TotalEnergies del 20/07/2026
--   gas  11.03–08.05   13,83 €  1NSN260500251449 (PDF en Confisic)
--   gas  09.05–09.07   16,99 €  aviso TotalEnergies del 15/07/2026
--
-- Sin huecos: los cortes 11.05/12.05 y 11.06/12.06 son la fecha de lectura del contador, no
-- días sin facturar. Mayo y junio quedan con cobertura completa de luz Y de gas.
--
--   mayo  luz  153,09×11/61 + 95,15×20/31 =  27,61 + 61,39 =  89,00
--         gas   13,83× 8/59 + 16,99×22/61 =   1,88 +  6,13 =   8,01
--                                                            ───────
--                                                              97,01 €
--   junio luz   95,15×11/31 + 130,05×19/31 =  33,76 + 79,71 = 113,47
--         gas   16,99×30/61                              =            8,36
--                                                            ───────
--                                                             121,83 €
--
-- Contra el estimado de 150,00 €/mes que había: mayo mejora 52,99 € y junio 28,17 €.
-- Nicasio no lleva internet en esta tabla — su fibra es la de Orange y ya está en el overhead
-- (028), así que `internet_eur = 0` como en enero–abril.
--
-- ── DE DÓNDE SALEN LOS TRES IMPORTES NUEVOS ─────────────────────────────────────
-- De los avisos de facturación de TotalEnergies, que traen dirección de suministro, período de
-- consumo e importe con IVA incluido — los tres datos que necesita el motor. Los PDF todavía
-- no están archivados en la carpeta de julio de Confisic. Van como `fiable = true` porque el
-- importe es el definitivo del emisor, no una estimación; cuando los PDF se archiven conviene
-- cotejar base+IVA, que es el control que se le hizo a las otras 31 facturas.
--
-- ── UN HALLAZGO QUE NO TOCA ESTA MIGRACIÓN PERO HAY QUE MIRAR ───────────────────
-- La factura de mayo de Nicasio lleva IVA al 10 % y el impuesto eléctrico al 0,5 %. Las de
-- Alexander y Marechal, mismo edificio y mismo comercializador, llevan IVA al 21 % e impuesto
-- eléctrico al 5,11 %. O Nicasio está en un régimen reducido que los otros dos podrían pedir,
-- o hay un error de facturación en alguno de los tres. No se toca acá porque el motor imputa
-- el total de la factura (peor caso, IVA incluido) y ese total es correcto en los tres casos.

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 5, '1A_NICA',  97.01, 0.00,  97.01, true,
   'Luz 89,00 (11.03-11.05 1NSN260500251449 + 12.05-11.06 aviso 18/07) + gas 8,01 (11.03-08.05 + 09.05-09.07 aviso 15/07). Prorrateo por dia, IVA incluido. PDF de julio pendiente de archivar en Confisic.'),
  (2026, 6, '1A_NICA', 121.83, 0.00, 121.83, true,
   'Luz 113,47 (12.05-11.06 aviso 18/07 + 12.06-12.07 aviso 20/07) + gas 8,36 (09.05-09.07 aviso 15/07). Prorrateo por dia, IVA incluido. PDF de julio pendiente de archivar en Confisic.')
on conflict (anio, mes, codigo) do nothing;
