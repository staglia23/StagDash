-- 021_iva_repercutido_comision.sql — el IVA de la comisión de Jacobine NO es ingreso.
--
-- Decisión de negocio (Stag, 25/07/2026): la comisión de Jacobine es 30,25 % = 25 % de base
-- + 21 % de IVA sobre esa base (25 × 1,21 = 30,25). Esos 5,25 puntos son IVA repercutido:
-- plata de Hacienda que pasa por la cuenta de Samavi y sale en el 303 trimestral. Contarla
-- como ingreso inflaba el Ingreso Samavi y, en cascada, el margen neto de todo el portfolio.
-- Magnitud detectada: 2.456,93 € YTD 2026 = el 13,5 % del margen neto del portfolio.
--
-- Modelo nuevo:
--   · comision_pct (0,3025) NO se toca: es lo que se factura y lo que se le descuenta a la
--     dueña, así que `pasivo_madre` sigue calculándose sobre el cobro completo.
--   · ingreso_samavi = cobro / (1 + iva_pct)  → la base, que sí es ingreso.
--   · iva_repercutido = cobro − ingreso_samavi → visible, pero fuera del margen.
--
-- Titular y subarriendo (NICA/ALEX/MARE) NO se tocan: el alquiler turístico sin servicios de
-- hostelería está exento de IVA, así que su host_payout no lleva IVA repercutido. Si Confisic
-- confirmara que hay servicios tipo hostelería (10 %), bastaría con poner su iva_pct.
--
-- Todas las vistas se redefinen AÑADIENDO columnas al final (create or replace no permite
-- reordenar ni quitar). El orden de abajo respeta las dependencias.

alter table listings add column if not exists iva_pct numeric(8,4) not null default 0;

-- Idempotente: solo pone el 21 % donde todavía está en cero.
update listings set iva_pct = 0.21 where modelo = 'comision' and iva_pct = 0;

-- 1) Ingreso por reserva: la base sin IVA es el ingreso; el IVA sale como línea propia.
create or replace view v_reservation_income as
select
  r.id, r.codigo, r.checkin_local, r.checkout_local, r.source, r.status,
  coalesce(r.bruto, 0)       as bruto,
  coalesce(r.host_payout, 0) as host_payout,
  l.modelo,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
            / (1 + l.iva_pct)
       else coalesce(r.host_payout,0) end                                    as ingreso_samavi,
  -- El pasivo con la dueña se calcula sobre el cobro COMPLETO (IVA incluido): es lo que se
  -- le factura y lo que efectivamente se le descuenta del payout.
  case when l.modelo = 'comision'
       then coalesce(r.host_payout,0) - (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else 0 end                                                            as pasivo_madre,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
            * (1 - 1 / (1 + l.iva_pct))
       else 0 end                                                            as iva_repercutido
from reservations r
join listings l on l.codigo = r.codigo
where r.status in ('confirmed','checked_in','checked_out')
  and r.checkin_local is not null and r.checkout_local is not null
  and r.checkout_local > r.checkin_local;

-- 2) Devengo por noche: el IVA se prorratea igual que el ingreso, para que cuadre por mes.
create or replace view v_reservation_nights as
select
  ri.codigo,
  extract(year  from n.night)::int as anio,
  extract(month from n.night)::int as mes,
  ri.ingreso_samavi::numeric / (ri.checkout_local - ri.checkin_local) as ingreso_samavi_night,
  ri.bruto::numeric          / (ri.checkout_local - ri.checkin_local) as bruto_night,
  n.night::date as night,
  ri.id,      -- id y source los añadió 005 (v_canal_ytd los usa): NO tocar el orden
  ri.source,
  ri.iva_repercutido::numeric / (ri.checkout_local - ri.checkin_local) as iva_night
from v_reservation_income ri
cross join lateral generate_series(
  ri.checkin_local::timestamp,
  (ri.checkout_local - interval '1 day'),
  interval '1 day'
) as n(night);

create or replace view v_nights_monthly as
select codigo, anio, mes,
  sum(ingreso_samavi_night) as ingreso_samavi,
  sum(bruto_night)          as bruto,
  count(*)                  as noches,
  sum(iva_night)            as iva_repercutido
from v_reservation_nights
group by codigo, anio, mes;

-- 3) Cancelaciones retenidas: misma regla (la comisión retenida también lleva IVA).
--    Se mantiene su base histórica (`bruto`), que es la que tenía desde 009.
create or replace view v_ingreso_cancelaciones as
select
  r.codigo,
  extract(year  from r.checkin_local)::int as anio,
  extract(month from r.checkin_local)::int as mes,
  sum(case when l.modelo = 'comision' then coalesce(r.bruto,0) * l.comision_pct / (1 + l.iva_pct)
           else coalesce(r.host_payout,0) end)                as ingreso_cancelaciones,
  count(*)                                                    as reservas_canceladas,
  sum(case when l.modelo = 'comision'
           then coalesce(r.bruto,0) * l.comision_pct * (1 - 1 / (1 + l.iva_pct))
           else 0 end)                                        as iva_cancelaciones
from reservations r
join listings l on l.codigo = r.codigo
where r.status = 'canceled'
  and coalesce(r.host_payout, 0) <> 0
  and r.checkin_local is not null
group by r.codigo, extract(year from r.checkin_local), extract(month from r.checkin_local);

-- 4) P&L mensual: el IVA viaja como columna informativa, nunca entra al margen.
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
  ingreso_cancelaciones,
  iva_repercutido
from base;

-- 5) Ranking YTD: mismo cálculo, con el IVA repercutido del año al final.
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
    sum(ingreso_cancelaciones)  as ingreso_cancelaciones,
    sum(iva_repercutido)        as iva_repercutido
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
  y.ingreso_cancelaciones,
  round(y.iva_repercutido, 2) as iva_repercutido
from ytd y
order by margen_neto desc;

-- 6) Parámetros por propiedad: el cliente necesita la comisión NETA para el break-even y el
--    simulador (si usara el 30,25 % sobreestimaría el ingreso por noche igual que antes).
create or replace view v_propiedades as
select codigo, modelo, fecha_inicio, renta_base, comision_pct, aviso_fecha, aviso_nota,
  iva_pct,
  round(comision_pct / (1 + iva_pct), 6) as comision_pct_neta
from listings;

grant select on v_propiedades to anon, authenticated;
