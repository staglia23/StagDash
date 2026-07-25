-- 023_reimputacion_eventos_q1.sql — dos gastos estaban en la propiedad equivocada.
--
-- Hallazgos de la auditoría de Alexander Q1 (Stag, 25/07/2026). Ninguno cambia el resultado
-- consolidado de Samavi: es plata que estaba cargada en el sitio equivocado y distorsionaba
-- la rentabilidad por propiedad, que es justo el número con el que se decide lo de Alexander
-- antes del 01/09.
--
-- 1) TERMO DE 450 € (enero) — estaba en 4B_ALEX y es de 1A_NICA.
--    Confirmado por Stag: el termo de Alexander es el Ariston de Obramat de ABRIL (427,80 €
--    brutos − 44,74 € de IVA deducible = 383,06 € netos), que Alberto reembolsó íntegro en dos
--    plazos sobre la renta de mayo y junio (191,53 × 2 = 383,06 exacto sobre la base). El de
--    enero, de J.E. Cabrera, es el de Nicasio y es coste propio de Samavi.
--    Efecto: Alexander +450 € en enero, Nicasio −450 €.
--
-- 2) SEQURA 304,34 €/mes (enero–marzo) — estaba como overhead de empresa y es mobiliario
--    de 3G_MARE. Confirmado por Stag: las cuotas de Sequra financiaban el mobiliario de
--    Marechal y terminaron en marzo 2026. Como overhead se repartía entre las cuatro
--    propiedades; como coste directo va entero a Marechal, que es donde está el mueble.
--    (El mobiliario de Alexander es otro: Klarna-Sklum, 162,77 €/mes, ya bien imputado —
--    9 cuotas desde oct-2025 + 472,28 € de cancelación anticipada el 21/06/2026.)
--    Efecto: el pool de overhead baja 304,34 €/mes en Q1 y las cuatro pagan menos cuota;
--    Marechal absorbe los 913,02 € completos.
--
-- ⚑ NO se toca la compensación del termo de mayo (191,53) ni la de junio (199,19): están
--   pendientes de que Stag verifique en el extracto qué se transfirió exactamente en mayo
--   (1.222,69 € o 1.218,86 €). Ver la nota al pie de esta migración.

update events
   set propiedad_codigo = '1A_NICA',
       concepto = 'Termo eléctrico Nicasio (J.E. Cabrera)'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes = 1
   and categoria = 'OTROS' and concepto like 'Termo eléctrico (J.E. Cabrera)%';

update events
   set propiedad_codigo = '3G_MARE',
       categoria        = 'OTROS',
       concepto         = 'Mobiliario Marechal (Sequra, última cuota mar-2026)'
 where propiedad_codigo = 'SAMAVI_GEN' and anio = 2026 and mes in (1, 2, 3)
   and categoria = 'SAMAVI_GEN' and concepto = 'Sequra';

-- NOTA PARA EL CIERRE (no aplicada — pendiente de verificación bancaria):
-- La compensación del termo de Alexander se cargó como +191,53 (mayo) y +199,19 (junio), en
-- euros TRANSFERIDOS. La factura descuenta 191,53 sobre la BASE, y una base que baja 191,53
-- hace bajar la transferencia 191,53 × 1,02 = 195,36. O sea, los dos números solo pueden ser
-- correctos a la vez si en mayo se transfirieron 1.222,69 € (descontando el importe de base
-- del giro habitual) y no los 1.218,86 € del total de la factura. El mail del 18/05 apunta a
-- eso ("ajuste técnico de 3,83 € a tu favor… en Junio recibirás 1.215,03 €"), y 3,83 = 2 % de
-- 191,53. Si el extracto de mayo dice 1.218,86 € (el total de la factura), entonces mayo debe
-- pasar a +195,36 y queda un descuadre de 3,83 € por explicar. El total de los dos meses
-- (390,72 €) es correcto en cualquiera de los dos escenarios.
