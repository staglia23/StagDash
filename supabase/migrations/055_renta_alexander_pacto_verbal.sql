-- 055_renta_alexander_pacto_verbal.sql — la renta de octubre según el pacto real (Stag, 27/07/2026).
--
-- ── QUÉ SE ACLARÓ ───────────────────────────────────────────────────────────────
-- Stag confirmó el pacto VERBAL con Alberto: lo acordado es que Alberto RECIBE EN CUENTA
-- 1.614,80 €/mes. Eso es un importe de TRANSFERENCIA, no de base imponible:
--
--   base = 1.614,80 / 1,02 = 1.583,14
--   1.583,14 + IVA 332,46 − retención 300,80 = 1.614,80  ✓
--
-- Las tres lecturas que conviven en los papeles, y lo que cuesta cada una desde octubre
-- (coste modelado = base × 1,21, peor caso de IVA no deducible):
--
--   verbal (Stag)      base 1.583,14 → recibe 1.614,80 → coste 1.915,60   +237,95/mes
--   contrato (4.1)     base 1.614,80 → recibe 1.647,10 → coste 1.953,91   +276,26/mes
--   planilla (typo)    base 1.641,80 → recibe 1.674,64 → coste 1.986,58   +308,93/mes
--
-- La 022 modeló la lectura del contrato (events de −232,88 en transferencia); la 053/054
-- discutieron entre el contrato y la planilla. Esta migración pasa el motor a la lectura VERBAL
-- por instrucción de Stag (27/07/2026): transferencia 1.614,80 → delta 200,58/mes.
--
-- ⚠️ ESTO ROMPE EL CRITERIO DE PEOR CASO DEL REPO, a sabiendas. Hasta que la adenda fije la
--   cifra por escrito (cláusula 8.2: sólo valen modificaciones firmadas), Alberto podría
--   facturar legítimamente 1.647,10 (contrato) o seguir la planilla con 1.674,64. La adenda de
--   octubre tiene que decir "transferencia 1.614,80, base 1.583,14, IVA 21 %, retención 19 %" —
--   mismo formato que el contrato de Marechal ("1.100 neto al propietario"). Vale 460–852 €/año.
--
-- ── Y EL DESCUENTO SE APLICÓ SOBRE EL NÚMERO EQUIVOCADO ─────────────────────────
-- El método del prorrateo (descontar 255,31 de la base) fue correcto y fiscalmente el más
-- eficiente: cada euro menos de base ahorra 1,21 de coste, y evitó refacturarle el amoblamiento
-- a Alberto con IVA. Pero se partió de 1.641,80 como si fuera base, cuando el pacto era de
-- transferencia: la base "completa" era 1.583,14 y la facturada debió ser 1.327,83 (transferencia
-- 1.354,39). Se pagó 1.414,22: ~59,83/mes de más, ≈598 € en 10 meses. Queda anotado en el aviso
-- para decidir en la adenda si se compensa; no se toca el histórico (es lo realmente pagado).

-- 1) Los events del Q4 pasan a la transferencia pactada: 1.614,80 − 1.414,22 = 200,58.
update events
   set importe = -200.58,
       notas   = 'Fin del prorrateo del amoblamiento: la transferencia pasa de 1.414,22 a 1.614,80 (pacto VERBAL confirmado por Stag el 27/07/2026: Alberto recibe 1.614,80 en cuenta; base derivada 1.583,14). La 022 habia cargado -232,88 con la lectura literal del contrato (base 1.614,80, transferencia 1.647,10). PENDIENTE la adenda que fije la cifra por escrito: sin ella el contrato permite a Alberto facturar 1.647,10.'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes in (10, 11, 12)
   and categoria = 'RENTA'
   and concepto = 'Renta sube Q4 (fin prorrateo mobiliario) — en transferencia'
   and importe = -232.88;

-- 2) El aviso cuenta la misma historia con el mismo número.
update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: Alberto pasa a recibir 1.614,80 €/mes (base 1.583,14)',
       impacto_mes = -237.95,
       nota = 'Pacto VERBAL (Stag, 27/07/2026): Alberto recibe 1.614,80 en cuenta -> base 1.583,14. Coste modelado 1.677,65 -> 1.915,60 (+237,95/mes, +2.855/ano, ~73% del margen anual del piso). Modela la lectura MAS FAVORABLE por instruccion de Stag, rompiendo el criterio de peor caso: el contrato literal daria coste 1.953,91 (+38,31/mes mas) y la planilla 1.986,58 (+70,98/mes mas). La adenda de octubre (clausulas 4.3 y 8.2) debe fijar por escrito "transferencia 1.614,80, base 1.583,14, IVA 21%, retencion 19%", formato del contrato de Marechal. Ademas, bajo el pacto verbal el descuento del prorrateo se aplico sobre base equivocada (1.641,80 en vez de 1.583,14): se transfirieron ~59,83/mes de mas desde oct-2025, ~598 en 10 meses — decidir en la adenda si se compensa. El P&L de oct-dic ya cuenta la subida via events (-200,58). En enero de 2027 actualizar listings.renta_base.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';
