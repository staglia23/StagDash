-- 009_cancelaciones_retenidas.sql — decisión de negocio (Stag, 16/07/2026):
-- las reservas CANCELADAS con cobro retenido son plata que ingresó y entran al conteo.
-- (Revierte parcialmente la exclusión total de canceladas de 003: aquella tiraba también
-- los payouts retenidos — 1.344,48 € YTD que Guesty sí muestra y el dashboard no.)
--
-- Reglas:
--   · Se imputan al MES DEL CHECK-IN de la estancia cancelada (como el Excel histórico).
--   · Van como LÍNEA SEPARADA (ingreso_cancelaciones): nunca tocan noches, ocupación ni ADR.
--   · Misma regla por modelo del motor: comisión (JACO) → bruto × comision_pct; resto → host_payout.
--   · ingreso_samavi (y todo lo que cae en cascada: margen directo/neto, prorrateo de
--     overhead, ranking, KPIs, % de costes) pasa a incluirlas.
--   · comision_aparente queda referida SOLO al ingreso por noches (el bruto no las incluye).
--   · El mix de canal (v_canal_ytd) sigue siendo de noches confirmadas: su total ya no
--     cuadra 1:1 con el ingreso Samavi — la diferencia es exactamente esta línea.

create or replace view v_ingreso_cancelaciones as
select
  r.codigo,
  extract(year  from r.checkin_local)::int as anio,
  extract(month from r.checkin_local)::int as mes,
  sum(case when l.modelo = 'comision' then coalesce(r.bruto,0) * l.comision_pct
           else coalesce(r.host_payout,0) end)                as ingreso_cancelaciones,
  count(*)                                                    as reservas_canceladas
from reservations r
join listings l on l.codigo = r.codigo
where r.status = 'canceled'
  and coalesce(r.host_payout, 0) <> 0
  and r.checkin_local is not null
group by r.codigo, extract(year from r.checkin_local), extract(month from r.checkin_local);

grant select on v_ingreso_cancelaciones to anon, authenticated;

-- v_pnl_mensual_propiedad: ingreso_samavi = noches + cancelaciones. Columnas nuevas al final.
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
    coalesce(n.bruto,0)                  as bruto,
    coalesce(n.ingreso_samavi,0)         as ingreso_noches,
    coalesce(c.ingreso_cancelaciones,0)  as ingreso_cancelaciones,
    coalesce(n.noches,0)                 as noches,
    coalesce(b.reservas,0)               as reservas,
    (case when l.modelo='subarriendo' then -l.renta_base else 0 end + coalesce(ev.ev_renta,0)) as renta,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    -l.suministros_mes                                                                          as suministros,
    -l.comunidad_ibi_mes                                                                        as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                               as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
)
select
  codigo, anio, mes, dias_mes, bruto,
  (ingreso_noches + ingreso_cancelaciones)                            as ingreso_samavi,
  (bruto - ingreso_noches)                                            as comision_aparente,
  noches, reservas,
  round(noches::numeric / dias_mes, 4)                                as ocup_pct,
  case when noches > 0 then round(bruto / noches, 2) else 0 end       as adr,
  round(bruto / dias_mes, 2)                                          as revpar,
  case when reservas > 0 then round(noches::numeric / reservas, 2) else 0 end as alos,
  renta, limpieza, suministros, comunidad, otros,
  (renta + limpieza + suministros + comunidad + otros)                as total_gastos_directos,
  (ingreso_noches + ingreso_cancelaciones
     + renta + limpieza + suministros + comunidad + otros)            as margen_directo,
  ingreso_noches,
  ingreso_cancelaciones
from base;

-- v_ranking_ytd: misma salida + ingreso_cancelaciones YTD al final (para el waterfall).
create or replace view v_ranking_ytd as
with ytd as (
  select codigo,
    sum(ingreso_samavi)         as ingreso_samavi,
    sum(bruto)                  as bruto,
    sum(noches)                 as noches,
    sum(reservas)               as reservas,
    sum(dias_mes)               as noches_disponibles,
    sum(total_gastos_directos)  as gastos_directos,
    sum(margen_directo)         as margen_directo,
    sum(ingreso_cancelaciones)  as ingreso_cancelaciones
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
  case when y.noches_disponibles>0 then round(y.bruto/y.noches_disponibles,2) else 0 end as revpar,
  y.ingreso_cancelaciones
from ytd y
order by margen_neto desc;
