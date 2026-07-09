-- 003_views.sql — MOTOR DE CÁLCULO (vistas SQL)
-- Reimplementa el modelo del Excel de Samavi. La lógica está validada 1:1 contra la hoja
-- "Vista B" por scripts/validate_model.py (NICA 6.064,82 · ALEX -373,56 · MARE 310,15 ·
-- JACO 4.585,42 · TOTAL 10.586,82). Diferencia intencional vs Excel: imputación por DEVENGO
-- POR NOCHE (el Excel usa mes de check-in) → los totales anuales coinciden, cambian levemente
-- los bordes de mes.
--
-- ⚑ DECISIÓN DE NEGOCIO (jul 2026): se EXCLUYEN las reservas canceladas. El Excel las incluía
--   (host_payout retenido) → por eso su YTD daba 10.586,82€. Al excluirlas el YTD baja ~1.345€.
--   Para volver a incluirlas, añadir 'canceled' a la lista de status de v_reservation_income.

-- 1) Ingreso Samavi por reserva (regla por modelo) ─────────────────────────────
create or replace view v_reservation_income as
select
  r.id, r.codigo, r.checkin_local, r.checkout_local, r.source, r.status,
  coalesce(r.bruto, 0)       as bruto,
  coalesce(r.host_payout, 0) as host_payout,
  l.modelo,
  case when l.modelo = 'comision' then coalesce(r.bruto,0) * l.comision_pct
       else coalesce(r.host_payout,0) end                                    as ingreso_samavi,
  case when l.modelo = 'comision' then coalesce(r.host_payout,0) - coalesce(r.bruto,0)*l.comision_pct
       else 0 end                                                            as pasivo_madre
from reservations r
join listings l on l.codigo = r.codigo
where r.status in ('confirmed','checked_in','checked_out')   -- ⚑ canceladas EXCLUIDAS (ver cabecera)
  and r.checkin_local is not null and r.checkout_local is not null
  and r.checkout_local > r.checkin_local;

-- 2) Devengo por noche ─────────────────────────────────────────────────────────
create or replace view v_reservation_nights as
select
  ri.codigo,
  extract(year  from n.night)::int as anio,
  extract(month from n.night)::int as mes,
  ri.ingreso_samavi::numeric / (ri.checkout_local - ri.checkin_local) as ingreso_samavi_night,
  ri.bruto::numeric          / (ri.checkout_local - ri.checkin_local) as bruto_night
from v_reservation_income ri
cross join lateral generate_series(
  ri.checkin_local::timestamp,
  (ri.checkout_local - interval '1 day'),
  interval '1 day'
) as n(night);

-- ingresos/noches devengados por mes y propiedad
create or replace view v_nights_monthly as
select codigo, anio, mes,
  sum(ingreso_samavi_night) as ingreso_samavi,
  sum(bruto_night)          as bruto,
  count(*)                  as noches
from v_reservation_nights
group by codigo, anio, mes;

-- reservas contadas por mes de CHECK-IN (bookings)
create or replace view v_bookings_monthly as
select codigo,
  extract(year  from checkin_local)::int as anio,
  extract(month from checkin_local)::int as mes,
  count(*) as reservas
from v_reservation_income
group by codigo, extract(year from checkin_local), extract(month from checkin_local);

-- 3) Espina de meses activos (año en curso, hasta el mes actual, desde fecha_inicio) ──
create or replace view v_month_spine as
select l.codigo,
  extract(year  from gs)::int as anio,
  extract(month from gs)::int as mes
from listings l
cross join lateral generate_series(
  greatest(date_trunc('month', l.fecha_inicio), date_trunc('year', now())),
  date_trunc('month', now()),
  interval '1 month'
) gs;

-- 4) Waterfall mensual por propiedad (margen DIRECTO) ──────────────────────────
create or replace view v_pnl_mensual_propiedad as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0) as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0) as ev_otros
  from events
  group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    coalesce(n.bruto,0)          as bruto,
    coalesce(n.ingreso_samavi,0) as ingreso_samavi,
    coalesce(n.noches,0)         as noches,
    coalesce(b.reservas,0)       as reservas,
    (case when l.modelo='subarriendo' then -l.renta_base else 0 end + coalesce(ev.ev_renta,0)) as renta,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    -l.suministros_mes                                                                          as suministros,
    -l.comunidad_ibi_mes                                                                        as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                               as otros
  from v_month_spine s
  join listings l              on l.codigo = s.codigo
  left join v_nights_monthly   n on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join ev                   on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
)
select
  codigo, anio, mes, dias_mes, bruto, ingreso_samavi,
  (bruto - ingreso_samavi)                                            as comision_aparente,
  noches, reservas,
  round(noches::numeric / dias_mes, 4)                               as ocup_pct,
  case when noches > 0 then round(bruto / noches, 2) else 0 end       as adr,
  round(bruto / dias_mes, 2)                                          as revpar,
  case when reservas > 0 then round(noches::numeric / reservas, 2) else 0 end as alos,
  renta, limpieza, suministros, comunidad, otros,
  (renta + limpieza + suministros + comunidad + otros)               as total_gastos_directos,
  (ingreso_samavi + renta + limpieza + suministros + comunidad + otros) as margen_directo
