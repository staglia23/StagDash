-- 076_ecocleans_junio_fix.sql — Ecocleans junio: kit de ALEX + mantenimiento (11/08/2026).
--
-- Lectura de las facturas reales de Ecocleans/BMR (F260506 y F260507, pagadas el 15/07;
-- eran los dos únicos pagos de julio que faltaban asignar junto a los intereses del
-- préstamo):
--
-- 1) F260506 (1.171,47, servicios de JUNIO): la carga del 25/07 asumió 9 kits para
--    4B_ALEX (9 servicios), pero la factura cobra 8 — el servicio extra del 20-jun
--    (CI=1, 1:00 h, "la cama individual es el textil de cuna") fue SIN kit. Con 9 kits
--    la suma por pisos daba 969,96 de base contra los 968,16 facturados y pagados.
--    Corrección ALEX junio: kits 16,20 → 14,40, base 351,76 → 349,96, IVA 73,87 → 73,49.
--    Tras el fix: bases 360,32 + 349,96 + 257,88 = 968,16 ✓ e IVAs 75,67 + 73,49 +
--    54,15 = 203,31 ✓ — la factura cuadra al céntimo.
--
-- 2) F260507 (33,88): mantenimiento del 29/06 en Segovia 8 4B — revisar atasco de
--    cerradura. Es de junio por devengo; no existía event. Entra acá.
--
-- Con esto, TODOS los movimientos bancarios de julio quedan asignados salvo los
-- intereses del préstamo (cuota 923,78 del 31/07; falta el recibo con el desglose).

update limpieza_mensual
   set kits_eur = 14.40, base_eur = 349.96, iva_eur = 73.49
 where anio = 2026 and mes = 6 and codigo = '4B_ALEX'
   and kits_eur = 16.20 and base_eur = 351.76;

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 6, '4B_ALEX', 'OTROS', 'Mantenimiento cerradura (Ecocleans F260507)', -33.88,
  'Revision de atasco de cerradura el 29/06/2026 (Segovia 8, 4B). Factura F260507 de BMR/Ecocleans, 28,00 + IVA = 33,88, pagada el 15/07 (extracto julio). Junio por devengo.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 6 and e.propiedad_codigo = '4B_ALEX'
     and e.concepto = 'Mantenimiento cerradura (Ecocleans F260507)'
);
