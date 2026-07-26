-- 054_fix_aviso_renta_alexander.sql — la 053 se equivocó en dos cosas (27/07/2026).
--
-- ── 1) EL MOTOR SÍ LO SABÍA ─────────────────────────────────────────────────────
-- La 053 dice que "el motor no lo sabía". Falso: la **migración 022** ya lo había resuelto, en su
-- sección "Fix de la renta Q4 de Alexander". Están cargados los events 92, 8 y 9 —
-- "Renta sube Q4 (fin prorrateo mobiliario) — en transferencia", −232,88 en octubre, noviembre y
-- diciembre— y el P&L de esos meses ya los cuenta.
--
-- Lo que la 053 sí aporta es la capa de AVISO: los events modelan el coste, pero no gritan. Ése es
-- exactamente el reparto que abrió la migración 045 ("un cambio que sube el coste no se puede
-- modelar con una fecha de fin: hay que verlo venir con tiempo para poder renegociar"). Las dos
-- capas conviven sin doble conteo, porque `avisos` sólo alimenta `v_alertas`, nunca el P&L.
--
-- ── 2) Y EL IMPORTE ESTABA MAL ──────────────────────────────────────────────────
-- La 053 usó 1.641,80 de renta, que es el número de la hoja de trabajo de Stag. El contrato dice
-- **1.614,80** y lo dice tres veces: en letras, en números y en la fianza (3.229,60 = 2
-- mensualidades). La 022 ya había elegido bien — sus 232,88 salen exactamente de ahí:
--
--   transferencia hoy      1.386,49 × 1,02 = 1.414,22
--   transferencia oct      1.614,80 × 1,02 = 1.647,10      → +232,88  (lo que cargan los events)
--   coste modelado hoy     1.386,49 × 1,21 = 1.677,65
--   coste modelado oct     1.614,80 × 1,21 = 1.953,91      → **+276,26/mes = +3.315/año**
--
-- El aviso llevaba +308,93, que sale de los 1.641,80. Se corrige a 276,26, que es el salto real en
-- términos de coste — la unidad en la que el dashboard mide todo lo demás.
--
-- Sigue en pie el fondo: son 3.315 €/año contra un margen anual de Alexander de ≈3.929 €. El 84 %,
-- no el 94 %. La conclusión no cambia; la cifra sí, y va en un mail a Alberto.
--
-- ⚑ LOS 27 € SIGUEN ABIERTOS. Si Alberto factura 1.641,80 desde octubre en vez de 1.614,80, el
--   salto es de 308,93 y no de 276,26. Hay que confirmarlo con él antes de renovar — y de paso
--   aclarar si los ~27 €/mes de más que se vienen pagando desde octubre de 2025 (unos 270 €) son
--   un error de la planilla o algo pactado que no está en el contrato.
--
-- ⚑ Y OJO CON ENERO DE 2027: los events de la 022 sólo cubren octubre, noviembre y diciembre.
--   Cuando el año ruede, `listings.renta_base` (hoy 1.414,22, en términos de transferencia) tiene
--   que pasar a la que se acuerde. Si no, 2027 arranca con la renta vieja.

update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.614,80 €/mes',
       impacto_mes = -276.26,
       nota = 'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste modelado: 1.677,65 -> 1.953,91 EUR/mes (+276,26/mes, +3.315/ano), un 84% del margen anual del piso. El P&L de oct-dic YA lo cuenta desde la migracion 022 (events 92/8/9, -232,88 en terminos de transferencia); este aviso es solo la capa de alerta. PENDIENTE: el contrato dice 1.614,80 (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 lo confirma) pero la hoja de trabajo uso 1.641,80. Si Alberto factura 1.641,80, el salto es 308,93. Confirmarlo antes de renovar. La palanca es la clausula 4.3. Y en enero de 2027 hay que actualizar listings.renta_base: los events de la 022 solo llegan a diciembre.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';
