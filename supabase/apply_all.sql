-- apply_all.sql — pegar TODO en Supabase SQL Editor y ejecutar (schema, rls, views, métricas, alertas, seed).
-- Generado por concatenación de migrations + seed. No editar a mano.

-- 001_schema.sql — tablas fuente del dashboard Samavi
-- Fuente única de verdad en Postgres. RAW de Guesty + parámetros portados del Excel.

-- ─────────────────────────────────────────────────────────────
-- listings — Bloque A del Excel (una fila por propiedad)
-- ─────────────────────────────────────────────────────────────
create table if not exists listings (
  codigo               text primary key,              -- 1A_NICA, 4B_ALEX, ...
  guesty_listing_id    text unique,                   -- se completa en Fase 0/2 (mapeo con Guesty)
  listing_nickname     text,                          -- MAD_NICASIO, ... (nickname en Guesty)
  ciudad               text,
  banco                text,
  modelo               text not null check (modelo in ('titular','subarriendo','comision')),
  fecha_inicio         date,
  -- parámetros económicos
  renta_base           numeric(12,2) not null default 0,   -- €/mes al propietario (subarriendo)
  comision_pct         numeric(8,4)  not null default 0,   -- comisión sobre bruto (JACO = 0,3025)
  iva_pct              numeric(6,4)  not null default 0,
  irpf_pct             numeric(6,4)  not null default 0,
  -- costos directos
  limpieza_por_reserva numeric(12,2) not null default 0,
  suministros_mes      numeric(12,2) not null default 0,
  comunidad_ibi_mes    numeric(12,2) not null default 0,   -- solo NICA (titular)
  minut                numeric(12,2) not null default 0,
  akiles               numeric(12,2) not null default 0,
  amenities            numeric(12,2) not null default 0,
  pricelabs            numeric(12,2) not null default 0,
  guesty_fee           numeric(12,2) not null default 0,
  extras               numeric(12,2) not null default 0,
  mobiliario_fin       numeric(12,2) not null default 0,   -- REFERENCIA: NO se usa en el cálculo
                                                           -- (la financiación entra por events OTROS/Klarna)
  -- datos sensibles (nunca expuestos a anon; sin política RLS de lectura)
  propietario          text,
  nif                  text,
  iban                 text,
  pasivo_base          numeric(12,2) not null default 0
);

-- ─────────────────────────────────────────────────────────────
-- reservations — RAW de Guesty (upsert por id). Mapeo de money a fijar en Fase 2.
-- ─────────────────────────────────────────────────────────────
create table if not exists reservations (
  id                text primary key,                 -- Guesty _id (clave de upsert)
  guesty_listing_id text,
  codigo            text references listings(codigo), -- resuelto en la ingesta
  checkin           timestamptz,
  checkout          timestamptz,
  checkin_local     date,
  checkout_local    date,
  nights            int,
  status            text,                             -- confirmed / canceled / checked_in / ...
  source            text,                             -- canal (airbnb, booking, ...)
  guest_nombre      text,
  -- monetario (candidatos; el mapeo real se confirma reconciliando con _RAW del Excel)
  bruto             numeric(12,2),                    -- "Bruto" del modelo
  host_service_fee  numeric(12,2),                    -- comisión del canal
  host_payout       numeric(12,2),                    -- neto al host
  total_paid        numeric(12,2),
  total_taxes       numeric(12,2),
  money_raw         jsonb,                            -- objeto money completo (auditoría)
  created_at        timestamptz,
  last_updated_at   timestamptz,                      -- para sync incremental
  synced_at         timestamptz not null default now()
);

create index if not exists idx_reservations_last_updated on reservations (last_updated_at desc);
create index if not exists idx_reservations_codigo_checkin on reservations (codigo, checkin_local);
create index if not exists idx_reservations_status on reservations (status);

-- ─────────────────────────────────────────────────────────────
-- general_expenses — Bloque B: SAMAVI_GEN recurrente (€/mes)
-- ─────────────────────────────────────────────────────────────
create table if not exists general_expenses (
  id          bigint generated always as identity primary key,
  concepto    text not null,
  importe_mes numeric(12,2) not null default 0
);

-- ─────────────────────────────────────────────────────────────
-- events — Bloque C: eventos puntuales por propiedad+mes
--   propiedad_codigo = un codigo de listings, o 'SAMAVI_GEN' para overhead
--   importe: positivo = descuento/crédito · negativo = gasto
-- ─────────────────────────────────────────────────────────────
create table if not exists events (
  id               bigint generated always as identity primary key,
  anio             int  not null,
  mes              int  not null check (mes between 1 and 12),
  propiedad_codigo text not null,
  categoria        text not null check (categoria in ('RENTA','OTROS','SAMAVI_GEN')),
  concepto         text,
  importe          numeric(12,2) not null default 0,
  notas            text
);
create index if not exists idx_events_lookup on events (propiedad_codigo, categoria, anio, mes);

