-- 049_gastos_bolsillo_y_recobros.sql — la planilla manual de Stag contra el motor (26/07/2026).
--
-- Stag pasó el libro "STAG PROPERTIES MGMT - INGRESOS Y FINANZAS.xlsx", que es lo que llevaba a mano
-- antes del dashboard. Trae dos cosas que el motor no tenía y que se contradicen con él:
--
--   A) La CUENTA CORRIENTE de la dueña de JACO (hoja 2026_JACOBINE_MADRE_INGRESOS), con una columna GASTOS:
--      gastos que Samavi pagó y le DESCONTÓ del saldo. En 2026: febrero 77,00 "compra mini UPS +
--      instalación" y marzo 130,00 "aspiradora reposición".
--   B) Cuatro listas de GASTOS DE BOLSILLO 2026, una por piso ("jacobine 2026", "marechal 2026",
--      "nicasio 2026", "alexander 2026"), con fecha, importe y concepto de cada compra que hizo Stag.
--
-- ── 1) DOS GASTOS QUE SAMAVI YA SE COBRÓ Y QUE EL MOTOR CUENTA IGUAL (186,97 €) ─────
-- Los dos gastos de la columna GASTOS son de JACOBINE, y a la dueña ya se le descontaron. O sea que
-- para Samavi son NEUTROS: pagó y recuperó. Pero los dos están cargados como coste propio, y encima
-- en la propiedad equivocada — en Nicasio, porque el barrido bancario del 23/07 los leyó como
-- "compras de hogar de Madrid":
--
--   ASPIRADORA · marzo · 129,98 €
--     Revolut: "Www.amazon* Te5ke0el5" 129,98 del 28/02, liquidado el 01/03 (extracto de marzo).
--     Planilla de la dueña de JACO: marzo, GASTOS 130,00, nota "aspiradora reposición".
--     Hoy: dentro de 1A_NICA marzo "Compras hogar/reposición pisos (real bancos)" −162,33.
--
--   MINI UPS · febrero · 56,99 €
--     Revolut: "Amazon* 437or6gc5" 56,99 del 12/02, tarjeta Virtual.
--     Instalación: 20,00 € a Agustín, en efectivo — está en la lista de bolsillo de Jacobine como
--     "minu ups agustin" del 02/03, y NO pasó por el banco.
--     56,99 + 20,00 = 76,99, que es el 77,00 que le descontaron a la dueña en febrero (1 céntimo de
--     redondeo de Stag).
--     Hoy: dentro de 1A_NICA febrero "Compras hogar/reposición pisos (real bancos)" −226,05, en el
--     sumando "Amazon 75,80". El resto de ese Amazon (18,81) sí es de Nicasio: la propia lista de
--     Stag lo llama "Amazon Pasta de dientes".
--
-- Los dos salen enteros del P&L. Nicasio mejora 186,97 € en el semestre.
--
-- ── 2) UNA COPIA DE LLAVES QUE ESTABA EN EL PISO EQUIVOCADO (46,30 €) ───────────────
-- "Ferreteria Diego De Le" 46,30 del 17/02 está cargada en Nicasio como compra de hogar de Madrid.
-- La lista de bolsillo de Stag la tiene en la columna de JACOBINE: "19/02/2026 · 46,30 · copia de
-- llaves". Es coste real de Samavi (a la dueña no se le descontó: su febrero sólo lleva los 77,00
-- del UPS), pero es de Sevilla. Se reimputa: no cambia el consolidado, cambia la rentabilidad por
-- propiedad. Mismo criterio que las auditorías 023 y 042.
--
-- ── 3) LO QUE NUNCA PASÓ POR EL BANCO (301,22 €) ────────────────────────────────────
-- Ésta es la parte que el motor no podía ver: el dashboard se alimenta de extractos, y estos pagos
-- se hicieron en efectivo o por fuera. Están en las listas de Stag, uno por uno, con fecha:
--
--   3G_MARE  02/01  60,00   "cristales claudio"        ← Claudio es el portero de Segovia 8
--   3G_MARE  03/03  150,00  "arreglo bañera claudio"
--   1A_NICA  24/02  32,73   "NRUA registro"            ← Registro Único de Alojamiento
--   4B_ALEX  25/02  28,67   "NRUA registro"
--   1A_JACO  09/01  28,57   "amenities"
--   1A_JACO  05/02   4,50   "secadas enero"
--   1A_JACO  27/02   8,50   "secadas febrero"
--   1A_JACO  27/02  10,00   "amenities"
--   1A_JACO  27/02  30,65   "ILSA"                     ← menaje italiano, reposición del piso
--
-- Los 210 € de Claudio son el tercer pago en efectivo al portero que aparece tarde: los otros 80 €
-- salieron en la migración 044 y sólo porque estaban en un correo. Es un patrón, no un descuido
-- suelto: lo que se paga en efectivo no llega al motor salvo que alguien lo escriba.
--
-- Los 82,22 € de Jacobine van como un solo evento por mes ("gastos de bolsillo") para no chocar con
-- los eventos que sí salen del banco. Los amenities NO duplican la migración 048: aquélla cargó
-- sólo los cargos de DIA Sevilla del Revolut, y enero y febrero no tenían ninguno.
--
-- ── LO QUE NO SE TOCA, Y POR QUÉ ────────────────────────────────────────────────────
-- · Renfe 38,75 + Uber 8,96 + Uber 7,94 + Cabify 6,96 = 62,61 €. Stag los tenía imputados a
--   Jacobine (son los viajes a Sevilla), pero la regla vigente desde el 21/07 manda el transporte a
--   la línea de "Viajes corporativos" del overhead, 200 €/mes. Cambiar eso es cambiar una regla, no
--   corregir un dato. Queda como pregunta.
-- · Uber Eats 16,74 y Mina Coffee 16,60: la lista de Stag los pone en Nicasio; el dashboard los tiene
--   en SAMAVI_GEN como comidas de negocio. Misma situación: es criterio ya decidido el 23/07.
-- · "secadas diciembre" 9,00 € (pagado el 09/01): el devengo es de diciembre de 2025 y el motor está
--   fijado al año en curso. Se pierde. No hay dónde ponerlo sin mentir.
-- · Todo 2025 de la cuenta corriente de la dueña de JACO (cortinas SOOFA 2.044, reparaciones 83, gastos de
--   diciembre 409,14, arranque 272,25): fuera del alcance del dashboard, y además ya recuperado de
--   la dueña. Vive en el proyecto de Admin & Fiscal.

