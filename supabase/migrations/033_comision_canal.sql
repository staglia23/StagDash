-- 033_comision_canal.sql — el mayor coste directo deja de ser invisible (Stag, 25/07/2026).
--
-- ── POR QUÉ ─────────────────────────────────────────────────────────────────────
-- El motor arranca en `host_payout`, que ya viene con la comisión del canal descontada. O sea
-- que el coste más grande del negocio no aparece en ninguna pantalla. Enero–julio 2026:
--
--     Comisión de canal (Samavi)   18.764,14 €   ← 18,5 % del bruto
--     Renta a propietarios         17.418,54 €
--     Limpieza                      8.358,27 €
--
-- Y el 98,1 % del bruto entra por una sola cuenta de Airbnb. No se puede decidir sobre una
-- dependencia que no se mide.
--
-- ── QUIÉN SOPORTA LA COMISIÓN ───────────────────────────────────────────────────
-- Depende del modelo, y mezclarlo daría un número falso:
--   · titular / subarriendo (NICA, ALEX, MARE): la paga Samavi. El canal la descuenta del
--     payout y el payout ES el ingreso de Samavi.
--   · comisión (JACO): la soporta la dueña. Samavi factura el 30,25 % sobre el bruto pase lo
--     que pase, así que su ingreso no cambia si el canal cobra más o menos.
-- Por eso van dos columnas: `comision_canal` (lo que cobra el canal, siempre) y
-- `comision_canal_samavi` (la parte que sale del bolsillo de Samavi). En las tres de Madrid son
-- iguales; en Jacobine la segunda es 0.
--
-- ── SEGURIDAD: UNA FUGA QUE QUEDÓ ABIERTA ───────────────────────────────────────
-- La migración 008 revocó `anon` sobre `v_reservation_income` porque exponía `host_payout` por
-- reserva. Pero `v_reservation_nights` — que deriva de ella — se quedó con el grant, y trae
-- `id` + `bruto_night` + `ingreso_samavi_night`: agrupando por `id` se reconstruye exactamente
-- el mismo dato que 008 cerró. La fuga estaba tapada en la vista madre y abierta en la hija.
--
-- El frontend solo la usa para el MTD de la portada, y de las nueve columnas necesita tres.
-- Se crea `v_noches_mtd` con esas tres y se revoca la vista ancha. Sin pérdida funcional.
-- (Confirmado leyendo web/lib/mtd.ts: NocheRow = { codigo, night, ingreso_samavi_night }.)

-- ── 1) LA COMISIÓN, A NIVEL RESERVA ─────────────────────────────────────────────
create or replace view v_reservation_income as
select
  r.id, r.codigo, r.checkin_local, r.checkout_local, r.source, r.status,
  coalesce(r.bruto, 0)       as bruto,
  coalesce(r.host_payout, 0) as host_payout,
  l.modelo,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct / (1 + l.iva_pct)
       else coalesce(r.host_payout,0) end                                    as ingreso_samavi,
  case when l.modelo = 'comision'
       then coalesce(r.host_payout,0) - (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else 0 end                                                            as pasivo_madre,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct * (1 - 1 / (1 + l.iva_pct))
       else 0 end                                                            as iva_repercutido,
  coalesce(r.host_service_fee, 0)                                            as comision_canal,
  case when l.modelo = 'comision' then 0
       else coalesce(r.host_service_fee, 0) end                              as comision_canal_samavi
from reservations r
join listings l on l.codigo = r.codigo
where r.status in ('confirmed','checked_in','checked_out')
  and r.checkin_local is not null and r.checkout_local is not null
  and r.checkout_local > r.checkin_local;

-- ── 2) DEVENGO POR NOCHE, igual que el ingreso ──────────────────────────────────
create or replace view v_reservation_nights as
select
  ri.codigo,
  extract(year  from n.night)::integer as anio,
  extract(month from n.night)::integer as mes,
  ri.ingreso_samavi  / (ri.checkout_local - ri.checkin_local)::numeric as ingreso_samavi_night,
  ri.bruto           / (ri.checkout_local - ri.checkin_local)::numeric as bruto_night,
  n.night::date as night,
  ri.id,
  ri.source,
  ri.iva_repercutido / (ri.checkout_local - ri.checkin_local)::numeric as iva_night,
  ri.comision_canal        / (ri.checkout_local - ri.checkin_local)::numeric as fee_night,
  ri.comision_canal_samavi / (ri.checkout_local - ri.checkin_local)::numeric as fee_samavi_night
from v_reservation_income ri
cross join lateral generate_series(
  ri.checkin_local::timestamp, ri.checkout_local - interval '1 day', interval '1 day') n(night);

create or replace view v_nights_monthly as
select codigo, anio, mes,
  sum(ingreso_samavi_night) as ingreso_samavi,
  sum(bruto_night)          as bruto,
  count(*)                  as noches,
  sum(iva_night)            as iva_repercutido,
  sum(fee_night)            as comision_canal,
  sum(fee_samavi_night)     as comision_canal_samavi
from v_reservation_nights
group by codigo, anio, mes;

-- ── 3) SEGURIDAD: vista angosta para el MTD, y se cierra la ancha ───────────────
create or replace view v_noches_mtd as
select codigo, night, ingreso_samavi_night
from v_reservation_nights;

grant select on v_noches_mtd to anon, authenticated;
revoke all on v_reservation_nights from anon, authenticated;

-- ── 4) EL CANAL COMO DATO DE NEGOCIO ────────────────────────────────────────────
-- Devengado por noche, igual que todo el resto: una reserva a caballo entre dos meses aporta
-- a los dos. `reservas` cuenta la reserva en cada mes que toca, que es lo coherente con eso.
-- Sin PII y sin dato por reserva → puede ir al dashboard.
create or replace view v_canales_mensual as
select
  codigo, anio, mes,
  coalesce(source, 'directo')          as canal,
  count(*)                             as noches,
  count(distinct id)                   as reservas,
  round(sum(bruto_night), 2)           as bruto,
  round(sum(fee_night), 2)             as comision_canal,
  round(sum(fee_samavi_night), 2)      as comision_canal_samavi,
  round(sum(ingreso_samavi_night), 2)  as ingreso_samavi,
  case when sum(bruto_night) > 0
       then round(sum(fee_night) / sum(bruto_night), 4) else 0 end as comision_pct,
  case when count(*) > 0
       then round(sum(fee_night) / count(*), 2) else 0 end         as coste_por_noche
from v_reservation_nights
group by codigo, anio, mes, coalesce(source, 'directo');

grant select on v_canales_mensual to anon, authenticated;

-- ── 5) LA LÍNEA EN EL P&L ───────────────────────────────────────────────────────
-- Se añaden al final: `create or replace` solo permite agregar columnas, nunca reordenar.
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
    coalesce(n.comision_canal,0)         as comision_canal,
    coalesce(n.comision_canal_samavi,0)  as comision_canal_samavi,
    ((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0)) as renta_transfer,
    (l.renta_factura_desde is not null
      and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date) as con_factura,
    l.renta_iva_pct, l.renta_retencion_pct,
    lp.coste                                                                                as limpieza,
    lp.fuente                                                                               as limpieza_fuente,
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                    as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  join v_limpieza_mensual lp          on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
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
  renta_iva,
  limpieza_fuente,
  round(comision_canal, 2)        as comision_canal,
  round(comision_canal_samavi, 2) as comision_canal_samavi
from final;