-- ─────────────────────────────────────────────────────────────
-- sync_state — cursor de la ingesta incremental (singleton)
-- ─────────────────────────────────────────────────────────────
create table if not exists sync_state (
  id         int primary key default 1 check (id = 1),
  last_sync  timestamptz not null default '2024-01-01T00:00:00Z',  -- backfill: antes de la 1ª reserva
  last_run   timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);
insert into sync_state (id) values (1) on conflict (id) do nothing;

-- helper: días de un mes (immutable, usado por las vistas)
create or replace function days_in_month(y int, m int)
returns int language sql immutable as $$
  select extract(day from (make_date(y, m, 1) + interval '1 month - 1 day'))::int
$$;

-- 002_rls.sql — Row Level Security (Pilar: Seguro)
-- Estrategia: RLS ON en todas las tablas base SIN políticas de lectura para anon/authenticated,
-- de modo que el cliente NO puede tocar las tablas directamente. El front solo lee las VISTAS
-- del dashboard (ver 003_views.sql), que corren con los privilegios del owner (security definer
-- por defecto) y exponen únicamente columnas no sensibles. La escritura la hace la Edge Function
-- con la service_role key (que bypassa RLS).

alter table listings         enable row level security;
alter table reservations     enable row level security;
alter table general_expenses enable row level security;
alter table events           enable row level security;
alter table sync_state       enable row level security;

-- Sin credenciales del cliente sobre las tablas base (nif/iban/host_payout nunca viajan al front).
revoke all on listings, reservations, general_expenses, events, sync_state
  from anon, authenticated;

-- Nota: service_role bypassa RLS por defecto en Supabase → la ingesta escribe sin políticas.
-- Los GRANT de SELECT para 'anon' se otorgan SOLO sobre las vistas del dashboard en 003_views.sql.

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

-- seed.sql — generado por scripts/excel_to_seed.py (NO editar a mano)
-- Fuente: STAG SAMAVI — Dashboard 2026.xlsx · hoja '⚙️ Parámetros'
begin;
truncate table events, general_expenses, listings restart identity cascade;

insert into listings (codigo, listing_nickname, ciudad, banco, modelo, fecha_inicio,
  renta_base, comision_pct, iva_pct, irpf_pct, limpieza_por_reserva, suministros_mes,
  comunidad_ibi_mes, minut, akiles, amenities, pricelabs, guesty_fee, extras,
  mobiliario_fin, propietario, nif, iban, pasivo_base) values
  ('1A_NICA', 'MAD_NICASIO', 'Madrid', 'Revolut', 'titular', '2024-06-01', 0.0, 0.0, 0.0, 0.0, 53.72, 215.0, 402.78, 7.81, 6.05, 80.0, 13.91, 33.0, 0.0, 0.0, '—', 'n/a', 'n/a', 0.0),
  ('4B_ALEX', 'MAD_ALEXANDER', 'Madrid', 'BBVA', 'subarriendo', '2025-10-01', 1414.22, 0.0, 0.21, 0.19, 43.8, 145.0, 0.0, 7.81, 6.05, 80.0, 13.91, 30.0, 0.0, 162.77, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 0.0),
  ('3G_MARE', 'MAD_MARECHAL', 'Madrid', 'BBVA', 'subarriendo', '2025-12-01', 1100.0, 0.0, 0.21, 0.19, 43.8, 125.0, 0.0, 7.81, 6.05, 80.0, 13.91, 30.0, 0.0, 0.0, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 0.0),
  ('1A_JACO', 'SEV_JACOBINE', 'Sevilla', 'Revolut', 'comision', '2025-06-01', 0.0, 0.3025, 0.0, 0.0, 0.0, 10.79, 0.0, 7.81, 0.0, 0.0, 13.91, 30.0, 12.55, 0.0, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 20985.83);

insert into general_expenses (concepto, importe_mes) values
  ('Asesor Confisic', 181.5),
  ('Seguro RC', 18.25),
  ('Hostinger', 12.74),
  ('Google Workspace', 15.94),
  ('Revolut Business cuota', 43.0),
  ('Sueldo Stag bruto', 3333.33),
  ('TGSS RETA Stag', 370.75),
  ('Claude.ai', 200.0),
  ('Comisión Revolut', 43.0),
  ('Viajes corporativos', 50.0),
  ('Otros AEAT/admin', 50.0);

