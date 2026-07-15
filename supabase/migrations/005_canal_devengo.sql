-- 005_canal_devengo.sql — consistencia del mix por canal
-- El mix se devenga por noche igual que el resto del motor y se recorta al mismo rango que
-- v_month_spine (ene..mes en curso), para que sus totales cuadren con el Ingreso Samavi YTD.
-- (Antes contaba reservas por fecha de check-in, incluyendo las futuras → no cuadraba.)

create or replace view v_reservation_nights as
select
  ri.codigo,
  extract(year  from n.night)::int as anio,
  extract(month from n.night)::int as mes,
  ri.ingreso_samavi::numeric / (ri.checkout_local - ri.checkin_local) as ingreso_samavi_night,
  ri.bruto::numeric          / (ri.checkout_local - ri.checkin_local) as bruto_night,
  n.night::date as night,
  ri.id,
  ri.source
from v_reservation_income ri
cross join lateral generate_series(
  ri.checkin_local::timestamp,
  (ri.checkout_local - interval '1 day'),
  interval '1 day'
) as n(night);

create or replace view v_canal_ytd as
select codigo,
  coalesce(source, 'directo/otro') as canal,
  count(distinct id) as reservas,
  round(sum(ingreso_samavi_night), 2) as ingreso
from v_reservation_nights
where anio = extract(year from now())::int
  and mes <= extract(month from now())::int
group by codigo, coalesce(source, 'directo/otro');

grant select on v_canal_ytd to anon, authenticated;
