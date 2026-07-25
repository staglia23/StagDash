-- 019_margen_asegurado.sql — "Margen neto asegurado hasta diciembre" (portada híbrida).
--
-- Qué responde: con lo YA RESERVADO a día de hoy, ¿qué margen neto deja cada propiedad
-- cada mes de aquí a fin de año? Es un PISO, no un pronóstico: sube a medida que se vende.
--
-- Mismas reglas del motor, sin excepciones:
--   · Ingreso por devengo/noche (v_nights_monthly) + cancelaciones retenidas del mes.
--   · Costes directos idénticos a v_pnl_mensual_propiedad (renta, limpieza por reserva,
--     suministros, comunidad, otros) + events del mes (RENTA / OTROS).
--   · Overhead prorrateado por peso en el ingreso del mes — igual que v_pnl_neto_propiedad.
--
-- ⚑ POR QUÉ LOS MESES LEJANOS DAN NEGATIVO (y no es una alarma): el coste del mes está
--   COMPLETO desde ya (renta, suministros, overhead se pagan igual), pero el ingreso es solo
--   el trozo vendido hasta hoy. Un mes a medio vender se lee en rojo y se corrige solo con
--   las reservas que entran. Por eso la vista expone `ocup_vendida`: el cliente pinta en gris
--   —no en rojo— los meses con poco vendido todavía (lib/asegurado.ts).
--
-- ⚑ Diferencia con v_pnl_neto_propiedad: aquella vive sobre v_month_spine, que termina en el
--   mes en curso (motor YTD). Esta arranca en el mes en curso y llega a diciembre. El mes en
--   curso aparece en las dos y da lo mismo, salvo por las noches del mes que aún no pasaron:
--   acá cuentan (es "asegurado"), y en el YTD también, porque el spine es mensual.
--
-- Regla 008: vista nueva nace pública por default privileges → GRANT explícito.

-- Espina forward: del mes en curso a diciembre del año en curso, por propiedad activa.
create or replace view v_forward_spine as
select l.codigo,
  extract(year  from gs)::int as anio,
  extract(month from gs)::int as mes
from listings l
cross join lateral generate_series(
  greatest(date_trunc('month', l.fecha_inicio), date_trunc('month', now())),
  date_trunc('year', now()) + interval '11 months',
  interval '1 month'
) gs;

create or replace view v_margen_asegurado as
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
    coalesce(n.bruto, 0)                 as bruto,
    coalesce(n.ingreso_samavi, 0)        as ingreso_noches,
    coalesce(c.ingreso_cancelaciones, 0) as ingreso_cancelaciones,
    coalesce(n.noches, 0)                as noches,
    coalesce(b.reservas, 0)              as reservas,
    (case when l.modelo='subarriendo' then -l.renta_base else 0 end + coalesce(ev.ev_renta,0)) as renta,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    -l.suministros_mes                                                                          as suministros,
    -l.comunidad_ibi_mes                                                                        as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                               as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
),
-- Overhead vigente de cada mes futuro (misma regla de vigencia que 010; v_samavi_gen_mensual
-- no sirve acá porque solo cubre los meses del spine YTD).
oh as (
  select m.anio, m.mes,
    (select coalesce(sum(g.importe_mes), 0)
       from general_expenses g
      where (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
        and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
    - coalesce((select sum(importe) from events e
                where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
  from (select distinct anio, mes from v_forward_spine) m
),
-- Peso de cada propiedad en el overhead del mes. Si el mes todavía no vendió NADA
-- (tot_ing = 0), prorratear por ingreso haría desaparecer el overhead y el mes se vería
-- mejor de lo que es → en ese caso se reparte en partes iguales. La suma de cuotas es
-- siempre el overhead del mes, se venda lo que se venda.
tot as (
  select anio, mes,
    sum(ingreso_noches + ingreso_cancelaciones) as tot_ing,
    count(*)                                    as n_props
  from base group by anio, mes
)
select
  b.codigo, b.anio, b.mes, b.dias_mes,
  round(b.bruto, 2)                                       as bruto,
  round(b.ingreso_noches + b.ingreso_cancelaciones, 2)    as ingreso_asegurado,
  b.noches                                                as noches_vendidas,
  round(b.noches::numeric / b.dias_mes, 4)                as ocup_vendida,
  round(b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as gastos_directos,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as margen_directo,
  round(-o.overhead * case when t.tot_ing > 0
                           then (b.ingreso_noches + b.ingreso_cancelaciones) / t.tot_ing
                           else 1.0 / t.n_props end, 2)    as cuota_samavi_gen,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros
        - o.overhead * case when t.tot_ing > 0
                            then (b.ingreso_noches + b.ingreso_cancelaciones) / t.tot_ing
                            else 1.0 / t.n_props end, 2)   as margen_neto
from base b
join oh  o on o.anio = b.anio and o.mes = b.mes
join tot t on t.anio = b.anio and t.mes = b.mes;

-- v_forward_spine es andamiaje interno: no la lee el dashboard.
revoke all on v_forward_spine from anon, authenticated;
grant select on v_margen_asegurado to anon, authenticated;