-- Brand Partners: 500 €/mes desde may-2026 hasta nuevo aviso (sin setup; fix 16/07/2026).
-- Requiere las columnas de vigencia de la migración 010 (desde/hasta).
insert into general_expenses (concepto, importe_mes, desde) values
  ('Brand Partners (marketing)', 500.0, date '2026-05-01');

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, 'ene-mar 2026'),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 5, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'crédito termo Alberto mayo'),
  (2026, 6, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'crédito termo Alberto junio'),
  (2026, 5, '3G_MARE', 'RENTA', 'Plan AA mayo (renta total descontada)', 1100.0, 'renta efectiva 0'),
  (2026, 6, '3G_MARE', 'RENTA', 'Plan AA junio (prorrata)', 500.0, 'renta efectiva 600'),
  (2026, 11, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, '1.614,80 - 1.414,22'),
  (2026, 12, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, NULL),
  (2026, 1, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, 'financiación ene-oct 2026'),
  (2026, 2, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 3, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 4, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 5, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 6, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 7, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 8, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 9, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 10, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 1, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 2, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 3, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 4, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 5, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 6, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 7, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 8, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 9, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 10, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 12, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi');

commit;
-- 006_alertas.sql — alertas del dashboard (backfill: ya aplicada en producción el 15/07/2026,
-- se reconstruye aquí para que el repo refleje el estado real de la base).
--   · listings.aviso_fecha / aviso_nota: fecha límite dura por propiedad (contratos).
--   · v_alertas: colchón de break-even < 10 pp, meses en negativo, avisos de contrato ≤ 90 días.

alter table listings add column if not exists aviso_fecha date;
alter table listings add column if not exists aviso_nota  text;

create or replace view v_alertas as
select
  'breakeven'::text as tipo,
  codigo,
  case when colchon < 0 then 'critical' else 'warning' end as severidad,
  case when colchon < 0
       then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
       else 'Colchón ajustado: solo ' || translate(to_char(colchon*100, 'FM990.0'), '.', ',')
            || ' pp por encima del equilibrio ('
            || translate(to_char(ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
  end as mensaje
from v_breakeven_ytd
where colchon is not null and colchon < 0.10

union all

select
  'mes_negativo'::text as tipo,
  codigo,
  'warning' as severidad,
  count(*) || ' mes(es) con margen neto negativo este año' as mensaje
from v_pnl_neto_propiedad
where anio = extract(year from now())::int and margen_neto < 0
group by codigo

union all

select
  'contrato'::text as tipo,
  codigo,
  case when (aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end as severidad,
  coalesce(aviso_nota, 'Aviso de contrato') || ' — fecha límite '
    || to_char(aviso_fecha, 'DD/MM/YYYY')
    || ' (faltan ' || (aviso_fecha - current_date) || ' días)' as mensaje
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

grant select on v_alertas to anon, authenticated;
-- 007_v2_fase1.sql — SQL de la Fase 1 del Dashboard CEO v2 (flujo portada → alerta → ficha ALEX → simulador).
--   1) v_propiedades: parámetros NO sensibles por propiedad. El simulador necesita modelo /
--      renta_base / comision_pct y hoy ninguna vista los expone; propietario, NIF e IBAN quedan fuera.
--   2) v_alertas v2: columnas estructuradas al final (clase, fecha_limite, dias_restantes) para
--      countdown y cascada del titular. Las 4 primeras columnas no cambian: el front v1 sigue vivo
--      entre la migración y el deploy.
--   3) v_freshness: honestidad del dato — last_sync + hasta qué mes hay costes manuales cargados
--      (los events están precargados hacia adelante; max(mes) dice hasta dónde llega la proyección).

-- 1) Parámetros por propiedad (sin datos personales) ───────────────────────────
create or replace view v_propiedades as
select codigo, modelo, fecha_inicio, renta_base, comision_pct, aviso_fecha, aviso_nota
from listings;

