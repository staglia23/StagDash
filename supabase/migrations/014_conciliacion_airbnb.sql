-- 014_conciliacion_airbnb.sql — vista de conciliación mensual Guesty ↔ Airbnb.
-- Verificado 24/07/2026 contra los 6 PDF oficiales de Airbnb (ene–jun 2026, las 4 propiedades):
-- el payout de Guesty reconcilia AL CÉNTIMO con el "Total" del informe de ingresos de Airbnb,
-- una vez que se atribuye por fecha de PAGO (check-in + ~1 día, como paga Airbnb) y se suman
-- las cancelaciones con cobro retenido (Airbnb las paga; el motor las cuenta en línea aparte,
-- v_ingreso_cancelaciones). Uso: comparar payout_total_airbnb por (codigo, anio, mes) contra
-- el "Total" del PDF del mes. Los canales no-Airbnb (Booking, directas) van por fuera.
-- Interna (ops/cierre mensual): REVOKE — expone payout agregado por propiedad/mes.

create or replace view v_conciliacion_airbnb as
select
  r.codigo,
  extract(year  from (r.checkin_local + interval '1 day'))::int as anio,
  extract(month from (r.checkin_local + interval '1 day'))::int as mes,
  count(*) filter (where r.status <> 'canceled')                                  as reservas,
  round(coalesce(sum(r.host_payout) filter (where r.status <> 'canceled'),0), 2)  as payout_confirmado,
  round(coalesce(sum(r.host_payout) filter (where r.status = 'canceled'),0), 2)   as payout_cancelado_retenido,
  round(sum(r.host_payout), 2)                                                     as payout_total_airbnb
from reservations r
where r.source = 'airbnb2'
  and r.checkin_local is not null
  and (r.status in ('confirmed','checked_in','checked_out')
       or (r.status = 'canceled' and coalesce(r.host_payout,0) <> 0))
group by r.codigo,
  extract(year from (r.checkin_local + interval '1 day')),
  extract(month from (r.checkin_local + interval '1 day'));

revoke all on v_conciliacion_airbnb from anon, authenticated;
