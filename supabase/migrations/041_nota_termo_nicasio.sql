-- 041_nota_termo_nicasio.sql — la nota del termo decía lo contrario del dato (Stag, 25/07/2026).
--
-- El evento de enero de 1A_NICA "Termo eléctrico Nicasio (J.E. Cabrera)" (−450 €) arrastraba la
-- nota de cuando estaba imputado a Alexander: "confirmado Stag 17/07: es de Alexander". La 023
-- lo movió a propósito de 4B_ALEX a 1A_NICA — Stag confirmó que el termo de Alexander es el
-- Ariston de Obramat de ABRIL (383,06 € netos, reembolsado por Alberto en dos plazos sobre la
-- renta de mayo y junio) y que el de enero, de J.E. Cabrera, es el de Nicasio y coste propio de
-- Samavi. Lo que la 023 no hizo fue actualizar el campo `notas`.
--
-- El importe y la propiedad están bien. Solo se corrige el texto, que en la auditoría de
-- Nicasio del 25/07 hizo perder tiempo persiguiendo una misimputación que no existía.

update events
   set notas = 'confirmado Stag 17/07: ES DE NICASIO y es coste propio de Samavi. Reimputado desde 4B_ALEX por la migracion 023. Distinto del Ariston/Obramat de abril (383,06), que si es de Alexander y lo reembolso Alberto.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 1
   and categoria = 'OTROS' and concepto = 'Termo eléctrico Nicasio (J.E. Cabrera)'
   and notas like '%es de Alexander%';
