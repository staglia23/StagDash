-- 011_vision_forward.sql — métricas forward para el morning check del operador (Fase A):
--   · v_forward: ocupación e ingreso YA VENDIDOS de los próximos 7/14/30 días, por propiedad,
--     más el detalle día a día de los próximos 30 (para la tira visual vendida/abierta).
--   · v_pickup: velocidad de venta — reservas nuevas en 7/15 días (por created_at) y días
--     desde la última reserva creada. Sin PII: solo agregados por propiedad.
-- Regla operativa (008): toda vista nueva nace pública por default privileges → GRANT explícito
-- y nada más; estas dos no exponen datos sensibles.

create or replace view v_forward as
with dias as (
  select codigo, night, ingreso_samavi_night, bruto_night
  from v_reservation_nights
  where night >= current_date and night < current_date + 30
)
select l.codigo,
  count(d.night) filter (where d.night < current_date + 7)   as noches_7,
  count(d.night) filter (where d.night < current_date + 14)  as noches_14,
  count(d.night)                                             as noches_30,
  round(coalesce(sum(d.bruto_night)   filter (where d.night < current_date + 7), 0), 2)  as bruto_7,
  round(coalesce(sum(d.bruto_night), 0), 2)                  as bruto_30,
  round(coalesce(sum(d.ingreso_samavi_night), 0), 2)         as ingreso_30
from listings l
left join dias d on d.codigo = l.codigo
group by l.codigo;

-- Detalle día a día para la tira de 30 días (vendida/abierta)
create or replace view v_forward_dias as
select l.codigo, g.dia::date as dia,
  (n.night is not null) as vendida
from listings l
cross join generate_series(current_date, current_date + interval '29 days', interval '1 day') as g(dia)
left join (select distinct codigo, night from v_reservation_nights
           where night >= current_date and night < current_date + 30) n
  on n.codigo = l.codigo and n.night = g.dia::date;

create or replace view v_pickup as
select l.codigo,
  count(r.id) filter (where r.created_at >= now() - interval '7 days')  as reservas_7d,
  count(r.id) filter (where r.created_at >= now() - interval '15 days') as reservas_15d,
  max(r.created_at)::date                                              as ultima_reserva,
  (current_date - max(r.created_at)::date)                             as dias_sin_vender
from listings l
left join reservations r
  on r.codigo = l.codigo and r.status in ('confirmed','checked_in','checked_out','closed')
group by l.codigo;

grant select on v_forward, v_forward_dias, v_pickup to anon, authenticated;
