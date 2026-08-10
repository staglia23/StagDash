-- 079_ecocleans_julio.sql — limpieza y mantenimiento de julio, Ecocleans/BMR (11/08/2026).
--
-- F260609 (emitida 05/08, vence 11/08): limpieza de JULIO. 16 servicios / 27,50 h,
-- tarifa sigue 16,40 €/h. Verificada al céntimo: 27,50×16,40 = 451,00 ✓; 16 kits ×
-- 1,80 = 28,80 ✓; renting NUEVO ESQUEMA plano 13,24/servicio (antes 10,44/20,24):
-- 16×13,24 = 211,84 + partida nueva "Deshecho textil" 38,13 = 249,97 ✓. Base 729,77 +
-- IVA 153,25 = 883,02 ✓. El deshecho textil se asigna a 1A_NICA: el servicio del 29/07
-- en 1A fue "repaso y cambio de textil" (si Ecocleans aclara otra cosa, se reparte).
-- La hoja de conciliación de Cowork da "NO CUADRA 836,88 vs 883,02" — FALSO negativo:
-- no conoce el deshecho textil y su chequeo de renting sigue siendo tautológico.
--
-- F260610 (misma fecha): mantenimiento por piso, factura aparte — 4B revisión 03/07
-- (42,00) + 1A revisión 06/07 (28,00) + 3G revisión 06/07 (28,00) + 1A urgente REVISAR
-- AC 28/07 (32,00). Events con IVA, criterio del precedente 076 (cerradura junio).
--
-- OJO cierre de AGOSTO: ambas facturas vencen el 11/08 → sus pagos aparecerán en los
-- extractos de agosto y NO se cargan de nuevo (el coste ya está acá, devengado julio).
-- ANOMALÍA para vigilar: 9 checkouts del 02–11/07 SIN servicio facturado (16 servicios
-- vs 24 checkouts) — riesgo de factura retroactiva o limpieza por otro canal.

insert into limpieza_mensual (anio, mes, codigo, servicios, horas, limpieza_eur, kits_eur, renting_eur, base_eur, iva_eur, factura, fiable)
select v.anio, v.mes, v.codigo, v.servicios, v.horas, v.limpieza, v.kits, v.renting, v.base, v.iva, 'F260609', true
from (values
  (2026, 7, '1A_NICA', 7, 14.00, 229.60, 12.60, 130.81, 373.01, 78.33),
  (2026, 7, '4B_ALEX', 4,  6.00,  98.40,  7.20,  52.96, 158.56, 33.30),
  (2026, 7, '3G_MARE', 5,  7.50, 123.00,  9.00,  66.20, 198.20, 41.62)
) as v(anio, mes, codigo, servicios, horas, limpieza, kits, renting, base, iva)
where not exists (
  select 1 from limpieza_mensual l
   where l.anio = v.anio and l.mes = v.mes and l.codigo = v.codigo
);

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, 'OTROS', v.concepto, v.importe, v.notas
from (values
  (2026, 7, '1A_NICA', 'Mantenimiento Ecocleans (F260610)', -72.60,
   'Revision general 06/07 (28,00) + urgente REVISAR AC 28/07 (32,00), base 60,00 + IVA = 72,60. Factura de mantenimiento separada de BMR/Ecocleans, vence 11/08 (el pago caera en el extracto de agosto: NO recargar).'),
  (2026, 7, '4B_ALEX', 'Mantenimiento Ecocleans (F260610)', -50.82,
   'Revision general 03/07, base 42,00 + IVA = 50,82. Vence 11/08 (pago en extracto de agosto: NO recargar).'),
  (2026, 7, '3G_MARE', 'Mantenimiento Ecocleans (F260610)', -33.88,
   'Revision general 06/07, base 28,00 + IVA = 33,88. Vence 11/08 (pago en extracto de agosto: NO recargar).')
) as v(anio, mes, cod, concepto, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = v.cod and e.concepto = v.concepto
);