-- 2) v_alertas v2 — alerta = tiene fecha límite; señal = condición persistente sin fecha ──
create or replace view v_alertas as
select
  'breakeven'::text as tipo,
  codigo,
  case when colchon < 0 then 'critical' else 'warning' end as severidad,
  case when colchon < 0
       then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
       else 'Colchón ajustado: solo ' || translate(to_char(colchon*100, 'FM990.0'), '.', ',')
            || ' pp por encima del equilibrio ('
            || translate(to_char(ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
  end as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_breakeven_ytd
where colchon is not null and colchon < 0.10

union all

select
  'mes_negativo'::text as tipo,
  codigo,
  'warning' as severidad,
  count(*) || ' mes(es) con margen neto negativo este año' as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_pnl_neto_propiedad
where anio = extract(year from now())::int and margen_neto < 0
group by codigo

union all

select
  'contrato'::text as tipo,
  codigo,
  case when (aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end as severidad,
  coalesce(aviso_nota, 'Aviso de contrato') || ' — fecha límite '
    || to_char(aviso_fecha, 'DD/MM/YYYY')
    || ' (faltan ' || (aviso_fecha - current_date) || ' días)' as mensaje,
  'alerta'::text as clase,
  aviso_fecha    as fecha_limite,
  (aviso_fecha - current_date) as dias_restantes
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

-- 3) Frescura del dato ─────────────────────────────────────────────────────────
create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)          as last_sync,
  (select max(make_date(anio, mes, 1)) from events)       as costes_cargados_hasta;

grant select on v_propiedades, v_freshness to anon, authenticated;
grant select on v_alertas to anon, authenticated;
-- 008_lockdown_vistas.sql — cerrar la fuga de las vistas internas del motor (hallazgo crítico
-- de la revisión adversarial, 16/07/2026).
--
-- Problema: los default privileges de Supabase auto-otorgan SELECT a anon/authenticated sobre
-- CADA vista nueva de public, anulando el modelo whitelist declarado en 002_rls.sql. Resultado
-- verificado en producción: v_reservation_income respondía a la anon key con host_payout y
-- pasivo_madre por reserva (515 filas) — exactamente lo que 002 promete que nunca viaja al front.
--
-- Fix: revocar las vistas internas y dejar GRANT explícito solo en las vistas del dashboard.
-- v_reservation_nights queda expuesta A PROPÓSITO (§3 de la spec: grano noche para heatmap,
-- MTD del titular y lista de reservas; sin PII) — hasta ahora funcionaba solo por el default.
-- ⚠ Regla operativa a futuro: toda vista nueva nace pública por el default privilege → si no
-- va al dashboard, revocarla en la misma migración que la crea.

revoke select on
  v_reservation_income,
  v_nights_monthly,
  v_bookings_monthly,
  v_month_spine,
  v_samavi_gen_mensual
from anon, authenticated;

grant select on v_reservation_nights to anon, authenticated;

-- Fix menor (hallazgo de la misma revisión): singular del countdown embebido en el mensaje.
create or replace view v_alertas as
select
  'breakeven'::text as tipo,
  codigo,
  case when colchon < 0 then 'critical' else 'warning' end as severidad,
  case when colchon < 0
       then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
       else 'Colchón ajustado: solo ' || translate(to_char(colchon*100, 'FM990.0'), '.', ',')
            || ' pp por encima del equilibrio ('
            || translate(to_char(ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
  end as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_breakeven_ytd
where colchon is not null and colchon < 0.10

union all

select
  'mes_negativo'::text as tipo,
  codigo,
  'warning' as severidad,
  count(*) || ' mes(es) con margen neto negativo este año' as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_pnl_neto_propiedad
where anio = extract(year from now())::int and margen_neto < 0
group by codigo

union all

select
  'contrato'::text as tipo,
  codigo,
  case when (aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end as severidad,
  coalesce(aviso_nota, 'Aviso de contrato') || ' — fecha límite '
    || to_char(aviso_fecha, 'DD/MM/YYYY')
    || case when (aviso_fecha - current_date) = 0 then ' (vence hoy)'
            when (aviso_fecha - current_date) = 1 then ' (falta 1 día)'
            else ' (faltan ' || (aviso_fecha - current_date) || ' días)' end as mensaje,
  'alerta'::text as clase,
  aviso_fecha    as fecha_limite,
  (aviso_fecha - current_date) as dias_restantes
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

grant select on v_alertas to anon, authenticated;
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
-- 010_gastos_generales_vigencia.sql — (Stag, 16/07/2026) los gastos generales pueden tener
-- vigencia: Brand Partners es 500 €/mes desde may-2026 "hasta nuevo aviso" (el setup de
-- 1.400 € NO existió). Modelarlo como evento año a año repetiría el gotcha ene-2027 de la
-- renta de ALEX (se cargó solo nov–dic y en enero desaparece): un recurrente sin fin va en
-- general_expenses con fecha de inicio, no en events.
--   · general_expenses.desde / .hasta (null = sin límite por ese lado).
--   · v_samavi_gen_mensual solo suma las líneas vigentes en cada mes.
--   · Se eliminan los eventos Brand Partners (setup + ongoing may–dic): quedaban duplicados.

alter table general_expenses add column if not exists desde date;
alter table general_expenses add column if not exists hasta date;

delete from events where propiedad_codigo = 'SAMAVI_GEN' and concepto like 'Brand Partners%';

insert into general_expenses (concepto, importe_mes, desde)
select 'Brand Partners (marketing)', 500.00, date '2026-05-01'
where not exists (select 1 from general_expenses where concepto = 'Brand Partners (marketing)');

create or replace view v_samavi_gen_mensual as
select m.anio, m.mes,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
from (select distinct anio, mes from v_month_spine) m;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SYNC PRODUCCIÓN 17/07/2026 — estado CONCILIADO contra Revolut + BBVA + tarjeta
-- (ene–jun 2026). Sustituye los valores de arriba; fuente de verdad = producción.
-- ═══════════════════════════════════════════════════════════════════════════════

update listings set suministros_mes = 150, comunidad_ibi_mes = 331.12, amenities = 30,
  guesty_fee = 30, extras = 30 where codigo = '1A_NICA';           -- extras = trastero Box2box
update listings set suministros_mes = 150, amenities = 30 where codigo = '4B_ALEX';
update listings set amenities = 30 where codigo = '3G_MARE';
update listings set suministros_mes = 0, amenities = 34.58, extras = 0 where codigo = '1A_JACO';

delete from general_expenses;
insert into general_expenses (concepto, importe_mes, desde, hasta) values
  ('Sueldo Stag bruto', 3333.33, NULL, NULL),
  ('Brand Partners (marketing)', 500.00, date '2026-05-01', NULL),   -- efectivo/Argentina: no sale en bancos
  ('TGSS RETA Stag', 370.75, NULL, NULL),
  ('Orange (fibra pisos + dispositivos)', 329.80, NULL, NULL),       -- promedio real ene–jun
  ('Viajes corporativos', 200.00, NULL, NULL),                       -- cubre el día a día Revolut; viajes grandes = eventos
  ('Asesor Confisic', 181.50, NULL, NULL),
  ('Claude.ai (plan 90)', 90.00, date '2026-06-01', NULL),
  ('Otros AEAT/admin', 50.00, NULL, NULL),
  ('Revolut Business cuota', 43.00, NULL, NULL),
  ('Seguro vida préstamo (Allianz 499,51/año)', 41.63, date '2026-05-01', NULL),
  ('Seguro RC', 18.25, NULL, NULL),
  ('Google Workspace', 15.94, NULL, NULL),
  ('Hostinger', 12.74, NULL, NULL);                                  -- pago anual 152,87 (feb) devengado

delete from events;
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 1, '1A_NICA', 'OTROS', 'Comunidad extra + Ayuntamiento (IBI plazos)', -385.09, '32,32+243,94+108,83'),
  (2026, 1, '1A_NICA', 'OTROS', 'Mobiliario aplazado (Paypal 3 plazos)', -105.82, NULL),
  (2026, 1, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, 'financiación ene-oct 2026'),
  (2026, 1, '4B_ALEX', 'OTROS', 'Termo eléctrico (J.E. Cabrera)', -450.00, 'confirmado Stag 17/07: es de Alexander (compra enero, distinta del Ariston/Obramat de abril compensado por Alberto)'),
  (2026, 1, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, 'ene-mar 2026'),
  (2026, 2, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 2, '1A_NICA', 'OTROS', 'Derrama forjado 50% (Segovia 8)', -765.00, 'recibo 25/02'),
  (2026, 2, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'BLT Law — 6ª y última cuota gestores anteriores', -584.89, 'deuda saldada, no se repite'),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viajes tarjeta (ITA/Booking/Iberia)', -1447.64, 'tarjeta 0084, adeudo 05/03'),
  (2026, 3, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 3, '1A_NICA', 'OTROS', 'Comunidad extra', -34.25, NULL),
  (2026, 3, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -20.00, 'barrido 17/07'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Orange amortización equipos (tarjeta)', -460.78, 'payoff dispositivos, no está en la línea mensual'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Servicio digital web (N. Casale)', -159.60, 'puntual'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viaje por carretera (Hertz/hotel/gasolina/peajes)', -600.73, 'tarjeta 0084, adeudo 06/04'),
  (2026, 4, '1A_JACO', 'OTROS', 'Mantenimiento termo Ariston (Concesionario)', -258.94, 'cuota mantenimiento'),
  (2026, 4, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 4, '1A_NICA', 'OTROS', 'IBI/tributos NRC + Ayuntamiento', -1141.60, '1.031,67+109,93'),
  (2026, 4, '3G_MARE', 'OTROS', 'Aire acondicionado (Nico Chaban, Fc 235)', -1754.50, 'compensado vía descuentos de renta may/jun'),
  (2026, 4, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 4, '4B_ALEX', 'OTROS', 'Termo Ariston 4B (Obramat + instalación, neto IVA)', -383.06, 'compensado 383,06 por Alberto vía facturas may/jun (mail 18/05)'),
  (2026, 4, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -219.22, '38,25+82,29+98,68'),
  (2026, 5, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 5, '1A_NICA', 'OTROS', 'Comunidad extra', -30.25, NULL),
  (2026, 5, '3G_MARE', 'RENTA', 'Plan AA mayo (renta total descontada)', 1100.00, 'renta efectiva 0'),
  (2026, 5, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 5, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'termo 1/2: crédito base 191,53 (efecto caja 195,36 con IVA/IRPF); pagado 1.222,69'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Asesoría laboral (J.A. Mateos)', -159.00, 'consulta puntual'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -110.59, '20,59+90,00'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Curso fiscalidad (Hotmart)', -747.04, 'formación empresa'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Notaría escritura préstamo (Herrand)', -379.26, 'gasto del préstamo prefabricada'),
  (2026, 6, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 6, '1A_NICA', 'OTROS', 'Forjado pago 1/2', -382.50, 'recibo 24/06'),
  (2026, 6, '3G_MARE', 'RENTA', 'Plan AA + compensación aire acondicionado (renta pagada: 365,50)', 734.50, 'renta efectiva 600'),
  (2026, 6, '3G_MARE', 'OTROS', 'Refacturación 50% inscripción registral', -218.22, 'a J.L. De La Torre 19/06'),
  (2026, 6, '4B_ALEX', 'OTROS', 'Klarna-Sklum cancelación anticipada mobiliario', -472.28, 'salda jul–oct (4×162,77=651,08) con descuento; confirmado Stag 17/07'),
  (2026, 6, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 6, '4B_ALEX', 'RENTA', 'Termo descuento renta', 199.19, 'termo 2/2 + ajuste técnico -3,83 regularizado; pagado 1.215,03'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Intereses préstamo BBVA (prefabricada)', -158.45, 'amortización 923,78 excluida: devolución de deuda'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viajes tarjeta (Enjoy Travel)', -66.04, 'adeudo esperado jul'),
  (2026, 7, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 7, '1A_NICA', 'OTROS', 'Forjado pago 2/2', -382.50, 'confirmado Stag; verificar en extracto jul'),
  (2026, 8, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 9, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 10, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, '1.614,80 - 1.414,22; desde nov queda 1.614,80 hasta nuevo aviso'),
  (2026, 12, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 12, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, NULL);
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
-- ═══ AJUSTES 21/07/2026 — clasificación del bucket de compras (decisión Stag) ═══
-- 1) Compras hogar/reposición de los pisos → TODO a Nicasio (eventos reales por mes).
--    Amazon + Día Madrid + Ideal Home + ferretería + Zara Home + El Corte Inglés + etc.
--    Barrido 23/07/2026: cargos <20€ ene–may incorporados (ene nuevo; mar/abr ampliados).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -50.01, 'Día Madrid 17,23 + Mp Día 16,89 + Ikea 15,89; barrido 23/07'),
  (2026, 2, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -226.05, 'Amazon 75,80 + Ideal Home 20,45 + Ferretería 46,30 + flores 83,50'),
  (2026, 3, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -162.33, 'Amazon 129,98 + Día Madrid 21,64 + Día Madrid 10,71 (barrido 23/07)'),
  (2026, 4, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -374.41, 'Amazon 34,41 + Zara Home 178,05 + Rituals 50,90 + Velas 33,90 + Mm 26,90 + barrido 23/07: Día Madrid 16,92 + Home Ideal 13,95 + Casa Soria 10,04 + Ferretería Hoyos 9,34'),
  (2026, 5, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -424.46, 'Amazon 160,93 + El Corte Inglés 128,90 + Día Madrid 76,90 + H&M 29,98 + Ideal Home 27,75'),
  (2026, 6, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -813.15, 'Amazon 731,00 + Día Madrid 39,71 + Ideal Home 15,95 + Bricochayta 16,50 + Hiperhogar 9,99');

-- 2) La provisión de amenities de los pisos de Madrid se reemplaza por lo real (arriba):
--    a 0 para no contar dos veces. Jacobine mantiene su 34,58 (Día SEVILLA, ya separado).
update listings set amenities = 0 where codigo in ('1A_NICA', '4B_ALEX', '3G_MARE');

-- 3) Lavandería My Laundry = secadas de José Modesto para Jacobine.
--    Serie ene–jun completa (barrido 23/07); enero sin cargos.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 2, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -4.50, '4,50; barrido 23/07'),
  (2026, 3, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -9.00, '4,50+4,50; barrido 23/07'),
  (2026, 4, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -8.00, '4,50+3,50; barrido 23/07'),
  (2026, 5, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -13.00, '4,50+3,50+5,00; barrido 23/07'),
  (2026, 6, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -16.00, '6+6+4; serie ene–jun completa (ene sin cargos)');

