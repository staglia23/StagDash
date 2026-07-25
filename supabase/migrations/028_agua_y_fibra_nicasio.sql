-- 028_agua_y_fibra_nicasio.sql — dos correcciones de suministros (Stag, 25/07/2026).
--
-- Salen de leer las facturas y los extractos de Revolut de la carpeta Confisic (7 meses).
--
-- ── 1) EL AGUA DE ALEXANDER NO ESTABA EN NINGÚN LADO ────────────────────────────
-- Alberto reenvía el recibo del agua y Samavi se lo reembolsa por Revolut. Documentado en
-- los extractos: 54,04 € el 27/01 ("Reembolso Recibos Agua") y 38,11 € el 16/03 ("Recibo de
-- Agua 1-395"). Se factura bimensual. Es coste directo de la propiedad —la cláusula 6.1 del
-- contrato pone los suministros por contador a cargo del arrendatario— y no estaba cargado.
-- Marechal queda fuera a propósito: José Luis no pasa recibos de agua (confirmado por Stag).
--
-- Se imputa al MES DEL PAGO, que es la convención de todos los events del modelo (están
-- conciliados contra banco). Por devengo estricto habría que repartirlos entre los dos meses
-- que cubre cada recibo; se prefiere la coherencia con el resto del modelo.
--
-- ── 2) LA FIBRA DE NICASIO SE CONTABA DOS VECES ─────────────────────────────────
-- La línea de overhead "Orange (fibra pisos + dispositivos)" (329,80 €/mes) resultó ser, al
-- leer las seis facturas del año: UNA sola fibra (el fijo 910341360, 23,49 €/mes de base, que
-- es el internet de Nicasio) + 3 móviles + 115,76 €/mes de dispositivos a plazos + roaming +
-- compras de aplicaciones. O sea que el 93 % no es internet de los pisos.
--
-- Y esa fibra ya estaba dentro de los 150 €/mes de `suministros_mes` de Nicasio → doble
-- conteo. Se saca del overhead (28,42 € = 23,49 × 1,21) y se relabela la línea con lo que
-- realmente es. Queda pendiente de decidir con Stag si ese resto (móviles, dispositivos,
-- roaming) es overhead operativo o corporativo.

-- events gana la categoría SUMINISTROS, que cae en la línea de suministros de la propiedad
-- en vez de mezclarse en "otros". Prepara la ingesta de facturas de luz/internet/agua.
alter table events drop constraint if exists events_categoria_check;
alter table events add  constraint events_categoria_check
  check (categoria = any (array['RENTA', 'OTROS', 'SAMAVI_GEN', 'CORPORATIVO', 'SUMINISTROS']));

insert into events (propiedad_codigo, anio, mes, categoria, concepto, importe)
select * from (values
  ('4B_ALEX', 2026, 1, 'SUMINISTROS', 'Agua (reembolso a Alberto, recibo bimensual)', -54.04),
  ('4B_ALEX', 2026, 3, 'SUMINISTROS', 'Agua (reembolso a Alberto, recibo 1-395)',     -38.11)
) as v(propiedad_codigo, anio, mes, categoria, concepto, importe)
where not exists (
  select 1 from events e
   where e.propiedad_codigo = v.propiedad_codigo and e.anio = v.anio and e.mes = v.mes
     and e.categoria = 'SUMINISTROS' and e.concepto like 'Agua%');

update general_expenses
   set importe_mes = 301.38,
       concepto    = 'Orange — móviles, dispositivos y roaming'
 where concepto = 'Orange (fibra pisos + dispositivos)';

-- El motor: los events SUMINISTROS caen en la línea de suministros.
create or replace view v_pnl_mensual_propiedad as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0)       as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0)       as ev_otros,
    coalesce(sum(importe) filter (where categoria='SUMINISTROS'),0) as ev_suministros
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
    coalesce(n.iva_repercutido,0) + coalesce(c.iva_cancelaciones,0) as iva_repercutido,
    ((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0)) as renta_transfer,
    (l.renta_factura_desde is not null
      and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date) as con_factura,
    l.renta_iva_pct, l.renta_retencion_pct,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                        as suministros,
    -l.comunidad_ibi_mes                                                                        as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                               as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
),
conv as (
  select b.*,
    case when b.con_factura
         then (1 + b.renta_iva_pct) / (1 + b.renta_iva_pct - b.renta_retencion_pct)
         else 1 end as factor,
    case when b.con_factura
         then b.renta_iva_pct / (1 + b.renta_iva_pct - b.renta_retencion_pct)
         else 0 end as factor_iva
  from base b
),
final as (
  select c.*,
    round(c.renta_transfer * c.factor, 2)     as renta,
    round(c.renta_transfer * c.factor_iva, 2) as renta_iva
  from conv c
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
  ingreso_cancelaciones,
  iva_repercutido,
  renta_iva
from final;

-- Misma regla hacia adelante, para que forward y YTD no cuenten con criterios distintos.
create or replace view v_margen_asegurado as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0)       as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0)       as ev_otros,
    coalesce(sum(importe) filter (where categoria='SUMINISTROS'),0) as ev_suministros
  from events group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    dias_gestion(l.fecha_inicio, s.anio, s.mes)           as dias_gest,
    coalesce(n.bruto, 0) as bruto, coalesce(n.ingreso_samavi, 0) as ingreso_noches,
    coalesce(c.ingreso_cancelaciones, 0) as ingreso_cancelaciones,
    coalesce(n.noches, 0) as noches, coalesce(b.reservas, 0) as reservas,
    (((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0))
      * case when l.renta_factura_desde is not null
                  and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date
             then (1 + l.renta_iva_pct) / (1 + l.renta_iva_pct - l.renta_retencion_pct)
             else 1 end)                                                                        as renta,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                        as suministros,
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
oh as (
  select m.anio, m.mes,
    (select coalesce(sum(g.importe_mes), 0) from general_expenses g
      where not g.es_corporativo
        and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
        and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
    - coalesce((select sum(importe) from events e
                where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
  from (select distinct anio, mes from v_forward_spine) m
),
tot as (select anio, mes, sum(dias_gest) as tot_dias from base group by anio, mes)
select
  b.codigo, b.anio, b.mes, b.dias_mes,
  round(b.bruto, 2) as bruto,
  round(b.ingreso_noches + b.ingreso_cancelaciones, 2) as ingreso_asegurado,
  b.noches as noches_vendidas,
  round(b.noches::numeric / b.dias_mes, 4) as ocup_vendida,
  round(b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as gastos_directos,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as margen_directo,
  round(-o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2) as cuota_samavi_gen,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros
        - o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2) as margen_neto
from base b
join oh  o on o.anio = b.anio and o.mes = b.mes
join tot t on t.anio = b.anio and t.mes = b.mes;

grant select on v_margen_asegurado to anon, authenticated;
