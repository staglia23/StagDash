-- 048_amenities_reales_jacobine.sql — la última línea estimada del semestre (Stag, 26/07/2026).
--
-- Jacobine era la única propiedad que todavía llevaba amenities como PROVISIÓN fija: 34,58 €/mes
-- en `listings.amenities`, heredados del modelo pre-auditoría. A las otras tres la migración 031
-- les puso el dato real de la factura de Ecocleans y les dejó la línea en cero; Jacobine se quedó
-- fuera porque no la limpia Ecocleans sino José Modesto, que compra y repone los amenities él
-- mismo con la tarjeta Revolut Standard (…3814).
--
-- Relevamiento de los seis extractos de Revolut ene–jun 2026 (carpetas de Confisic en Drive),
-- filtrando las compras de consumibles en Sevilla — DIA Sevilla 2271 y Mp**dia 22144, en las dos
-- tarjetas, con la convención de siempre: cada cargo al mes del extracto donde aparece:
--
--   ene  —                                                                              0,00
--   feb  —                                                                              0,00
--   mar  02/03 Dia Sevilla 2271 45,94 · 10/03 Mp**dia 5,54 · 28/03 Mp**dia 16,05       67,53
--   abr  12/04 Mp**dia 10,19 · 20/04 Dia Sevilla 2271 18,73                            28,92
--   may  01/05 Mp**dia 4,54 · 11/05 Dia Sevilla 2271 30,28                             34,82
--   jun  31/05 Dia Sevilla 9,68 + 5,79 · 25/06 Dia Sevilla 28,70                       44,17
--                                                                                    ───────
--                                                                                     175,44
--
-- Contra 207,48 € de provisión (34,58 × 6). El total sobra por 32,04 €, pero el mes a mes estaba
-- muy mal: enero y febrero no tuvieron NI UNA compra de amenities y cargaban 34,58 cada uno,
-- mientras marzo gastó casi el doble de lo provisionado.
--
-- ⚑ Y febrero contaba dos veces. La compra real de amenities de ese mes (Natura Sevilla Sierpes,
--   33,80 €, tarjeta Metal) ya estaba cargada como evento desde el barrido del 23/07. Con la
--   provisión encima, febrero soportaba 68,38 € de amenities habiendo gastado 33,80. El evento
--   de Natura se queda —es gasto real—; lo que sale es la provisión.
--
-- Se aplica el mismo criterio que 031 (limpieza) y 034 (suministros): la provisión fija se va a
-- cero y el gasto entra como evento mensual real. A partir de julio, los amenities de Jacobine se
-- cargan en cada cierre desde el extracto, como los de las otras tres.
--
-- Efecto: la contribución del semestre de Jacobine sube 32,04 € (9.777,06 → 9.809,10). Enero pasa
-- de +32,63 a +67,21 de margen neto y febrero de +50,16 a +84,74 — sigue siendo el mismo titular,
-- que en temporada baja Jacobine paga su gestión y nada más.
--
-- NO se toca la lavandería (My Laundry, secadas de ropa de cama que hace José): la serie ene–jun
-- ya estaba cargada y el relevamiento la confirma al céntimo mes a mes, incluido enero sin cargos.
-- Toallas y ropa de cama las asume Samavi pero son de 2025 y de julio → cierre de julio.

-- 1) La provisión fija se va a cero, como en las otras tres.
update listings set amenities = 0 where codigo = '1A_JACO';

-- 2) El gasto real entra mes a mes. Marzo, abril, mayo y junio; enero y febrero no tuvieron.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, '1A_JACO', 'OTROS', 'Amenities/consumibles Sevilla (DIA, real)', v.importe, v.notas
from (values
  (2026, 3, -67.53, 'Dia Sevilla 2271 45,94 del 02/03 (tarjeta Metal) + Mp**dia 22144 5,54 del 10/03 y 16,05 del 28/03 (tarjeta Standard de Jose Modesto). Extracto Revolut marzo 2026.'),
  (2026, 4, -28.92, 'Mp**dia 22144 10,19 del 12/04 + Dia Sevilla 2271 18,73 del 20/04, tarjeta Standard de Jose Modesto. Extracto Revolut abril 2026.'),
  (2026, 5, -34.82, 'Mp**dia 22144 4,54 del 01/05 + Dia Sevilla 2271 30,28 del 11/05, tarjeta Standard de Jose Modesto. Extracto Revolut mayo 2026.'),
  (2026, 6, -44.17, 'Dia Sevilla 2271 9,68 y 5,79 del 31/05 + 28,70 del 25/06, tarjeta Standard de Jose Modesto. Extracto Revolut junio 2026 (los cargos del 31/05 aparecen en el extracto de junio).')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Amenities/consumibles Sevilla (DIA, real)');

-- 3) La compra de febrero ya estaba cargada; queda claro que ES el amenities del mes, no un extra.
update events
   set notas = 'Natura Sevilla Sierpes 33,80 del 27/02, tarjeta Metal. Confirmado Stag 23/07. Es el UNICO gasto de amenities de febrero: hasta la migracion 048 convivia con la provision fija de 34,58, o sea que el mes contaba 68,38 habiendo gastado 33,80.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Amenities Natura Sevilla Sierpes';