-- 3b) Dudas del barrido resueltas por Stag 23/07: ambas a Jacobine.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_JACO', 'OTROS', 'Papelería carteles instructivos (Folder)', -4.00, 'material carteles del piso, impreso por Stag con tarjeta de José; confirmado Stag 23/07'),
  (2026, 2, '1A_JACO', 'OTROS', 'Amenities Natura Sevilla Sierpes', -33.80, 'compra puntual amenities; confirmado Stag 23/07');

-- 4) Comidas de negocio (Uber Eats/Glovo/restaurantes) → gasto general.
--    Serie ene–jun completa (barrido 23/07); ene/mar/abr sin cargos ("Licencia 431" es taxi, MCC 4121).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -37.69, 'Uber Eats 16,74 + Café Bistro Nuncio 4,35 + Mina Coffee 16,60; barrido 23/07'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -15.38, 'Uber Eats 15,38; barrido 23/07'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -167.26, 'Uber Eats 45,22 + Glovo 13,54 + Irish Rover 25 + Pavlov 13,50 + Campo Simbólico 70; serie ene–jun completa (ene/mar/abr sin cargos, Licencia 431 es taxi)');
-- 012_cuadre.sql — /cuadre: el motor se verifica a sí mismo (roadmap 22/07/2026;
-- reemplaza los "chequeos aleatorios" que propuso Fede por validación automática).
-- Una fila por chequeo: el front SOLO renderiza — la definición de "cuadrar" vive acá.
--   · estado: 'ok' | 'alerta' | 'info' (info = dato de contexto, no pasa/falla)
--   · esperado/obtenido: los dos caminos del cálculo; unidad dice cómo formatear.
--   · Tolerancias: 0,05 € en sumas redondeadas una vez; 0,50 € donde el redondeo se
--     acumula por fila (cuotas por propiedad-mes, canal por propiedad-canal).
-- Regla 008: vista nueva nace pública por default privileges → GRANT explícito.
-- No expone PII: solo agregados, contadores y fechas de proceso.

