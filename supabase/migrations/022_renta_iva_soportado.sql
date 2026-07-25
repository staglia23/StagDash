-- 022_renta_iva_soportado.sql — el coste real de las rentas de subarriendo (hipótesis prudente).
--
-- Contexto (Stag, 25/07/2026, tras revisar las facturas de Alberto López y José Luis Angulo):
-- las rentas de ALEX y MARE se facturan con IVA 21 % y retención de IRPF 19 %. La aritmética:
--
--     base × (1 + 0,21 − 0,19) = base × 1,02 = LO QUE SE TRANSFIERE al propietario
--
--   · ALEX: base 1.386,49 → transfiere 1.414,22   (factura 005/26 de Alberto)
--   · MARE: base 1.078,43 → transfiere 1.100,00   (factura 002/26 de José Luis; el contrato
--     está redactado como "1.100 NETO al propietario", de ahí la base derivada)
--
-- Qué estaba mal: el motor cargaba como coste LA TRANSFERENCIA, que no es ninguna de las dos
-- cifras correctas. La retención NO es coste (es plata del propietario que Samavi ingresa en
-- su nombre vía modelo 115), y el IVA soportado solo es coste si NO se puede deducir.
--
-- ⚑ DECISIÓN DE NEGOCIO: se modela el PEOR CASO — IVA soportado NO deducible. Motivo: la
--   consulta nº 1 del pliego a la gestoría (régimen de IVA de los 3 pisos de Madrid, abierta
--   desde 24/04/2026) sigue sin respuesta. Si la actividad resulta exenta (art. 20.Uno.23
--   LIVA), ese IVA es coste puro. Prudente > optimista mientras no haya respuesta.
--   Cuando Confisic conteste: si es deducible, basta poner renta_iva_pct = 0 y el motor
--   vuelve a la base sin rehacer nada.
--
--     coste = transferencia × (1 + iva) / (1 + iva − retención) = transferencia × 1,186275
--
--   Se mantiene renta_base EN TÉRMINOS DE TRANSFERENCIA a propósito: así los events de
--   compensación, el ritual de cierre y la conciliación bancaria —que están todos en euros
--   transferidos— siguen cuadrando sin tocar ni una fila.
--
-- Vigencia: el IVA solo aplica desde que hay factura. MARE cobró ene–may sin factura ni
-- retención (1.100 € directos), así que esos meses no llevan factor.

alter table listings add column if not exists renta_iva_pct       numeric(8,4) not null default 0;
alter table listings add column if not exists renta_retencion_pct numeric(8,4) not null default 0;
alter table listings add column if not exists renta_factura_desde date;

-- Idempotente: solo escribe donde todavía está sin configurar.
update listings set renta_iva_pct = 0.21, renta_retencion_pct = 0.19,
                    renta_factura_desde = date '2025-10-01'
 where codigo = '4B_ALEX' and renta_factura_desde is null;

update listings set renta_iva_pct = 0.21, renta_retencion_pct = 0.19,
                    renta_factura_desde = date '2026-06-01'
 where codigo = '3G_MARE' and renta_factura_desde is null;

-- ── Fix de la renta Q4 de Alexander ─────────────────────────────────────────────
-- El prorrateo de mobiliario (−255,31 €/mes) termina en septiembre, así que desde OCTUBRE
-- la base contractual pasa a 1.614,80 € → transferencia 1.647,10 €.
-- Dos errores que corrige esto:
--   1) octubre no tenía cargada la subida (estaba ~233 € barato);
--   2) nov/dic usaban −200,58, que lleva a 1.614,80 = la BASE, mientras el resto del año va
--      en transferencia. En transferencia el ajuste correcto es −232,88 (1.647,10 − 1.414,22).
update events
   set importe = -232.88,
       concepto = 'Renta sube Q4 (fin prorrateo mobiliario) — en transferencia'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes in (11, 12)
   and categoria = 'RENTA' and concepto like 'Renta sube Q4%';

insert into events (propiedad_codigo, anio, mes, categoria, concepto, importe)
select '4B_ALEX', 2026, 10, 'RENTA',
       'Renta sube Q4 (fin prorrateo mobiliario) — en transferencia', -232.88
 where not exists (
   select 1 from events
    where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes = 10
      and categoria = 'RENTA' and concepto like 'Renta sube Q4%');

-- ── Motor: la renta pasa a costar transferencia × factor ────────────────────────
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
    coalesce(n.iva_repercutido,0) + coalesce(c.iva_cancelaciones,0) as iva_repercutido,
    -- Renta en euros TRANSFERIDOS (incluye los events de compensación)
    ((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0)) as renta_transfer,
    -- ¿Ese mes ya se factura con IVA + retención?
    (l.renta_factura_desde is not null
      and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date) as con_factura,
    l.renta_iva_pct, l.renta_retencion_pct,
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

-- v_costes_ytd: el IVA soportado de renta, visible como línea propia (va DENTRO de renta).
create or replace view v_costes_ytd as
with ytd as (
  select codigo,
    sum(renta) as renta, sum(limpieza) as limpieza, sum(suministros) as suministros,
    sum(comunidad) as comunidad, sum(otros) as otros,
    sum(total_gastos_directos) as total_directos, sum(ingreso_samavi) as ingreso,
    sum(renta_iva) as renta_iva
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
       then round(-(y.total_directos + r.cuota_samavi_gen) / y.ingreso, 4) else 0 end as pct_sobre_ingreso,
  round(-y.renta_iva, 2)        as renta_iva
from ytd y join v_ranking_ytd r on r.codigo = y.codigo;

-- v_margen_asegurado: misma regla hacia adelante (si no, el forward y el YTD contarían
-- la renta con dos criterios distintos).
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
    (((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0))
      * case when l.renta_factura_desde is not null
                  and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date
             then (1 + l.renta_iva_pct) / (1 + l.renta_iva_pct - l.renta_retencion_pct)
             else 1 end)                                                                        as renta,
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

grant select on v_margen_asegurado to anon, authenticated;
