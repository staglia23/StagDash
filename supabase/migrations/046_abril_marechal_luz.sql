-- 046_abril_marechal_luz.sql — el último mes estimado del semestre (Stag, 26/07/2026).
--
-- ── LA FACTURA QUE FALTABA ──────────────────────────────────────────────────────
-- 1NSN260500255032 (CUPS ES0022000007651514DE1P = 3º G), período 12.04–11.05, 29 días, 46,98 €.
-- Estaba archivada en la carpeta de mayo de Confisic. Con ella abril queda cubierto:
--
--   1NSN260400331958  11.02–04.04  127,60 €  52 d → abril 1–3   =  3 d →  7,36 €
--   ── hueco de 8 días: 4 al 11 de abril ──────────────────────────────────────
--   1NSN260500255032  12.04–11.05   46,98 €  29 d → abril 12–30 = 19 d → 30,78 €
--                                                                        ───────
--                                                          luz de abril    38,14 €
--
-- Contra el estimado de 125,00 €/mes que había: abril de Marechal mejora 56,86 €.
--
-- ── EL HUECO ES REAL: TOTALENERGIES NO FACTURÓ ESOS 8 DÍAS ──────────────────────
-- No es que falte una factura, es que no existe. Se ve en las lecturas del contador 40088848:
--
--   1NSN260400331958 cierra el 04.04 en   punta 2.325 · llano 2.494 · valle 2.684
--   1NSN260500255032 arranca el 12.04 en  punta 2.341 · llano 2.502 · valle 2.739
--                                         ─────────────────────────────────────
--   sin facturar                          punta    16 · llano     8 · valle   55  = 79 kWh
--
-- Esos 79 kWh más 8 días de término de potencia son unos 15,60 € que el comercializador se
-- saltó. Decisión de Stag (26/07/2026): se asume así y se carga lo realmente facturado. Va con
-- `fiable = false` para que la vista lo etiquete `real_revisar`: si TotalEnergies regulariza en
-- algún ciclo posterior, ese cargo aparece y hay que acordarse de que corresponde a abril.
--
-- ── LA CONVENCIÓN DE DÍAS, YA VERIFICADA ────────────────────────────────────────
-- Reconstruida la serie completa de los tres pisos contra las facturas: TotalEnergies factura
-- con inicio INCLUSIVE y fin EXCLUSIVE ("11.02–11.03, 28 días" = del 11 de febrero al 10 de
-- marzo); papernest con ambos extremos inclusive. Con eso, 16 de los 17 meses-propiedad
-- cargados reproducen dentro de 0,16 € — mayo de Marechal sale exacto con esta misma factura
-- (46,98 × 10/29 + 66,49 × 21/31 = 61,24, que es lo cargado). El único que no reproduce es
-- FEBRERO de Marechal (96,43 cargado contra 95,42–103,15 reconstruido): es el único mes en que
-- un CUPS cambió de comercializadora a mitad de mes y el 4 de febrero aparece en las dos
-- facturas. La diferencia está entre 1 y 7 € y se deja como está.

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 4, '3G_MARE', 38.14, 30.00, 68.14, false,
   'Luz: 7,36 (1NSN260400331958, abril 1-3) + 30,78 (1NSN260500255032, abril 12-30), prorrateo por dia, IVA incluido. TotalEnergies NO facturo del 4 al 11 de abril: 79 kWh de diferencia entre las lecturas de cierre (04.04) y apertura (12.04) del contador 40088848, unos 15,60 EUR. Si lo regularizan mas adelante, corresponde a abril. Internet: linea cara de Movistar.')
on conflict (anio, mes, codigo) do nothing;