create or replace view v_cuadre as
with a as (select extract(year from now())::int as anio),
mensual as (
  select coalesce(sum(ingreso_samavi), 0)         as ingreso,
         coalesce(sum(ingreso_noches), 0)         as ingreso_noches,
         coalesce(sum(ingreso_cancelaciones), 0)  as cancelaciones,
         coalesce(sum(margen_directo), 0)         as margen_directo
  from v_pnl_mensual_propiedad where anio = (select anio from a)
),
kpi    as (select ingreso_samavi_ytd, margen_neto_ytd from v_kpis),
oh     as (select coalesce(sum(overhead), 0) as total from v_samavi_gen_mensual where anio = (select anio from a)),
cuotas as (select coalesce(sum(cuota_samavi_gen), 0) as suma from v_pnl_neto_propiedad where anio = (select anio from a)),
canal  as (select coalesce(sum(ingreso), 0) as ingreso from v_canal_ytd),
fisica as (select count(*) as n from v_pnl_mensual_propiedad where noches > dias_mes),
ilegibles as (
  select count(*) as n from reservations r
  where r.status in ('confirmed', 'checked_in', 'checked_out')
    and (r.checkin_local is null or r.checkout_local is null or r.checkout_local <= r.checkin_local)
),
sync as (
  select last_run, round((extract(epoch from (now() - last_run)) / 3600)::numeric, 1) as horas
  from sync_state where id = 1
),
conc as (select max(make_date(anio, mes, 1)) as hasta from events where concepto ilike '%real bancos%')
select * from (
  select 1 as orden, 'ingreso_ytd' as chequeo,
    'El ingreso YTD es la suma de los meses' as titulo,
    case when abs(m.ingreso - k.ingreso_samavi_ytd) <= 0.05 then 'ok' else 'alerta' end as estado,
    round(m.ingreso, 2) as esperado, k.ingreso_samavi_ytd as obtenido, 'eur' as unidad,
    'Suma mensual por propiedad vs la tarjeta de la portada.' as detalle
  from mensual m, kpi k
  union all
  select 2, 'margen_neto_ytd', 'Margen neto = margen directo − overhead',
    case when abs(k.margen_neto_ytd - (m.margen_directo - o.total)) <= 0.05 then 'ok' else 'alerta' end,
    round(m.margen_directo - o.total, 2), k.margen_neto_ytd, 'eur',
    'La cascada completa (prorrateo incluido) devuelve el mismo total que la resta directa.'
  from mensual m, kpi k, oh o
  union all
  select 3, 'prorrateo_overhead', 'El overhead prorrateado suma el 100 %',
    case when abs(-c.suma - o.total) <= 0.5 then 'ok' else 'alerta' end,
    round(o.total, 2), round(-c.suma, 2), 'eur',
    'Las cuotas por propiedad reconstruyen el pool de gastos generales, sin perder ni duplicar.'
  from cuotas c, oh o
  union all
  select 4, 'canal_vs_ingreso', 'El mix por canal cuadra con el ingreso por noches',
    case when abs(cn.ingreso - m.ingreso_noches) <= 0.5 then 'ok' else 'alerta' end,
    round(m.ingreso_noches, 2), round(cn.ingreso, 2), 'eur',
    'Los canales suman el ingreso devengado por noche; las cancelaciones retenidas van aparte.'
  from canal cn, mensual m
  union all
  select 5, 'cancelaciones_aparte', 'Ingreso = noches + cancelaciones retenidas',
    case when abs(m.ingreso - (m.ingreso_noches + m.cancelaciones)) <= 0.01 then 'ok' else 'alerta' end,
    round(m.ingreso, 2), round(m.ingreso_noches + m.cancelaciones, 2), 'eur',
    'La línea separada de cancelaciones no toca noches, ocupación ni ADR.'
  from mensual m
  union all
  select 6, 'ocupacion_fisica', 'Ningún mes con más noches que días',
    case when f.n = 0 then 'ok' else 'alerta' end,
    0, f.n, 'casos',
    'Noches devengadas ≤ días del mes, en todas las propiedades.'
  from fisica f
  union all
  select 7, 'reservas_ilegibles', 'Todas las reservas activas son contables',
    case when i.n = 0 then 'ok' else 'alerta' end,
    0, i.n, 'casos',
    'Una reserva confirmada sin fechas válidas quedaría fuera del devengo sin avisar.'
  from ilegibles i
  union all
  select 8, 'sync_guesty', 'Datos de Guesty al día',
    case when s.horas <= 6 then 'ok' else 'alerta' end,
    6, s.horas, 'horas',
    'El sync corre cada 3 h; más de 6 h sin correr es un problema, no un retraso.'
  from sync s
  union all
  select 9, 'conciliacion_bancos', 'Conciliado contra bancos',
    'info',
    null::numeric, extract(month from c.hasta)::numeric, 'mes',
    'Último mes con gastos reales de bancos cargados (ritual de cierre mensual).'
  from conc c
) checks
order by orden;

