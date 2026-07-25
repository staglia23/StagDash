-- 042_auditoria_nicasio.sql — dos correcciones de la auditoría de Nicasio (Stag, 26/07/2026).
--
-- Mismo criterio que la auditoría de Alexander (023): ninguna de las dos cambia el resultado
-- consolidado de Samavi por el mismo importe — es plata que estaba en el sitio equivocado y
-- distorsionaba la rentabilidad por propiedad. Nicasio mejora 1.177,47 € en el semestre.
--
-- ── 1) EL IRPF PERSONAL NO ES GASTO DE LA EMPRESA (1.031,67 €) ──────────────────
-- El evento de abril "IBI/tributos NRC + Ayuntamiento" (−1.141,60 €) eran dos cosas distintas
-- metidas en una:
--
--   109,93 €   cuota 02 del fraccionamiento del IBI 2025 (FRA/2025/01001446325, 06/04/26)
--   1.031,67 € IRPF PERSONAL de Stag, pagado por error desde la cuenta de la sociedad
--
-- Verificado el 26/07/2026 contra los dos planes de pago de la Carpeta Tributaria de Madrid:
-- los 109,93 son exactamente la cuota 02 del fraccionamiento; los 1.031,67 no están en ninguno
-- de los dos planes municipales, y la referencia NRC es de la AEAT, no del Ayuntamiento.
-- Confirmado por Stag: Confisic lo cargó a la cuenta de empresa cuando debía salir de la
-- personal.
--
-- El IRPF del socio no es gasto deducible, ni coste operativo, ni coste de Nicasio: es un
-- derecho de cobro de la sociedad contra el socio. Sale del P&L entero. Decisión de Stag
-- (26/07/2026): queda como saldo a compensar en cuenta con el socio; la regularización la
-- lleva Confisic y vive en el proyecto de Admin & Fiscal, no en este repo.
--
-- ⚑ El dashboard NO modela la cuenta con el socio. Que este importe desaparezca del P&L es
--   correcto contablemente, pero significa que hay 1.031,67 € de caja que salieron y no se ven
--   en ninguna pantalla. Es la contrapartida de tratarlo bien.
--
-- ── 2) LOS AURICULARES DE OFICINA NO SON DE NICASIO (145,80 €) ──────────────────
-- El cargo de "Amazon 731,00 €" de junio no era un pedido: eran DIEZ pedidos menos un
-- reembolso, leídos uno a uno del extracto de Revolut de la sociedad:
--
--   11/06 Nl0j47u04    62,22     15/06 Vu0am3um5    18,99
--   12/06 Nr9op7co4   119,43     15/06 Qv7m74vr5     8,21
--   12/06 Nr6416en4    26,50     21/06 I04yh1kb5    25,80
--   13/06 Nr99h4xf4   301,77     23/06 Amazon.es   145,80  ← MCC 5732 (electrónica)
--   14/06 Nr6r47eu4    19,40     24/06 reembolso   −10,29
--   14/06 Nr2xu5ej4    13,17                       ───────
--                                                   731,00
--
-- El de 145,80 € (MCC 5732, electrónica) es el plazo 1 de 3 de unos auriculares de oficina:
-- herramienta de trabajo, no reposición de piso. Confirmado por Stag el 26/07/2026. Va al
-- overhead operativo (`SAMAVI_GEN`, no `CORPORATIVO`), mismo criterio que los dispositivos de
-- Orange en la 036: se prorratea entre las cuatro por días bajo gestión.
--
-- ⚑ PENDIENTE DE LOS CIERRES DE JULIO Y AGOSTO: faltan los plazos 2/3 y 3/3, 145,80 € cada uno
--   (total 437,40 €). Cuando aparezcan en el extracto van acá, NO a compras de hogar.
--
-- ── LO QUE NO SE TOCA ───────────────────────────────────────────────────────────
-- · La derrama de obras IEE 2020 (149,83 €/mes dentro de los 331,12 de comunidad) sigue como
--   línea perpetua por decisión de Stag hasta que Susana Fernández Robleda confirme la fecha
--   de la última cuota. Es un coste finito modelado como infinito: infla el punto de
--   equilibrio y el margen asegurado de Nicasio en 1.797,96 €/año hasta que se corrija.
-- · La derrama del forjado (765 + 382,50 + 382,50 = 1.530 €) está bien: Stag confirmó que
--   fueron tres pagos de dos recibos distintos, no un doble conteo.
-- · El resto de las compras de hogar sigue íntegro en Nicasio, que es la regla vigente desde
--   el 21/07/2026.

-- 1) El IRPF sale del P&L. Queda solo la cuota real del IBI.
update events
   set importe  = -109.93,
       concepto = 'IBI plazo (fraccionamiento 2025, cuota 02)',
       notas    = 'FRA/2025/01001446325 cuota 02 del 06/04/26, verificado contra la Carpeta Tributaria. Los 1.031,67 que estaban acá eran IRPF personal de Stag pagado por error desde la cuenta de empresa: no es gasto de la sociedad, queda a compensar en cuenta con el socio (regularizacion via Confisic).'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 4
   and categoria = 'OTROS' and concepto = 'IBI/tributos NRC + Ayuntamiento'
   and importe = -1141.60;

-- 2) Los auriculares salen de las compras de hogar de Nicasio.
update events
   set importe = -667.35,
       notas   = 'Amazon 585,20 (10 pedidos - 1 reembolso, sin los 145,80 de los auriculares de oficina) + Dia Madrid 39,71 + Ideal Home 15,95 + Bricochayta 16,50 + Hiperhogar 9,99'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 6
   and categoria = 'OTROS' and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -813.15;

-- 3) ...y entran al overhead operativo, que se reparte entre las cuatro.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Auriculares oficina (Amazon, plazo 1/3)', -145.80,
       'Amazon.es 23/06 MCC 5732. Herramienta de trabajo, no reposicion de piso; confirmado Stag 26/07. Faltan los plazos 2/3 y 3/3 (145,80 c/u) en los cierres de julio y agosto.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 6 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Auriculares oficina (Amazon, plazo 1/3)');
