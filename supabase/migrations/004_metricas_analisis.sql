-- 004_metricas_analisis.sql — métricas de análisis para el negocio
--   1) Desglose de costes por propiedad   2) Punto de equilibrio (break-even)
--   3) Mix por canal                       4) Ingreso ya reservado (on the books)

-- v_reservation_nights: exponer la fecha de la noche (necesaria para "on the books")
create or replace view v_reservation_nights as
select
  ri.codigo,
  extract(year  from n.night)::int as anio,
  extract(month from n.night)::int as mes,
  ri.ingreso_samavi::numeric / (ri.checkout_local - ri.checkin_local) as ingreso_samavi_night,
  ri.bruto::numeric          / (ri.checkout_local - ri.checkin_local) as bruto_night,
  n.night::date as night
from v_reservation_income ri
cross join lateral generate_series(
  ri.checkin_local::timestamp,
  (ri.checkout_local - interval '1 day'),
  interval '1 day'
) as n(night);

-- 1) DESGLOSE DE COSTES por propiedad (YTD). Valores positivos = cuánto cuesta.
create or replace view v_costes_ytd as
with ytd as (
  select codigo,
    sum(renta) as renta, sum(limpieza) as limpieza, sum(suministros) as suministros,
    sum(comunidad) as comunidad, sum(otros) as otros,
    sum(total_gastos_directos) as total_directos, sum(ingreso_samavi) as ingreso
  from v_pnl_mensual_propiedad
  where anio = extract(year from now())::int
  group by codigo
)
select y.codigo,
  round(-y.renta, 2)            as renta,
  round(-y.limpieza, 2)         as limpieza,
  round(-y.suministros, 2)      as suministros,
  round(-y.comunidad, 2)        as comunidad,
  round(-y.otros, 2)            as otros,
  round(-y.total_directos, 2)   as total_directos,
  round(-r.cuota_samavi_gen, 2) as overhead,
  round(-(y.total_directos + r.cuota_samavi_gen), 2) as total_costes,
  case when y.ingreso > 0
       then round(-(y.total_directos + r.cuota_samavi_gen) / y.ingreso, 4) else 0 end as pct_sobre_ingreso
from ytd y join v_ranking_ytd r on r.codigo = y.codigo;

-- 2) PUNTO DE EQUILIBRIO por propiedad
--    fijos = renta + suministros + comunidad + otros + overhead (no dependen de la ocupación)
--    variable = limpieza (por reserva) → contribución por noche = (ingreso - limpieza) / noches
create or replace view v_breakeven_ytd as
with ytd as (
  select codigo,
    sum(ingreso_samavi) as ingreso, sum(noches) as noches, sum(dias_mes) as disponibles,
    sum(renta) as renta, sum(limpieza) as limpieza, sum(suministros) as suministros,
    sum(comunidad) as comunidad, sum(otros) as otros
  from v_pnl_mensual_propiedad
  where anio = extract(year from now())::int
  group by codigo
),
calc as (
  select y.codigo, y.noches, y.disponibles,
    (-(y.renta + y.suministros + y.comunidad + y.otros) - r.cuota_samavi_gen) as costes_fijos,
    case when y.noches > 0 then (y.ingreso + y.limpieza) / y.noches else 0 end as contrib_noche,
    case when y.disponibles > 0 then y.noches::numeric / y.disponibles else 0 end as ocup_actual
  from ytd y join v_ranking_ytd r on r.codigo = y.codigo
)
select codigo,
  round(costes_fijos, 2)  as costes_fijos,
  round(contrib_noche, 2) as contribucion_noche,
  case when contrib_noche > 0 then ceil(costes_fijos / contrib_noche)::int else null end as noches_necesarias,
  case when contrib_noche > 0 and disponibles > 0
       then round((costes_fijos / contrib_noche) / disponibles, 4) else null end as ocup_breakeven,
  round(ocup_actual, 4) as ocup_actual,
  case when contrib_noche > 0 and disponibles > 0
       then round(ocup_actual - (costes_fijos / contrib_noche) / disponibles, 4) else null end as colchon
from calc;

-- 3) MIX POR CANAL (YTD)
create or replace view v_canal_ytd as
select codigo,
  coalesce(source, 'directo/otro') as canal,
  count(*) as reservas,
  round(sum(ingreso_samavi), 2) as ingreso
from v_reservation_income
where extract(year from checkin_local)::int = extract(year from now())::int
group by codigo, coalesce(source, 'directo/otro');

-- 4) INGRESO YA RESERVADO (on the books) — noches futuras ya confirmadas
create or replace view v_on_the_books as
select anio, mes, codigo,
  count(*) as noches,
  round(sum(ingreso_samavi_night), 2) as ingreso
from v_reservation_nights
where night >= current_date
group by anio, mes, codigo;

grant select on v_costes_ytd, v_breakeven_ytd, v_canal_ytd, v_on_the_books to anon, authenticated;