from base;

-- 5) Overhead SAMAVI_GEN por mes (Bloque B + eventos SAMAVI_GEN) ───────────────
create or replace view v_samavi_gen_mensual as
select m.anio, m.mes,
  (select coalesce(sum(importe_mes),0) from general_expenses)
  - coalesce((select sum(importe) from events e
              where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
from (select distinct anio, mes from v_month_spine) m;

-- 6) Margen NETO mensual por propiedad (overhead prorrateado por Ingreso Samavi del mes) ─
create or replace view v_pnl_neto_propiedad as
with tot as (
  select anio, mes, sum(ingreso_samavi) as tot_ing
  from v_pnl_mensual_propiedad group by anio, mes
)
select p.*,
  round(-g.overhead * case when t.tot_ing>0 then p.ingreso_samavi/t.tot_ing else 0 end, 2) as cuota_samavi_gen,
  round(p.margen_directo - g.overhead * case when t.tot_ing>0 then p.ingreso_samavi/t.tot_ing else 0 end, 2) as margen_neto
from v_pnl_mensual_propiedad p
join tot t                  on t.anio=p.anio and t.mes=p.mes
join v_samavi_gen_mensual g on g.anio=p.anio and g.mes=p.mes;

-- 7) Ranking YTD por propiedad (prorrateo a nivel YTD → coincide con Vista B) ──
create or replace view v_ranking_ytd as
with ytd as (
  select codigo,
    sum(ingreso_samavi)        as ingreso_samavi,
    sum(bruto)                 as bruto,
    sum(noches)                as noches,
    sum(reservas)              as reservas,
    sum(dias_mes)              as noches_disponibles,
    sum(total_gastos_directos) as gastos_directos,
    sum(margen_directo)        as margen_directo
  from v_pnl_mensual_propiedad
  where anio = extract(year from now())::int
  group by codigo
),
oh as (select coalesce(sum(overhead),0) as total from v_samavi_gen_mensual where anio=extract(year from now())::int),
tt as (select coalesce(sum(ingreso_samavi),0) as t from ytd)
select
  y.codigo, y.ingreso_samavi, y.bruto, y.noches, y.reservas, y.noches_disponibles,
  y.gastos_directos, y.margen_directo,
  round(-(select total from oh) * case when (select t from tt)>0 then y.ingreso_samavi/(select t from tt) else 0 end, 2) as cuota_samavi_gen,
  round(y.margen_directo - (select total from oh) * case when (select t from tt)>0 then y.ingreso_samavi/(select t from tt) else 0 end, 2) as margen_neto,
  case when y.ingreso_samavi>0
       then round((y.margen_directo - (select total from oh) * (y.ingreso_samavi/(select t from tt))) / y.ingreso_samavi, 4)
       else 0 end as margen_neto_pct,
  case when y.noches>0
       then round((y.margen_directo - (select total from oh) * (y.ingreso_samavi/(select t from tt))) / y.noches, 2)
       else 0 end as eur_noche_neto,
  case when y.noches_disponibles>0 then round(y.noches::numeric/y.noches_disponibles,4) else 0 end as ocup_pct,
  case when y.noches>0 then round(y.bruto/y.noches,2) else 0 end as adr,
  case when y.noches_disponibles>0 then round(y.bruto/y.noches_disponibles,2) else 0 end as revpar
from ytd y
order by margen_neto desc;

-- 8) KPIs portfolio (tarjetas de la home) ─────────────────────────────────────
create or replace view v_kpis as
select
  round(sum(margen_neto),2)                                                                     as margen_neto_ytd,
  round(sum(ingreso_samavi),2)                                                                  as ingreso_samavi_ytd,
  round(sum(bruto),2)                                                                           as bruto_ytd,
  sum(noches)                                                                                   as noches_ytd,
  sum(noches_disponibles)                                                                       as noches_disponibles_ytd,
  case when sum(noches_disponibles)>0 then round(sum(noches)::numeric/sum(noches_disponibles),4) else 0 end as ocupacion_ytd,
  case when sum(noches)>0 then round(sum(bruto)/sum(noches),2) else 0 end                       as adr_ytd,
  case when sum(noches_disponibles)>0 then round(sum(bruto)/sum(noches_disponibles),2) else 0 end as revpar_ytd,
  case when sum(ingreso_samavi)>0 then round(sum(margen_neto)/sum(ingreso_samavi),4) else 0 end as margen_neto_pct_ytd,
  (select last_run from sync_state where id=1)                                                  as last_sync
from v_ranking_ytd;

-- 9) Tendencia mensual portfolio (gráfico) ────────────────────────────────────
create or replace view v_trend_mensual as
select anio, mes,
  round(sum(ingreso_samavi),2) as ingreso_samavi,
  round(sum(margen_directo),2) as margen_directo,
  round(sum(margen_neto),2)    as margen_neto
from v_pnl_neto_propiedad
group by anio, mes
order by anio, mes;

-- Grants: el cliente (anon) solo lee las vistas del dashboard (nunca las tablas base) ─
grant select on
  v_pnl_mensual_propiedad,
  v_pnl_neto_propiedad,
  v_ranking_ytd,
  v_kpis,
  v_trend_mensual
to anon, authenticated;
