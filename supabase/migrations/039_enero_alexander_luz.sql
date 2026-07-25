-- 039_enero_alexander_luz.sql — enero de Alexander deja de ser un estimado inventado (Stag, 25/07/2026).
--
-- ── LA FACTURA QUE FALTABA ──────────────────────────────────────────────────────
-- TotalEnergies 1NSN260200213697, aportada por Stag el 25/07/2026. Estaba archivada en la
-- carpeta de enero de Confisic desde el principio; la 034 la contabilizó (por eso decía
-- "4B_ALEX cubierto 24.01") pero enero quedó fuera por cobertura parcial y nunca se cerró.
--
--   CUPS ES0022000007651519XG1P · contador 40088846 · "CL SEGOVIA 8, 4º, B"  → es el 4B.
--   Contrato 700009721799 · titular Santiago Tagliaferri (NIF personal 55114137L)
--   Período 24.01.2026 – 05.02.2026 · 12 días facturados · 485 kWh · 77,89 € (base 64,37 + IVA 13,52)
--
--   prorrateo por día:  8 días de enero (24–31) = 51,93 €
--                       4 días de febrero (1–4) = 25,96 €  ← ya dentro de los 126,92 de la 034
--
-- ── LO QUE ESTA MIGRACIÓN NO RESUELVE, Y HAY QUE DECIRLO ────────────────────────
-- Del 01 al 23 de enero el suministro estaba a nombre del titular ANTERIOR (presumiblemente
-- Alberto, el propietario: el CUPS pasa a Santiago recién el 24/01 y a la sociedad el 05/02).
-- No hay factura ni event de reembolso por ese tramo. Al ritmo de la propia factura —
-- 6,49 €/día, 40 kWh/día de pleno invierno — esos 23 días valen ~149 €.
--
-- Se carga SOLO lo documentado (51,93 €) y se marca `fiable = false`, así que la vista lo
-- etiqueta `real_revisar` y el dashboard no lo presenta como cerrado. No se extrapolan los 23
-- días: sería inventarle a Samavi un pasivo que nadie le reclamó. Si Alberto confirma que pasó
-- ese consumo, entra como event SUMINISTROS de enero — mismo circuito que el agua (028).
--
-- Contra el estimado que había (150,00 €/mes), enero de Alexander mejora 73,07 €. Esa mejora
-- es provisional por definición y se revierte si aparece el tramo de Alberto.
--
-- ── A NOMBRE PERSONAL, IMPUTADO A LA EMPRESA ────────────────────────────────────
-- Mismo caso que Marechal en la 038: la factura viene a nombre personal de Stag y domiciliada
-- en su cuenta. Decisión de Stag (25/07/2026): se imputa como coste de la sociedad igual,
-- porque el consumo es del piso que explota Samavi, y queda pendiente la refacturación a
-- nombre de SAMAVI. El criterio de IVA no cambia: peor caso, incluido (022, 031, 034).

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '4B_ALEX', 51.93, 25.00, 76.93, false,
   'PARCIAL: solo 24-31/01 (TotalEnergies 1NSN260200213697, 77,89 EUR / 12 dias, prorrateo por dia, IVA incluido). Del 01 al 23/01 el CUPS estaba a nombre del titular anterior (Alberto): ~149 EUR sin factura ni reembolso, pendiente de confirmar. Factura a nombre personal de Stag: refacturacion a SAMAVI pendiente. Internet: linea barata de Movistar (20,66 base -> 25,00 c/IVA).')
on conflict (anio, mes, codigo) do nothing;