grant select on v_cuadre to anon, authenticated;

-- ═══ MIGRACIÓN 013 (24/07/2026) — base de comisión al bruto post-descuento ═══
-- 013_jacobine_base_comision.sql — base de comisión al bruto POST-descuento.
-- Contexto (24/07/2026, verificado contra los PDF de Airbnb de Jacobine): el `bruto` guardado
-- (fareAccommodation + fareCleaning) es PRE-descuento. Cuando una reserva tiene descuento
-- (estadía larga/oferta), Guesty reduce el cobro real pero nuestro `bruto` queda inflado.
-- Como el ingreso de los pisos en comisión (solo JACO) = comision_pct × bruto, eso
-- sobreestimaba el Ingreso Samavi de Jacobine (2026: 947,48 € de descuentos → 286,61 € de más).
-- El bruto REAL cobrado = host_payout + host_service_fee (idéntico al `bruto` en reservas sin
-- descuento; menor cuando hay descuento). Es la misma base que usa Guesty (host_payout +
-- host_channel_fee). Fix quirúrgico: SOLO cambia la base de comisión. Titular/subarriendo
-- (NICA/ALEX/MARE) corren sobre host_payout y NO se tocan. `bruto` (ADR/RevPAR) se deja igual.
-- NOTA: sin grant — 008 revocó anon sobre esta vista (exponía host_payout por reserva);
-- create or replace preserva los privilegios, así que no se reabre la fuga.

