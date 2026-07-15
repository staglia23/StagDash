-- apply_all.sql — pegar TODO en Supabase SQL Editor y ejecutar (schema, rls, views, métricas, seed).
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
  ('Otros AEAT/admin', 50.0),
  ('Brand Partners (marketing)', 500.0);

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
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, 'inicio mayo'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 7, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 8, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 9, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 10, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 11, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 12, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners ongoing', -500.0, NULL),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Brand Partners setup', -1400.0, 'one-time mayo'),
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
