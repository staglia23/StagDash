-- 052_tgss_verificada.sql — la nómina de José, contra el BBVA (Stag, 26/07/2026).
--
-- El modelo daba por bueno que Samavi gana 11,67 €/mes con la limpieza de Jacobine: cobra 700 a la
-- dueña y paga 688,33 (484,00 de sueldo + 204,33 de TGSS). El sueldo estaba verificado contra el
-- Revolut todos los meses, pero **el TGSS no aparecía en ningún extracto de Revolut**: era el número
-- más grande de Jacobine que descansaba sólo en una suposición, y si estaba mal, estaba mal los doce
-- meses y daba vuelta el signo.
--
-- Stag indicó que se paga desde el BBVA. Verificado en los seis extractos, uno por uno:
--
--   30/01  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,33
--   27/02  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,86
--   31/03  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,86
--   30/04  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,86
--   29/05  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,86
--   30/06  TGSS. COTIZACION 001 REGIMEN GENERAL   −204,86
--
-- **El modelo era correcto.** El régimen general es el de José (el 005 R.E.AUTÓNOMOS de 370,75 que
-- va al lado es el RETA de Stag, ya modelado aparte en general_expenses). La refactura de limpieza
-- de Jacobine no pierde plata: gana, poco pero gana.
--
-- Lo único que se corrige es que la cuota subió a 204,86 en febrero y se quedó ahí, y que la nómina
-- de enero fueron 484,44 y no 484,00. Devengo mes a mes:
--
--   enero      484,44 + 204,33 = 688,77   →  700 − 688,77 = +11,23
--   feb–dic    484,00 + 204,86 = 688,86   →  700 − 688,86 = +11,14
--
-- Son 3,09 € en el semestre. Irrelevante para cualquier decisión — pero ahora el número está
-- verificado contra banco en vez de supuesto, que es la diferencia que importa.
--
-- ── Y UNA MARCA QUE PUSE MAL ────────────────────────────────────────────────────────
-- La migración 051 marcó los dos NRUA con "⚑ FUENTE: solo la planilla manual, sin respaldo bancario".
-- Es falso: están en el BBVA, por eso no los encontré en el Revolut.
--
--   24/02  TRANSFERENCIAS · "F4 510 - NRUA"     −32,73   → Nicasio
--   26/02  TRANSFERENCIAS · "F4 - 7784 - NRUA"  −28,67   → Alexander
--
-- Importes exactos y fechas que cuadran con la planilla. Se les quita la marca.
-- Los de Claudio (60,00 y 150,00) y los amenities de Jacobine (28,57 y 10,00) NO están en el BBVA:
-- ésos sí siguen apoyados sólo en la planilla, y mantienen su ⚑.

update events
   set importe = 11.23,
       notas   = 'Nomina de enero 484,44 (pagada el 02/02 desde Revolut) + TGSS regimen general 204,33 (cargada el 30/01 en el BBVA) = 688,77, contra los 700 que se le descuentan a la duena. VERIFICADO contra banco el 26/07/2026, ya no es una suposicion.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 1
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set importe = 11.14,
       notas   = 'Nomina 484,00 + TGSS regimen general 204,86 = 688,86, contra los 700 que se le descuentan a la duena. La cuota de TGSS subio de 204,33 a 204,86 en febrero y se mantuvo; verificada cargo por cargo en los extractos del BBVA (27/02, 31/03, 30/04, 29/05, 30/06). El cargo de 370,75 que aparece al lado es el RETA de Stag, no el de Jose. VERIFICADO contra banco el 26/07/2026.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes >= 2
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set notas = replace(notas,
        ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.',
        ' ⚑ CORREGIDO 26/07: si tiene respaldo bancario, esta en el BBVA (no en el Revolut, por eso no aparecia): transferencia del 24/02 "F4 510 - NRUA" 32,73 para Nicasio y del 26/02 "F4 - 7784 - NRUA" 28,67 para Alexander.')
 where anio = 2026 and concepto = 'NRUA — registro único de alojamiento';
