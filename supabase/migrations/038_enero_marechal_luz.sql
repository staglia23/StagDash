-- 038_enero_marechal_luz.sql — el enero de Marechal deja de ser estimado (Stag, 25/07/2026).
--
-- ── QUÉ FALTABA Y POR QUÉ NO SE HABÍA VISTO ─────────────────────────────────────
-- La 034 dejó enero fuera para 3G_MARE y 4B_ALEX: "el tramo de enero es de la comercializadora
-- anterior". El de Marechal SÍ está en las carpetas de Confisic — son tres facturas de
-- Galápago/papernest (contrato 65221) que no se habían cruzado con el CUPS porque vienen a
-- nombre PERSONAL de Stag y no de la sociedad, así que no parecían del piso:
--
--   PPN 25000131309   02/12 – 08/12/2025    103,46 €   (fuera del ejercicio)
--   PPN 26000007553   09/12/2025 – 11/01    254,23 €   → 11 días de enero =   82,25 €
--   PPN 26000020088   12/01 – 04/02/2026    185,37 €   → 20 días de enero =  154,48 €
--                                                        ──────────────────────────
--                                                        enero completo      236,73 €
--
-- Cobertura verificada por CUPS y no por carpeta, igual que en la 034: 01–11 (7553) + 12–31
-- (20088) = mes entero sin huecos, así que enero es dato real y no un mes corto disfrazado.
-- Mismo prorrateo por día y mismo criterio de IVA incluido (peor caso) que 022, 031 y 034.
--
-- ── POR QUÉ ES EL 3º G Y NO EL 4º B ─────────────────────────────────────────────
-- Las tres facturas llevan CUPS ES0022000007651514DE1P / contador 040088848 — el mismo que la
-- factura de TotalEnergies 1NSN260200388415, cuya dirección de suministro dice "SEGOVIA 8, 3º,
-- G". El 4º B es otro contador: CUPS ES0022000007651519XG1P / 40088846, factura 1NSN260200415536.
-- El CUPS es el punto de suministro físico: no cambia aunque cambien titular ni comercializadora,
-- y es lo único que identifica el piso cuando el PDF viene a nombre de una persona. Confirmado
-- con Stag el 25/07/2026.
--
-- El salto contra febrero (236,73 vs 126,43) no es un error de imputación: papernest cobraba la
-- energía a 0,1679–0,1731 €/kWh y TotalEnergies la cobra a 0,1099 €/kWh, con el consumo de
-- invierno encima (27 kWh/día en dic–ene contra 22,6 kWh/día en febrero). El cambio de
-- comercializadora del 04/02/2026 vale ~40 % del recibo.
--
-- ── A NOMBRE PERSONAL, IMPUTADO A LA EMPRESA ────────────────────────────────────
-- Titular: Santiago Tagliaferri (NIF personal), domiciliado en cuenta personal. Decisión de Stag
-- el 25/07/2026: se imputa como coste de la sociedad igual, porque el consumo es del piso que
-- explota Samavi. Queda pendiente pedirle a papernest la refacturación a nombre de SAMAVI.
-- Mientras no ocurra, ese IVA no es recuperable ni en el mejor escenario fiscal — que es
-- exactamente el criterio de peor caso que el motor ya aplica, así que el importe no cambia
-- cuando Confisic conteste lo del régimen de IVA.
--
-- ── ENERO DE ALEXANDER SIGUE ABIERTO, A PROPÓSITO ───────────────────────────────
-- El 4º B no tiene ninguna factura de enero en Confisic: su alta en TotalEnergies es del
-- 05/02/2026 y la del comercializador anterior no está archivada. Se queda en el estimado de
-- 150,00 €/mes y la vista lo etiqueta sola (`fuente = 'estimado'`). No se carga un prorrateo
-- parcial: un mes incompleto no es un dato real, es un dato bajo — misma regla que la 034.

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '3G_MARE', 236.73, 30.00, 266.73, true,
   'Luz: papernest/Galapago contrato 65221 (PPN 26000007553 + PPN 26000020088), prorrateo por dia, IVA incluido. Facturas a nombre personal de Stag: refacturacion a SAMAVI pendiente. Internet: linea cara de Movistar (24,79 base -> 30,00 c/IVA).')
on conflict (anio, mes, codigo) do nothing;