-- 1) El mini UPS y la copia de llaves salen de las compras de hogar de Nicasio de febrero.
--    Quedan los 18,81 de la pasta de dientes + Ideal Home 20,45 + flores 83,50 = 122,76.
update events
   set importe = -122.76,
       notas   = 'Amazon 18,81 (pasta de dientes, 15/02) + Ideal Home 20,45 + Mon Parnasse flores 83,50. Salieron dos cosas que no eran de Nicasio: los 56,99 del Amazon del 12/02 eran el mini UPS de JACOBINE (56,99 + 20,00 de instalacion de Agustin = 77,00 que se le descontaron a la duena en su cuenta corriente, o sea coste neutro para Samavi), y los 46,30 de Ferreteria Diego de Leon eran la copia de llaves de JACOBINE segun la lista de gastos de bolsillo de Stag. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 2
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -226.05;

-- 2) La aspiradora sale de las compras de hogar de Nicasio de marzo.
--    Quedan los dos Día de Madrid: 21,64 + 10,71 = 32,35.
update events
   set importe = -32.35,
       notas   = 'Dia Madrid 21,64 + Dia Madrid 10,71. Los 129,98 del Amazon del 28/02 (liquidado el 01/03) eran la ASPIRADORA de JACOBINE: figura en la cuenta corriente de la duena como GASTOS 130,00 de marzo con la nota "aspiradora reposicion", o sea que Samavi ya se la cobro. Coste neutro: sale del P&L. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 3
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -162.33;

-- 3) La copia de llaves entra en Jacobine, que es donde se usó.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, '1A_JACO', 'OTROS', 'Copia de llaves (Ferretería Diego de León)', -46.30,
       'Cargo de 46,30 del 17/02 en el Revolut, tarjeta Metal. Estaba imputado a Nicasio por el barrido bancario del 23/07 (ferreteria de Madrid = compra de hogar de Madrid); la lista de gastos de bolsillo de Stag lo tiene en la columna de JACOBINE, "19/02/2026 copia de llaves". No se le descontó a la duena.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Copia de llaves (Ferretería Diego de León)');

-- 4) Lo pagado en efectivo, que nunca pasó por el banco.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, 'OTROS', v.concepto, v.importe, v.notas
from (values
  (2026, 1, '3G_MARE', 'Cristales (Claudio, efectivo)', -60.00,
   'Lista de gastos de bolsillo de Stag, "02/01/2026 cristales claudio". Claudio es el portero de Segovia 8. Pagado en efectivo, no pasa por el extracto: por eso el motor no lo veia. Tercer pago en efectivo a Claudio que aparece tarde (los otros 80,00 entraron por la migracion 044).'),
  (2026, 3, '3G_MARE', 'Arreglo de bañera (Claudio, efectivo)', -150.00,
   'Lista de gastos de bolsillo de Stag, "03/03/2026 arreglo banera claudio". Pagado en efectivo, sin factura, fuera del extracto.'),
  (2026, 2, '1A_NICA', 'NRUA — registro único de alojamiento', -32.73,
   'Lista de gastos de bolsillo de Stag, "24/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 2, '4B_ALEX', 'NRUA — registro único de alojamiento', -28.67,
   'Lista de gastos de bolsillo de Stag, "25/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 1, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -28.57,
   'Lista de gastos de bolsillo de Stag: "09/01/2026 amenities 28,57". Fuera del extracto. NO duplica la migracion 048, que solo cargo los cargos de DIA Sevilla del Revolut y enero no tenia ninguno. En la misma fecha hay 9,00 de "secadas diciembre" que NO se cargan: el devengo es de diciembre de 2025 y el motor esta fijado al ano en curso.'),
  (2026, 2, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -53.65,
   'Lista de gastos de bolsillo de Stag: ILSA 30,65 (menaje, 27/02) + amenities 10,00 (27/02) + secadas 8,50 (27/02) + secadas de enero 4,50 (pagadas el 05/02). Ninguno pasa por el extracto. La secada de 4,50 del 27/02 SI esta en el banco y ya estaba cargada aparte, no se repite aca.')
) as v(anio, mes, cod, concepto, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = v.cod
     and e.concepto = v.concepto);