create or replace view v_reservation_income as
select
  r.id, r.codigo, r.checkin_local, r.checkout_local, r.source, r.status,
  coalesce(r.bruto, 0)       as bruto,
  coalesce(r.host_payout, 0) as host_payout,
  l.modelo,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else coalesce(r.host_payout,0) end                                    as ingreso_samavi,
  case when l.modelo = 'comision'
       then coalesce(r.host_payout,0) - (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else 0 end                                                            as pasivo_madre
from reservations r
join listings l on l.codigo = r.codigo
where r.status in ('confirmed','checked_in','checked_out')
  and r.checkin_local is not null and r.checkout_local is not null
  and r.checkout_local > r.checkin_local;

-- ═══ MIGRACIÓN 014 (24/07/2026) — vista de conciliación Guesty↔Airbnb ═══
-- 014_conciliacion_airbnb.sql — vista de conciliación mensual Guesty ↔ Airbnb.
-- Verificado 24/07/2026 contra los 6 PDF oficiales de Airbnb (ene–jun 2026, las 4 propiedades):
-- el payout de Guesty reconcilia AL CÉNTIMO con el "Total" del informe de ingresos de Airbnb,
-- una vez que se atribuye por fecha de PAGO (check-in + ~1 día, como paga Airbnb) y se suman
-- las cancelaciones con cobro retenido (Airbnb las paga; el motor las cuenta en línea aparte,
-- v_ingreso_cancelaciones). Uso: comparar payout_total_airbnb por (codigo, anio, mes) contra
-- el "Total" del PDF del mes. Los canales no-Airbnb (Booking, directas) van por fuera.
-- Interna (ops/cierre mensual): REVOKE — expone payout agregado por propiedad/mes.

create or replace view v_conciliacion_airbnb as
select
  r.codigo,
  extract(year  from (r.checkin_local + interval '1 day'))::int as anio,
  extract(month from (r.checkin_local + interval '1 day'))::int as mes,
  count(*) filter (where r.status <> 'canceled')                                  as reservas,
  round(coalesce(sum(r.host_payout) filter (where r.status <> 'canceled'),0), 2)  as payout_confirmado,
  round(coalesce(sum(r.host_payout) filter (where r.status = 'canceled'),0), 2)   as payout_cancelado_retenido,
  round(sum(r.host_payout), 2)                                                     as payout_total_airbnb
from reservations r
where r.source = 'airbnb2'
  and r.checkin_local is not null
  and (r.status in ('confirmed','checked_in','checked_out')
       or (r.status = 'canceled' and coalesce(r.host_payout,0) <> 0))
group by r.codigo,
  extract(year from (r.checkin_local + interval '1 day')),
  extract(month from (r.checkin_local + interval '1 day'));

revoke all on v_conciliacion_airbnb from anon, authenticated;
