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
  -- 'Viajes corporativos (transporte)' eliminado 25/07: fantasma; los viajes reales entran como eventos conciliados
  ('Asesor Confisic', 181.50, NULL, NULL),
  ('Claude.ai (plan 90)', 90.00, date '2026-06-01', NULL),
  -- 'Otros AEAT/admin' eliminado 25/07: fantasma; los gastos reales entran como eventos conciliados
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
  (2026, 6, '3G_MARE', 'OTROS', 'Refacturación 50% inscripción registral', -218.22, 'al dueño de MARE 19/06'),
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

-- ═══ MIGRACIÓN 015 (24/07/2026) ═══
-- 015 — código de confirmación del canal (Airbnb HMxxxx, etc.) por reserva.
-- Habilita el cruce 1:1 Guesty ↔ reporte de transacciones de Airbnb (clave única,
-- sin depender de monto/fecha). Lo llena el sync (guesty-sync v4+); backfill vía re-sync.
alter table reservations add column if not exists confirmation_code text;
create index if not exists idx_reservations_conf on reservations (confirmation_code);

-- ═══ MIGRACIÓN 016 (24/07/2026) ═══
-- 016 — tablas de ingesta para la conciliación a tres puntas (Fase 2).
-- Internas (ops): REVOKE anon/authenticated. No guardan nombres de huéspedes (PII):
-- el cruce se hace por confirmation_code, no por nombre.

-- Lado CAJA: depósitos bancarios (Airbnb y otros).
create table if not exists bank_deposits (
  id         bigint generated always as identity primary key,
  banco      text not null,               -- 'revolut' | 'bbva'
  iban       text,                         -- '7165' | '8920'
  fecha      date not null,
  importe    numeric(12,2) not null,       -- + entrada / − salida
  concepto   text,
  es_airbnb  boolean default false,
  archivo    text,                          -- para recargar por archivo sin duplicar
  cargado_at timestamptz default now()
);
create index if not exists idx_bank_dep_fecha on bank_deposits (banco, fecha);

-- Lado FISCAL/pago: reporte de transacciones de Airbnb (IBAN destino + fecha de llegada).
create table if not exists airbnb_tx (
  id                bigint generated always as identity primary key,
  tipo              text not null,          -- 'Payout' | 'Reserva' | 'Resolucion'
  fecha             date not null,
  fecha_llegada     date,                   -- llegada estimada al banco (Payout)
  confirmation_code text,                   -- HMxxxx (Reserva) → cruza con reservations
  iban              text,                   -- '7165' | '8920' (Payout)
  alojamiento       text,
  inicio            date,
  fin               date,
  noches            int,
  cobrado           numeric(12,2),          -- monto del payout
  importe           numeric(12,2),          -- ganancia del anfitrión (Reserva)
  comision_servicio numeric(12,2),
  limpieza          numeric(12,2),
  bruto             numeric(12,2),
  anio_fiscal       int,
  archivo           text,
  cargado_at        timestamptz default now()
);
create index if not exists idx_airbnb_tx_conf   on airbnb_tx (confirmation_code);
create index if not exists idx_airbnb_tx_payout on airbnb_tx (fecha_llegada, cobrado);

revoke all on bank_deposits from anon, authenticated;
revoke all on airbnb_tx     from anon, authenticated;

-- ═══ MIGRACIÓN 017 (24/07/2026) ═══
-- 017 — v_cuadre_banco: conciliación bancaria para el panel de /cuadre (Fase 3).
-- Por cuenta (7165 Revolut = Nica+Jaco · 8920 BBVA = Alex+Mare) y mes:
--   airbnb_pago  = lo que Airbnb pagó (desde Guesty, v_conciliacion_airbnb; = el PDF).
--   banco_recibio = depósitos de Airbnb que entraron (bank_deposits).
--   diferencia_acum = acumulado banco − airbnb → el "en tránsito" neto; debe quedarse chico.
-- Restringida al PERÍODO con extractos cargados (para que el acumulado no se contamine con
-- meses sin banco). Vista de panel (agregada, sin PII ni IBAN completo) → GRANT anon.

create or replace view v_cuadre_banco as
with rango as (
  select date_trunc('month', min(fecha))::date as desde,
         date_trunc('month', max(fecha))::date as hasta
  from bank_deposits where es_airbnb
),
airbnb as (
  select case when codigo in ('1A_NICA','1A_JACO') then '7165' else '8920' end as iban,
         anio, mes, sum(payout_total_airbnb) as airbnb_pago
  from v_conciliacion_airbnb
  where make_date(anio, mes, 1) between (select desde from rango) and (select hasta from rango)
  group by 1, anio, mes
),
banco as (
  select iban,
         extract(year  from fecha)::int as anio,
         extract(month from fecha)::int as mes,
         sum(importe) as banco_recibio, count(*) as depositos
  from bank_deposits
  where es_airbnb
  group by iban, extract(year from fecha)::int, extract(month from fecha)::int
),
j as (
  select coalesce(a.iban, b.iban) as iban,
         coalesce(a.anio, b.anio) as anio,
         coalesce(a.mes,  b.mes)  as mes,
         round(coalesce(a.airbnb_pago, 0), 2)   as airbnb_pago,
         round(coalesce(b.banco_recibio, 0), 2) as banco_recibio,
         coalesce(b.depositos, 0) as depositos
  from airbnb a
  full outer join banco b on a.iban = b.iban and a.anio = b.anio and a.mes = b.mes
)
select
  iban,
  case iban when '7165' then 'Revolut · Nicasio + Jacobine'
            when '8920' then 'BBVA · Alexander + Marechal'
            else iban end as cuenta,
  anio, mes, airbnb_pago, banco_recibio, depositos,
  round(banco_recibio - airbnb_pago, 2) as diferencia_mes,
  round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2) as diferencia_acum
from j
order by iban, anio, mes;

grant select on v_cuadre_banco to anon, authenticated;

-- ═══ MIGRACIÓN 018 (24/07/2026) ═══
-- 018 — caché del token de Guesty en sync_state (dura 24h → no pedir en cada corrida).
-- Evita el rate-limit del endpoint de token: se pide uno nuevo solo cuando el cacheado venció.
-- Lo usa guesty-sync v6+.
alter table sync_state add column if not exists guesty_token     text;
alter table sync_state add column if not exists guesty_token_exp timestamptz;

-- ═══ MIGRACIÓN 019 (25/07/2026) ═══
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

-- ═══ MIGRACIÓN 020 (25/07/2026) ═══
create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)            as last_sync,
  (select max(make_date(anio, mes, 1)) from events)         as costes_cargados_hasta,
  (select max(date_trunc('month', fecha))::date
     from bank_deposits)                                    as cierre_hasta;

grant select on v_freshness to anon, authenticated;

-- ═══ MIGRACIÓN 021 (25/07/2026) ═══
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

-- ═══ MIGRACIÓN 022 (25/07/2026) ═══
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

-- ═══ MIGRACIÓN 023 (25/07/2026) ═══
update events
   set propiedad_codigo = '1A_NICA',
       concepto = 'Termo eléctrico Nicasio (J.E. Cabrera)'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes = 1
   and categoria = 'OTROS' and concepto like 'Termo eléctrico (J.E. Cabrera)%';

update events
   set propiedad_codigo = '3G_MARE',
       categoria        = 'OTROS',
       concepto         = 'Mobiliario Marechal (Sequra, última cuota mar-2026)'
 where propiedad_codigo = 'SAMAVI_GEN' and anio = 2026 and mes in (1, 2, 3)
   and categoria = 'SAMAVI_GEN' and concepto = 'Sequra';

-- NOTA PARA EL CIERRE (no aplicada — pendiente de verificación bancaria):
-- La compensación del termo de Alexander se cargó como +191,53 (mayo) y +199,19 (junio), en
-- euros TRANSFERIDOS. La factura descuenta 191,53 sobre la BASE, y una base que baja 191,53
-- hace bajar la transferencia 191,53 × 1,02 = 195,36. O sea, los dos números solo pueden ser
-- correctos a la vez si en mayo se transfirieron 1.222,69 € (descontando el importe de base
-- del giro habitual) y no los 1.218,86 € del total de la factura. El mail del 18/05 apunta a
-- eso ("ajuste técnico de 3,83 € a tu favor… en Junio recibirás 1.215,03 €"), y 3,83 = 2 % de
-- 191,53. Si el extracto de mayo dice 1.218,86 € (el total de la factura), entonces mayo debe
-- pasar a +195,36 y queda un descuadre de 3,83 € por explicar. El total de los dos meses
-- (390,72 €) es correcto en cualquiera de los dos escenarios.

-- ═══ MIGRACIÓN 025 (25/07/2026) — estructura de tres capas ═══
alter table general_expenses add column if not exists es_corporativo boolean not null default false;

-- events.categoria tenía un CHECK cerrado a RENTA/OTROS/SAMAVI_GEN (001_schema).
-- Se abre a CORPORATIVO manteniendo la garantía de que no entren categorías sueltas.
alter table events drop constraint if exists events_categoria_check;
alter table events add  constraint events_categoria_check
  check (categoria = any (array['RENTA', 'OTROS', 'SAMAVI_GEN', 'CORPORATIVO']));

update general_expenses set es_corporativo = true
 where concepto in ('Brand Partners (marketing)',
                    'Seguro vida préstamo (Allianz 499,51/año)');

-- Los eventos corporativos salen de SAMAVI_GEN a su propia categoría.
update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN'
   and concepto in ('BLT Law — 6ª y última cuota gestores anteriores',
                    'Notaría escritura préstamo (Herrand)',
                    'Intereses préstamo BBVA (prefabricada)',
                    'Curso fiscalidad (Hotmart)',
                    'Servicio digital web (N. Casale)');

-- ── 2) Días bajo gestión: la nueva base de reparto ──────────────────────────────
-- Días del mes en que la propiedad ya estaba en cartera. Un piso que entra el 20 de octubre
-- solo carga 12 días de overhead de octubre, no el mes entero.
create or replace function dias_gestion(p_inicio date, p_anio int, p_mes int)
returns int language sql immutable as $$
  select case
    when p_inicio is null then days_in_month(p_anio, p_mes)
    when date_trunc('month', p_inicio) > make_date(p_anio, p_mes, 1) then 0
    when date_trunc('month', p_inicio) = make_date(p_anio, p_mes, 1)
      then days_in_month(p_anio, p_mes) - extract(day from p_inicio)::int + 1
    else days_in_month(p_anio, p_mes)
  end;
$$;

create or replace view v_dias_gestion as
select s.codigo, s.anio, s.mes, dias_gestion(l.fecha_inicio, s.anio, s.mes) as dias
from v_month_spine s join listings l on l.codigo = s.codigo;

revoke all on v_dias_gestion from anon, authenticated;   -- andamiaje interno

-- ── 3) El pool mensual se parte en operativo y corporativo ──────────────────────
create or replace view v_samavi_gen_mensual as
select m.anio, m.mes,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where not g.es_corporativo
      and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria = 'SAMAVI_GEN' and e.anio = m.anio and e.mes = m.mes), 0) as overhead,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where g.es_corporativo
      and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria = 'CORPORATIVO' and e.anio = m.anio and e.mes = m.mes), 0) as corporativo
from (select distinct anio, mes from v_month_spine) m;

-- ── 4) P&L mensual por propiedad: overhead por días de gestión ──────────────────
-- ⚑ Las columnas van ENUMERADAS, no con p.*: esta vista se creó en 003 con un p.* que quedó
--   congelado en 22 columnas, así que las que 009/021/022 añadieron a v_pnl_mensual_propiedad
--   nunca llegaron hasta acá. Con p.* un create or replace explota ("cannot change name of
--   view column"). Enumerar deja el orden bajo control y evita que vuelva a pasar.
create or replace view v_pnl_neto_propiedad as
with tot as (select anio, mes, sum(dias) as tot_dias from v_dias_gestion group by anio, mes)
select
  p.codigo, p.anio, p.mes, p.dias_mes, p.bruto, p.ingreso_samavi, p.comision_aparente,
  p.noches, p.reservas, p.ocup_pct, p.adr, p.revpar, p.alos,
  p.renta, p.limpieza, p.suministros, p.comunidad, p.otros,
  p.total_gastos_directos, p.margen_directo,
  round(-g.overhead * (dg.dias::numeric / nullif(t.tot_dias, 0)), 2)                    as cuota_samavi_gen,
  round(p.margen_directo - g.overhead * (dg.dias::numeric / nullif(t.tot_dias, 0)), 2)  as margen_neto,
  round(p.margen_directo, 2)                                                            as contribucion
from v_pnl_mensual_propiedad p
join v_dias_gestion dg      on dg.codigo = p.codigo and dg.anio = p.anio and dg.mes = p.mes
join tot t                  on t.anio = p.anio and t.mes = p.mes
join v_samavi_gen_mensual g on g.anio = p.anio and g.mes = p.mes;

-- ── 5) Ranking YTD: misma base ──────────────────────────────────────────────────
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
dias as (
  select codigo, sum(dias) as dias
  from v_dias_gestion where anio = extract(year from now())::int group by codigo
),
oh as (select coalesce(sum(overhead), 0) as total from v_samavi_gen_mensual where anio = extract(year from now())::int),
td as (select coalesce(sum(dias), 0) as t from dias)
select
  y.codigo, y.ingreso_samavi, y.bruto, y.noches, y.reservas, y.noches_disponibles,
  y.gastos_directos, y.margen_directo,
  round(-(select total from oh) * (d.dias::numeric / nullif((select t from td), 0)), 2) as cuota_samavi_gen,
  round(y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0)), 2) as margen_neto,
  case when y.ingreso_samavi > 0
       then round((y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0))) / y.ingreso_samavi, 4)
       else 0 end as margen_neto_pct,
  case when y.noches > 0
       then round((y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0))) / y.noches, 2)
       else 0 end as eur_noche_neto,
  case when y.noches_disponibles > 0 then round(y.noches::numeric / y.noches_disponibles, 4) else 0 end as ocup_pct,
  case when y.noches > 0 then round(y.bruto / y.noches, 2) else 0 end as adr,
  case when y.noches_disponibles > 0 then round(y.bruto / y.noches_disponibles, 2) else 0 end as revpar,
  y.ingreso_cancelaciones,
  round(y.iva_repercutido, 2) as iva_repercutido,
  round(y.margen_directo, 2)  as contribucion,
  case when y.ingreso_samavi > 0 then round(y.margen_directo / y.ingreso_samavi, 4) else 0 end as contribucion_pct
from ytd y join dias d on d.codigo = y.codigo
order by margen_neto desc;

-- ── 6) KPIs: margen_neto_ytd pasa a ser el RESULTADO DE SAMAVI (tras corporativos) ──
-- Es lo que de verdad ganó el negocio, y es lo que titula la portada. El desglose por capas
-- queda en las columnas nuevas.
create or replace view v_kpis as
with corp as (
  select coalesce(sum(corporativo), 0) as total
  from v_samavi_gen_mensual where anio = extract(year from now())::int
)
select
  round(sum(r.margen_neto) - (select total from corp), 2)                                       as margen_neto_ytd,
  round(sum(r.ingreso_samavi), 2)                                                               as ingreso_samavi_ytd,
  round(sum(r.bruto), 2)                                                                        as bruto_ytd,
  sum(r.noches)                                                                                 as noches_ytd,
  sum(r.noches_disponibles)                                                                     as noches_disponibles_ytd,
  case when sum(r.noches_disponibles) > 0 then round(sum(r.noches)::numeric / sum(r.noches_disponibles), 4) else 0 end as ocupacion_ytd,
  case when sum(r.noches) > 0 then round(sum(r.bruto) / sum(r.noches), 2) else 0 end            as adr_ytd,
  case when sum(r.noches_disponibles) > 0 then round(sum(r.bruto) / sum(r.noches_disponibles), 2) else 0 end as revpar_ytd,
  case when sum(r.ingreso_samavi) > 0
       then round((sum(r.margen_neto) - (select total from corp)) / sum(r.ingreso_samavi), 4) else 0 end as margen_neto_pct_ytd,
  (select last_run from sync_state where id = 1)                                                as last_sync,
  round(sum(r.margen_neto), 2)                                                                  as margen_operativo_ytd,
  round((select total from corp), 2)                                                            as corporativo_ytd,
  round(sum(r.margen_directo), 2)                                                               as contribucion_ytd
from v_ranking_ytd r;

-- ── 7) Tendencia mensual: coherente con el KPI (incluye corporativos) ───────────
create or replace view v_trend_mensual as
select p.anio, p.mes,
  round(sum(p.ingreso_samavi), 2)                                        as ingreso_samavi,
  round(sum(p.margen_directo), 2)                                        as margen_directo,
  round(sum(p.margen_neto) - max(g.corporativo), 2)                      as margen_neto,
  round(max(g.corporativo), 2)                                           as corporativo
from v_pnl_neto_propiedad p
join v_samavi_gen_mensual g on g.anio = p.anio and g.mes = p.mes
group by p.anio, p.mes
order by p.anio, p.mes;

-- ── 8) Margen asegurado hacia adelante: misma base de reparto ───────────────────
create or replace view v_margen_asegurado as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0) as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0) as ev_otros
  from events group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    dias_gestion(l.fecha_inicio, s.anio, s.mes)           as dias_gest,
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
  round(b.bruto, 2)                                       as bruto,
  round(b.ingreso_noches + b.ingreso_cancelaciones, 2)    as ingreso_asegurado,
  b.noches                                                as noches_vendidas,
  round(b.noches::numeric / b.dias_mes, 4)                as ocup_vendida,
  round(b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as gastos_directos,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as margen_directo,
  round(-o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2)   as cuota_samavi_gen,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros
        - o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2)  as margen_neto
from base b
join oh  o on o.anio = b.anio and o.mes = b.mes
join tot t on t.anio = b.anio and t.mes = b.mes;

grant select on v_margen_asegurado to anon, authenticated;

-- ── 9) El puente de las tres capas, para /analisis ──────────────────────────────
create or replace view v_resultado_samavi as
with r as (
  select coalesce(sum(margen_directo), 0) as contribucion,
         coalesce(sum(cuota_samavi_gen), 0) as overhead_operativo,
         coalesce(sum(margen_neto), 0) as margen_operativo,
         coalesce(sum(ingreso_samavi), 0) as ingreso
  from v_ranking_ytd
),
c as (select coalesce(sum(corporativo), 0) as corporativo
      from v_samavi_gen_mensual where anio = extract(year from now())::int)
select
  round(r.ingreso, 2)                                as ingreso_samavi,
  round(r.contribucion, 2)                           as contribucion,
  round(-r.overhead_operativo, 2)                    as overhead_operativo,
  round(r.margen_operativo, 2)                       as margen_operativo,
  round(c.corporativo, 2)                            as costes_corporativos,
  round(r.margen_operativo - c.corporativo, 2)       as resultado_samavi
from r, c;

grant select on v_resultado_samavi to anon, authenticated;

-- ── 10) El cuadre aprende las tres capas ────────────────────────────────────────
-- Chequeo 2 pasa a validar la cascada COMPLETA (operativo + corporativo) y el 3 valida que
-- las cuotas reconstruyan el pool OPERATIVO. Se añade el 10: el puente de capas cierra.
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
oh     as (select coalesce(sum(overhead), 0) as total, coalesce(sum(corporativo), 0) as corp
           from v_samavi_gen_mensual where anio = (select anio from a)),
cuotas as (select coalesce(sum(cuota_samavi_gen), 0) as suma from v_pnl_neto_propiedad where anio = (select anio from a)),
capas  as (select contribucion, overhead_operativo, margen_operativo, costes_corporativos, resultado_samavi from v_resultado_samavi),
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
  select 2, 'margen_neto_ytd', 'Resultado = contribución − overhead − corporativos',
    case when abs(k.margen_neto_ytd - (m.margen_directo - o.total - o.corp)) <= 0.05 then 'ok' else 'alerta' end,
    round(m.margen_directo - o.total - o.corp, 2), k.margen_neto_ytd, 'eur',
    'La cascada de tres capas devuelve el mismo total que la resta directa.'
  from mensual m, kpi k, oh o
  union all
  select 3, 'prorrateo_overhead', 'El overhead operativo prorrateado suma el 100 %',
    case when abs(-c.suma - o.total) <= 0.5 then 'ok' else 'alerta' end,
    round(o.total, 2), round(-c.suma, 2), 'eur',
    'Las cuotas por días de gestión reconstruyen el pool operativo, sin perder ni duplicar.'
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
  union all
  select 10, 'puente_capas', 'Las tres capas cierran entre sí',
    case when abs((cp.contribucion - cp.overhead_operativo - cp.costes_corporativos) - cp.resultado_samavi) <= 0.05
         then 'ok' else 'alerta' end,
    round(cp.contribucion - cp.overhead_operativo - cp.costes_corporativos, 2), cp.resultado_samavi, 'eur',
    'Contribución − overhead de gestión − costes corporativos = resultado de Samavi.'
  from capas cp
) checks
order by orden;

grant select on v_cuadre to anon, authenticated;

-- ═══ MIGRACIÓN 026 (25/07/2026) ═══
update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN' and anio = 2026
   and concepto in ('Viajes tarjeta (ITA/Booking/Iberia)',
                    'Viaje por carretera (Hertz/hotel/gasolina/peajes)');

-- ═══ MIGRACIONES 026–028 (25/07/2026) ═══
update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN' and anio = 2026
   and concepto in ('Viajes tarjeta (ITA/Booking/Iberia)',
                    'Viaje por carretera (Hertz/hotel/gasolina/peajes)');

update events set categoria = 'CORPORATIVO' where categoria = 'SAMAVI_GEN' and anio = 2026 and concepto = 'Viajes tarjeta (Enjoy Travel)';

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

-- ═══ MIGRACIÓN 029 (25/07/2026) ═══
update events
   set propiedad_codigo = '3G_MARE', categoria = 'OTROS',
       concepto = 'TV Xiaomi de Marechal (Orange, pago anticipado del plazo)'
 where propiedad_codigo = 'SAMAVI_GEN' and anio = 2026 and mes = 3
   and concepto = 'Orange amortización equipos (tarjeta)';
update general_expenses set importe_mes = 271.67, concepto = 'Orange — móviles y dispositivos'
 where concepto = 'Orange — móviles, dispositivos y roaming';
insert into general_expenses (concepto, importe_mes, desde, hasta, es_corporativo)
select 'Roaming internacional (Orange)', 29.71, null, null, true
where not exists (select 1 from general_expenses where concepto = 'Roaming internacional (Orange)');


-- 030 — limpieza de alfombra de Marechal (Ecocleans F260176, abril): servicio puntual de
-- tapicería, coste directo de la propiedad. Va como event, no en limpieza_mensual.

insert into events (propiedad_codigo, anio, mes, categoria, concepto, importe)
select '3G_MARE', 2026, 4, 'OTROS', 'Limpieza de alfombra (Ecocleans F260176, servicio puntual)', -60.50
where not exists (
  select 1 from events where propiedad_codigo = '3G_MARE' and anio = 2026 and mes = 4
    and concepto like 'Limpieza de alfombra%');


-- 031 — la limpieza deja de estimarse: entra el coste real de Ecocleans por propiedad y mes.
-- La tabla limpieza_mensual es el punto de entrada de la conciliación (Apps Script), y
-- v_limpieza_mensual decide en un solo sitio si el motor usa el real o el estimado.

create table if not exists limpieza_mensual (
  anio         int  not null,
  mes          int  not null check (mes between 1 and 12),
  codigo       text not null references listings(codigo),
  servicios    int           not null default 0,
  horas        numeric(8,2)  not null default 0,
  limpieza_eur numeric(10,2) not null default 0,   -- horas × precio/hora
  kits_eur     numeric(10,2) not null default 0,   -- amenities
  renting_eur  numeric(10,2) not null default 0,   -- renting textil
  base_eur     numeric(10,2) not null default 0,
  iva_eur      numeric(10,2) not null default 0,
  factura      text,
  fiable       boolean       not null default true, -- la extracción cuadró con la factura
  cargado_at   timestamptz   not null default now(),
  primary key (anio, mes, codigo)
);

comment on table limpieza_mensual is
  'Coste real de limpieza por propiedad y mes. La escribe la conciliación de Ecocleans.';

revoke all on limpieza_mensual from anon, authenticated;

insert into limpieza_mensual
  (anio, mes, codigo, servicios, horas, limpieza_eur, kits_eur, renting_eur, base_eur, iva_eur, factura)
values
  (2026,  1,'1A_NICA',  8, 14.00, 229.60, 14.40,  92.32,  336.32,  70.63,'F260063'),
  (2026,  1,'4B_ALEX',  7, 10.50, 172.20, 12.60,  92.68,  277.48,  58.27,'F260063'),
  (2026,  1,'3G_MARE',  9, 13.50, 221.40, 16.20,  93.96,  331.56,  69.63,'F260063'),
  (2026,  2,'1A_NICA', 10, 20.25, 332.10, 18.00, 124.00,  474.10,  99.56,'F260090'),
  (2026,  2,'4B_ALEX',  7, 11.33, 185.81, 12.60, 111.28,  309.69,  65.03,'F260090'),
  (2026,  2,'3G_MARE',  7, 11.00, 180.40, 12.60,  73.08,  266.08,  55.88,'F260090'),
  (2026,  3,'1A_NICA',  7, 14.00, 229.60, 12.60,  73.08,  315.28,  66.21,'F260127'),
  (2026,  3,'4B_ALEX',  9, 12.00, 196.80, 16.20,  93.96,  306.96,  64.46,'F260127'),
  (2026,  3,'3G_MARE',  9, 12.17, 199.59, 16.20,  93.96,  309.75,  65.05,'F260127'),
  (2026,  4,'1A_NICA',  7, 14.25, 233.70, 12.60,  73.08,  319.38,  67.07,'F260156'),
  (2026,  4,'4B_ALEX',  9, 13.50, 221.40, 16.20, 103.76,  341.36,  71.69,'F260156'),
  (2026,  4,'3G_MARE', 10, 16.00, 262.40, 18.00, 104.40,  384.80,  80.81,'F260156'),
  (2026,  5,'1A_NICA',  7, 14.00, 229.60, 12.60,  92.68,  334.88,  70.32,'F260201'),
  (2026,  5,'4B_ALEX', 11, 15.00, 246.00, 19.80, 163.84,  429.64,  90.22,'F260201'),
  (2026,  5,'3G_MARE',  7, 10.50, 172.20, 12.60,  73.08,  257.88,  54.15,'F260201'),
  (2026,  6,'1A_NICA',  8, 16.00, 262.40, 14.40,  83.52,  360.32,  75.67,'F260506'),
  (2026,  6,'4B_ALEX',  9, 13.00, 213.20, 16.20, 122.36,  351.76,  73.87,'F260506'),
  (2026,  6,'3G_MARE',  7, 10.50, 172.20, 12.60,  73.08,  257.88,  54.15,'F260506')
on conflict (anio, mes, codigo) do nothing;

create or replace view v_limpieza_mensual as
select
  s.codigo, s.anio, s.mes,
  case when lm.codigo is not null
       then -(lm.base_eur + lm.iva_eur)
       else -(l.limpieza_por_reserva * coalesce(b.reservas, 0)) end as coste,
  case when lm.codigo is null      then 'estimado'
       when lm.fiable              then 'real'
       else                             'real_revisar' end          as fuente,
  lm.servicios, lm.horas, lm.factura
from v_month_spine s
join listings l                on l.codigo = s.codigo
left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
left join limpieza_mensual lm  on lm.codigo = s.codigo and lm.anio = s.anio and lm.mes = s.mes;

grant select on v_limpieza_mensual to anon, authenticated;

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
  limpieza_fuente
from final;

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
             else 1 end)                                                                    as renta,
    coalesce(lp.coste, -(l.limpieza_por_reserva * coalesce(b.reservas,0)))                   as limpieza,
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                    as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_limpieza_mensual lp     on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
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


-- 032 — el ADR deja de contar plata que nunca se cobró: bruto pasa a ser POST-promoción
-- (fareAccommodationAdjusted). Corrige el histórico desde money_raw; el sync va en v7.

update reservations r
   set bruto = round(
         coalesce((r.money_raw::jsonb->>'fareAccommodationAdjusted')::numeric,
                  (r.money_raw::jsonb->>'fareAccommodation')::numeric, 0)
       + coalesce((r.money_raw::jsonb->>'fareCleaning')::numeric, 0), 2)
 where r.money_raw is not null
   and (r.money_raw::jsonb->>'fareAccommodationAdjusted') is not null
   and abs(r.bruto - (
         coalesce((r.money_raw::jsonb->>'fareAccommodationAdjusted')::numeric, 0)
       + coalesce((r.money_raw::jsonb->>'fareCleaning')::numeric, 0))) > 0.005;


-- 033 — la comisión de canal deja de ser invisible (es el mayor coste directo: 18.764 € en 7
-- meses, por encima de la renta) + v_canales_mensual + se cierra la fuga de v_reservation_nights.

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

create or replace view v_noches_mtd as
select codigo, night, ingreso_samavi_night
from v_reservation_nights;

grant select on v_noches_mtd to anon, authenticated;
revoke all on v_reservation_nights from anon, authenticated;

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


-- 034 — los suministros dejan de ser un fijo inventado: entran las facturas reales de Confisic
-- (Total Energies, Galápago, Movistar), prorrateadas por día y solo los meses con cobertura completa.

create table if not exists suministros_mensual (
  anio         int  not null,
  mes          int  not null check (mes between 1 and 12),
  codigo       text not null references listings(codigo),
  luz_eur      numeric(10,2) not null default 0,   -- luz + gas, con IVA
  internet_eur numeric(10,2) not null default 0,
  total_eur    numeric(10,2) not null default 0,
  fiable       boolean       not null default true,
  nota         text,
  cargado_at   timestamptz   not null default now(),
  primary key (anio, mes, codigo)
);

comment on table suministros_mensual is
  'Coste real de suministros por propiedad y mes, prorrateado por día. Solo meses con cobertura completa.';

revoke all on suministros_mensual from anon, authenticated;

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '1A_NICA', 159.69,  0.00, 159.69, true,  'Luz+gas TotalEnergies, contrato dual a nombre de la sociedad'),
  (2026, 2, '1A_NICA', 138.70,  0.00, 138.70, true,  null),
  (2026, 3, '1A_NICA', 106.95,  0.00, 106.95, true,  null),
  (2026, 4, '1A_NICA',  82.44,  0.00,  82.44, true,  'Gas con consumo 0 kWh: solo término fijo (~83 €/año)'),
  (2026, 2, '4B_ALEX', 126.92, 27.50, 154.42, false, 'Internet: reparto hipotético 27,50 de los 55,00 de Movistar'),
  (2026, 3, '4B_ALEX',  92.58, 27.50, 120.08, false, 'Internet: reparto hipotético'),
  (2026, 4, '4B_ALEX',  68.63, 27.50,  96.13, false, 'Internet: reparto hipotético'),
  (2026, 5, '4B_ALEX',  76.36, 27.50, 103.86, false, 'Internet: reparto hipotético'),
  (2026, 6, '4B_ALEX',  89.08, 27.50, 116.58, false, 'Internet: reparto hipotético'),
  (2026, 2, '3G_MARE',  96.43, 27.50, 123.93, false, 'Internet: reparto hipotético'),
  (2026, 3, '3G_MARE',  76.07, 27.50, 103.57, false, 'Internet: reparto hipotético'),
  (2026, 5, '3G_MARE',  61.24, 27.50,  88.74, false, 'Internet: reparto hipotético'),
  (2026, 6, '3G_MARE',  77.69, 27.50, 105.19, false, 'Internet: reparto hipotético')
on conflict (anio, mes, codigo) do nothing;

create or replace view v_suministros_mensual as
select
  s.codigo, s.anio, s.mes,
  case when sm.codigo is not null then -sm.total_eur
       else -l.suministros_mes end                                as coste,
  case when sm.codigo is null then 'estimado'
       when sm.fiable          then 'real'
       else                         'real_revisar' end            as fuente,
  sm.luz_eur, sm.internet_eur, sm.nota
from v_month_spine s
join listings l              on l.codigo = s.codigo
left join suministros_mensual sm on sm.codigo=s.codigo and sm.anio=s.anio and sm.mes=s.mes;

grant select on v_suministros_mensual to anon, authenticated;

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
    (sp.coste + coalesce(ev.ev_suministros,0))                                              as suministros,
    sp.fuente                                                                               as suministros_fuente,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  join v_limpieza_mensual lp          on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
  join v_suministros_mensual sp       on sp.codigo=s.codigo and sp.anio=s.anio and sp.mes=s.mes
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
  round(comision_canal_samavi, 2) as comision_canal_samavi,
  suministros_fuente
from final;

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
             else 1 end)                                                                    as renta,
    coalesce(lp.coste, -(l.limpieza_por_reserva * coalesce(b.reservas,0)))                   as limpieza,
    (coalesce(sp.coste, -l.suministros_mes) + coalesce(ev.ev_suministros,0))                 as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_limpieza_mensual lp     on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
  left join v_suministros_mensual sp  on sp.codigo=s.codigo and sp.anio=s.anio and sp.mes=s.mes
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


-- 035 — reparto de Movistar confirmado por Stag: linea barata (25,00) a Alexander, cara (30,00)
-- a Marechal. Deja de ser hipotesis.
update suministros_mensual set internet_eur = 25.00, total_eur = round(luz_eur + 25.00, 2), fiable = true
 where codigo = '4B_ALEX' and anio = 2026 and internet_eur = 27.50;
update suministros_mensual set internet_eur = 30.00, total_eur = round(luz_eur + 30.00, 2), fiable = true
 where codigo = '3G_MARE' and anio = 2026 and internet_eur = 27.50;


-- 036 — la linea de Orange se abre en sus partes: moviles, apps y cuotas de dispositivos, estas
-- ultimas CON FECHA DE FIN (el forward asumia que se pagan para siempre).

update general_expenses
   set importe_mes = 137.04,
       concepto    = 'Orange — móviles corporativos'
 where concepto = 'Orange — móviles y dispositivos';

insert into general_expenses (concepto, importe_mes, desde, hasta, es_corporativo)
select * from (values
  ('Apps y servicios de terceros (Apple vía Orange)', 36.63, null::date, null::date,       false),
  ('iPhone + AirPods a plazos (Orange)',              79.05, null::date, '2027-10-31'::date, false),
  ('Apple Watch Ultra a plazos (Orange)',             18.95, null::date, '2026-12-31'::date, false)
) as v(concepto, importe_mes, desde, hasta, es_corporativo)
where not exists (select 1 from general_expenses g where g.concepto = v.concepto);


-- 037 — v_costes_ytd expone comision_canal (la que soporta Samavi), para que el simulador
-- pueda calcular el punto de equilibrio de la captación por canal directo.
-- (Cuerpo repuesto el 29/07/2026 desde producción — pg_get_viewdef; hasta entonces solo
-- estaba el comentario y un rebuild desde este archivo dejaba la vista sin comision_canal.)

create or replace view v_costes_ytd as
with ytd as (
  select codigo,
         sum(renta)                 as renta,
         sum(limpieza)              as limpieza,
         sum(suministros)           as suministros,
         sum(comunidad)             as comunidad,
         sum(otros)                 as otros,
         sum(total_gastos_directos) as total_directos,
         sum(ingreso_samavi)        as ingreso,
         sum(renta_iva)             as renta_iva,
         sum(comision_canal_samavi) as comision_canal_samavi
    from v_pnl_mensual_propiedad
   where anio = extract(year from now())::int
   group by codigo
)
select
  y.codigo,
  round(-y.renta, 2)                                 as renta,
  round(-y.limpieza, 2)                              as limpieza,
  round(-y.suministros, 2)                           as suministros,
  round(-y.comunidad, 2)                             as comunidad,
  round(-y.otros, 2)                                 as otros,
  round(-y.total_directos, 2)                        as total_directos,
  round(-r.cuota_samavi_gen, 2)                      as overhead,
  round(-(y.total_directos + r.cuota_samavi_gen), 2) as total_costes,
  case when y.ingreso > 0
       then round((-(y.total_directos + r.cuota_samavi_gen)) / y.ingreso, 4)
       else 0 end                                    as pct_sobre_ingreso,
  round(-y.renta_iva, 2)                             as renta_iva,
  round(y.comision_canal_samavi, 2)                  as comision_canal
from ytd y
join v_ranking_ytd r on r.codigo = y.codigo;

grant select on v_costes_ytd to anon, authenticated;


-- 038 — el enero de Marechal deja de ser estimado. Las tres facturas de papernest (contrato
-- 65221, CUPS ES0022000007651514DE1P = 3º G) venían a nombre personal de Stag, por eso no se
-- habían cruzado con el piso en la 034. Prorrateo por día: 11 días de la PPN 26000007553
-- (82,25) + 20 días de la PPN 26000020088 (154,48) = 236,73 € de luz. Enero de 4B_ALEX sigue
-- en estimado: no hay factura del comercializador anterior y el alta en TotalEnergies es del
-- 05/02/2026.
insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '3G_MARE', 236.73, 30.00, 266.73, true,
   'Luz: papernest/Galapago contrato 65221 (PPN 26000007553 + PPN 26000020088), prorrateo por dia, IVA incluido. Facturas a nombre personal de Stag: refacturacion a SAMAVI pendiente. Internet: linea cara de Movistar (24,79 base -> 30,00 c/IVA).')
on conflict (anio, mes, codigo) do nothing;


-- 039 — enero de Alexander, parcial. TotalEnergies 1NSN260200213697 (CUPS ...519XG1P = 4º B,
-- titular personal de Stag) cubre 24.01–05.02: 8 días de enero = 51,93 €. Del 01 al 23/01 el
-- suministro era del titular anterior (Alberto), ~149 € sin factura ni reembolso → va como
-- `fiable = false` para que la vista lo etiquete `real_revisar`, no como mes cerrado.
insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '4B_ALEX', 51.93, 25.00, 76.93, false,
   'PARCIAL: solo 24-31/01 (TotalEnergies 1NSN260200213697, 77,89 EUR / 12 dias, prorrateo por dia, IVA incluido). Del 01 al 23/01 el CUPS estaba a nombre del titular anterior (Alberto): ~149 EUR sin factura ni reembolso, pendiente de confirmar. Factura a nombre personal de Stag: refacturacion a SAMAVI pendiente. Internet: linea barata de Movistar (20,66 base -> 25,00 c/IVA).')
on conflict (anio, mes, codigo) do nothing;


-- 040 — mayo y junio de Nicasio. El ciclo bimensual del contrato dual (luz+gas) hacía que la
-- 034 no tuviera factura desde el 11.05; ya se emitió. TotalEnergies además desdualizó el
-- contrato en julio: desde ahora la luz va mensual y el gas bimensual, como ALEX y MARE.
-- mayo  = luz 89,00 (11.03-11.05 + 12.05-11.06) + gas 8,01  =  97,01
-- junio = luz 113,47 (12.05-11.06 + 12.06-12.07) + gas 8,36 = 121,83
insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 5, '1A_NICA',  97.01, 0.00,  97.01, true,
   'Luz 89,00 (11.03-11.05 1NSN260500251449 + 12.05-11.06 aviso 18/07) + gas 8,01 (11.03-08.05 + 09.05-09.07 aviso 15/07). Prorrateo por dia, IVA incluido. PDF de julio pendiente de archivar en Confisic.'),
  (2026, 6, '1A_NICA', 121.83, 0.00, 121.83, true,
   'Luz 113,47 (12.05-11.06 aviso 18/07 + 12.06-12.07 aviso 20/07) + gas 8,36 (09.05-09.07 aviso 15/07). Prorrateo por dia, IVA incluido. PDF de julio pendiente de archivar en Confisic.')
on conflict (anio, mes, codigo) do nothing;


-- 041 — la nota del termo de enero de Nicasio decía "es de Alexander" (nota vieja que la 023 no
-- actualizó al reimputarlo). El importe y la propiedad estaban bien.
update events
   set notas = 'confirmado Stag 17/07: ES DE NICASIO y es coste propio de Samavi. Reimputado desde 4B_ALEX por la migracion 023. Distinto del Ariston/Obramat de abril (383,06), que si es de Alexander y lo reembolso Alberto.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 1
   and categoria = 'OTROS' and concepto = 'Termo eléctrico Nicasio (J.E. Cabrera)'
   and notas like '%es de Alexander%';


-- 042 — auditoría de Nicasio. El evento de abril eran dos cosas: 109,93 de IBI real (cuota 02
-- del fraccionamiento, verificada contra la Carpeta Tributaria) y 1.031,67 de IRPF PERSONAL de
-- Stag pagado por error desde la cuenta de empresa. El IRPF del socio no es gasto de la
-- sociedad: sale del P&L y queda a compensar en cuenta con el socio (vía Confisic).
-- Y de las compras de hogar de junio salen 145,80 € de auriculares de oficina (plazo 1/3), que
-- son herramienta de trabajo y van al overhead operativo, no a reposición de piso.
-- Nicasio mejora 1.177,47 € en el semestre.
update events
   set importe  = -109.93,
       concepto = 'IBI plazo (fraccionamiento 2025, cuota 02)',
       notas    = 'FRA/2025/01001446325 cuota 02 del 06/04/26, verificado contra la Carpeta Tributaria. Los 1.031,67 que estaban aca eran IRPF personal de Stag pagado por error desde la cuenta de empresa: no es gasto de la sociedad, queda a compensar en cuenta con el socio (regularizacion via Confisic).'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 4
   and categoria = 'OTROS' and concepto = 'IBI/tributos NRC + Ayuntamiento'
   and importe = -1141.60;

update events
   set importe = -667.35,
       notas   = 'Amazon 585,20 (10 pedidos - 1 reembolso, sin los 145,80 de los auriculares de oficina) + Dia Madrid 39,71 + Ideal Home 15,95 + Bricochayta 16,50 + Hiperhogar 9,99'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 6
   and categoria = 'OTROS' and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -813.15;

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Auriculares oficina (Amazon, plazo 1/3)', -145.80,
       'Amazon.es 23/06 MCC 5732. Herramienta de trabajo, no reposicion de piso; confirmado Stag 26/07. Faltan los plazos 2/3 y 3/3 (145,80 c/u) en los cierres de julio y agosto.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 6 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Auriculares oficina (Amazon, plazo 1/3)');


-- 043 — la comisión de Booking no llegaba al P&L. Booking cobra "payment by the property": el
-- huésped paga el BRUTO al alojamiento y Booking factura su comisión aparte, así que
-- host_payout = bruto y `bruto − ingreso_samavi` da cero. Factura 1657524585: comisión 150,02 +
-- 21 % IVA 31,50 = 181,52 €, domiciliada en Revolut ...7165. PARCHE por reserva: el motor sigue
-- sin entender el modelo de Booking y ya hay dos reservas más confirmadas para agosto.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 6, '1A_NICA', 'OTROS', 'Comisión Booking.com (factura 1657524585)', -181.52,
       'Reserva BC-qpY7JQDO7, 25-28/06. Comision 150,02 + 21% IVA 31,50. Booking cobra aparte porque la huesped pago el bruto directo (882,48 el 16/06): host_payout = bruto y el motor no descontaba nada. Domiciliado en Revolut ...7165, vencimiento 16/07. PARCHE: quedan BC-68wENnWVl (agosto, 216,92) y BC-jg7mnkyGW (agosto-septiembre, 250,03) sin cubrir.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 6 and e.propiedad_codigo = '1A_NICA'
     and e.concepto = 'Comisión Booking.com (factura 1657524585)');


-- 044 — al aire acondicionado de Marechal le faltaban 80 €. La intervención costó 1.834,50
-- (factura 235 de Nico Chaban 1.754,50 + 80,00 a Claudio en efectivo, sin factura) y eso es
-- exactamente lo compensado en las rentas de mayo y junio; el motor tenía la compensación
-- completa pero sólo el coste de Chaban. Confirmado por Stag: los 80 € los puso Samavi.
-- Y se corrige la nota del evento de renta de junio, que decía "renta efectiva 600" cuando la
-- renta transferida fueron 365,50 (verificado en el extracto de Revolut del 08/06).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 4, '3G_MARE', 'OTROS', 'Reparación y pintura tras el A/C (Claudio, efectivo)', -80.00,
       'Segundo tramo de la intervencion del aire acondicionado: 1.754,50 (factura 235 Nico Chaban) + 80,00 (Claudio, portero, en efectivo) = 1.834,50, que es exactamente lo compensado en las rentas de mayo y junio. Sin factura formal; pagado en efectivo por Samavi, confirmado por Stag 26/07/2026.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 4 and e.propiedad_codigo = '3G_MARE'
     and e.concepto = 'Reparación y pintura tras el A/C (Claudio, efectivo)');

update events
   set notas = 'Renta transferida: 365,50 el 08/06, verificado en el extracto de Revolut. Compensacion 734,50 del plan de aire acondicionado acordado con Jose Luis el 21/04 y aceptado el 04/05.'
 where propiedad_codigo = '3G_MARE' and anio = 2026 and mes = 6
   and categoria = 'RENTA' and notas like '%renta efectiva 600%';


-- 045 — avisos con fecha: costes que cambian en una fecha conocida. `general_expenses` tiene
-- vigencia para que el motor DEJE de contar un coste, pero eso no sirve para avisar de uno que
-- SUBE. Estrena con la promoción de Movistar (vence 27/10/2026: el internet de Marechal pasa de
-- 30,00 a 40,00 €/mes). Ventana de 120 días, más ancha que los 90 del aviso de contrato, porque
-- un cambio de precio hay que verlo con tiempo para renegociarlo.
create table if not exists avisos (
  id           bigserial primary key,
  codigo       text not null references listings(codigo),
  fecha        date not null,
  tipo         text not null default 'aviso',
  mensaje      text not null,              -- la consecuencia, SIN la fecha: la vista la añade
  impacto_mes  numeric(12,2),              -- € al mes que cambian (negativo = el coste sube)
  nota         text,
  unique (codigo, fecha, mensaje)
);

comment on table avisos is
  'Cambios de coste con fecha conocida. Alimenta v_alertas; no lo consume el motor de P&L.';

revoke all on avisos from anon, authenticated;

insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '3G_MARE', date '2026-10-27', 'promocion',
       'Vence la promoción de Movistar: el internet pasa de 30,00 a 40,00 €/mes', -10.00,
       'Linea 9142***84 (Fibra 600 Mb). Descuento actual 8,2644 EUR de base = 10,00 con IVA. Factura FMPVAFJ001. La linea ...89 de Alexander tiene otra promocion de 12 meses sin fecha visible en la factura: mirar en Mi Movistar (salto de 25,00 a 36,00).'
where not exists (select 1 from avisos a where a.codigo='3G_MARE' and a.fecha=date '2026-10-27');

-- La vista suma un cuarto tipo. Los tres existentes quedan idénticos.
create or replace view v_alertas as
select 'breakeven'::text as tipo, b.codigo,
       case when b.colchon < 0 then 'critical' else 'warning' end as severidad,
       case when b.colchon < 0
            then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
            else 'Colchón ajustado: solo ' || translate(to_char(b.colchon*100, 'FM990.0'), '.', ',')
                 || ' pp por encima del equilibrio ('
                 || translate(to_char(b.ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
       end as mensaje,
       'senal'::text as clase, null::date as fecha_limite, null::integer as dias_restantes
from v_breakeven_ytd b
where b.colchon is not null and b.colchon < 0.10

union all

select 'mes_negativo'::text, p.codigo, 'warning',
       count(*) || ' mes(es) con margen neto negativo este año',
       'senal'::text, null::date, null::integer
from v_pnl_neto_propiedad p
where p.anio = extract(year from now())::int and p.margen_neto < 0
group by p.codigo

union all

select 'contrato'::text, l.codigo,
       case when (l.aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end,
       coalesce(l.aviso_nota, 'Aviso de contrato') || ' — fecha límite '
         || to_char(l.aviso_fecha, 'DD/MM/YYYY')
         || case when (l.aviso_fecha - current_date) = 0 then ' (vence hoy)'
                 when (l.aviso_fecha - current_date) = 1 then ' (falta 1 día)'
                 else ' (faltan ' || (l.aviso_fecha - current_date) || ' días)' end,
       'alerta'::text, l.aviso_fecha, l.aviso_fecha - current_date
from listings l
where l.aviso_fecha is not null and l.aviso_fecha >= current_date
  and (l.aviso_fecha - current_date) <= 90

union all

select a.tipo, a.codigo,
       case when (a.fecha - current_date) <= 30 then 'critical' else 'warning' end,
       a.mensaje || ' — fecha límite ' || to_char(a.fecha, 'DD/MM/YYYY')
         || case when (a.fecha - current_date) = 0 then ' (vence hoy)'
                 when (a.fecha - current_date) = 1 then ' (falta 1 día)'
                 else ' (faltan ' || (a.fecha - current_date) || ' días)' end,
       'alerta'::text, a.fecha, a.fecha - current_date
from avisos a
where a.fecha >= current_date and (a.fecha - current_date) <= 120;

grant select on v_alertas to anon, authenticated;


-- 046 — abril de Marechal, el último mes estimado del semestre. La factura que faltaba
-- (1NSN260500255032, 12.04–11.05) estaba en la carpeta de mayo. Luz de abril = 7,36 (días 1–3)
-- + 30,78 (días 12–30) = 38,14 €. El hueco del 4 al 11 es real: TotalEnergies no facturó esos
-- 8 días — 79 kWh de diferencia entre las lecturas de cierre y apertura del contador 40088848,
-- unos 15,60 €. Va como fiable = false por si lo regularizan más adelante.
insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 4, '3G_MARE', 38.14, 30.00, 68.14, false,
   'Luz: 7,36 (1NSN260400331958, abril 1-3) + 30,78 (1NSN260500255032, abril 12-30), prorrateo por dia, IVA incluido. TotalEnergies NO facturo del 4 al 11 de abril: 79 kWh de diferencia entre las lecturas de cierre (04.04) y apertura (12.04) del contador 40088848, unos 15,60 EUR. Si lo regularizan mas adelante, corresponde a abril. Internet: linea cara de Movistar.')
on conflict (anio, mes, codigo) do nothing;


-- 047 — una cancelada sin cobro no es un cobro retenido. `host_payout <> 0` no equivale a
-- "hubo plata": en una reserva MANUAL de Guesty el payout se copia del precio aunque nadie
-- pague. Dos fantasmas de dic-2025 (JACO GY-maaMEbuB 85,50 y NICA GY-nc72xAQr 200,00) sumaban
-- 285,50 € de ingreso inventado. No se filtra sólo por `total_paid` porque Airbnb adjudica la
-- retención al cancelar y la paga el día del check-in original (MARE HMA2CS9HZB, ago-2026, es
-- un derecho de cobro real todavía sin pagar). De paso, la base de comisión se alinea con la
-- migración 013: bruto POST-descuento (`host_payout + host_service_fee`), no `bruto`.
-- `create or replace` y no `drop ... cascade`: de acá cuelgan v_pnl_mensual_propiedad y
-- v_margen_asegurado. Efecto en el año en curso: ninguno.
create or replace view v_ingreso_cancelaciones as
select
  r.codigo,
  extract(year  from r.checkin_local)::int  as anio,
  extract(month from r.checkin_local)::int  as mes,
  sum(case when l.modelo = 'comision'
           then (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0))
                * l.comision_pct / (1 + l.iva_pct)
           else coalesce(r.host_payout, 0) end)                                as ingreso_cancelaciones,
  count(*)                                                                      as reservas_canceladas,
  sum(case when l.modelo = 'comision'
           then (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0))
                * l.comision_pct * (1 - 1 / (1 + l.iva_pct))
           else 0 end)                                                          as iva_cancelaciones
from reservations r
join listings l on l.codigo = r.codigo
where r.status = 'canceled'
  and r.checkin_local is not null
  and (
        coalesce(r.total_paid, 0) <> 0
     or (r.source <> 'manual' and coalesce(r.host_payout, 0) <> 0)
      )
group by r.codigo,
         extract(year  from r.checkin_local),
         extract(month from r.checkin_local);

grant select on v_ingreso_cancelaciones to anon;


-- 048 — amenities reales de Jacobine. Era la última línea estimada del semestre: 34,58 €/mes de
-- provisión fija heredados del modelo pre-auditoría (a las otras tres, la 031 les puso el dato
-- real de Ecocleans y les dejó la línea en cero; Jacobine quedó fuera porque la limpia José
-- Modesto, que compra los amenities él mismo). Relevamiento de los 6 extractos de Revolut
-- ene–jun filtrando DIA Sevilla 2271 y Mp**dia 22144: 175,44 € reales contra 207,48 € de
-- provisión. El total sobra 32,04 € pero el mes a mes estaba muy mal — enero y febrero no
-- tuvieron ni una compra y cargaban 34,58 cada uno; marzo gastó casi el doble. Además febrero
-- contaba dos veces: la compra real (Natura Sierpes, 33,80) ya era un evento y la provisión iba
-- encima. Mismo criterio que 031 y 034: provisión a cero, gasto real como evento mensual.
update listings set amenities = 0 where codigo = '1A_JACO';

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, '1A_JACO', 'OTROS', 'Amenities/consumibles Sevilla (DIA, real)', v.importe, v.notas
from (values
  (2026, 3, -67.53, 'Dia Sevilla 2271 45,94 del 02/03 (tarjeta Metal) + Mp**dia 22144 5,54 del 10/03 y 16,05 del 28/03 (tarjeta Standard de Jose Modesto). Extracto Revolut marzo 2026.'),
  (2026, 4, -28.92, 'Mp**dia 22144 10,19 del 12/04 + Dia Sevilla 2271 18,73 del 20/04, tarjeta Standard de Jose Modesto. Extracto Revolut abril 2026.'),
  (2026, 5, -34.82, 'Mp**dia 22144 4,54 del 01/05 + Dia Sevilla 2271 30,28 del 11/05, tarjeta Standard de Jose Modesto. Extracto Revolut mayo 2026.'),
  (2026, 6, -44.17, 'Dia Sevilla 2271 9,68 y 5,79 del 31/05 + 28,70 del 25/06, tarjeta Standard de Jose Modesto. Extracto Revolut junio 2026 (los cargos del 31/05 aparecen en el extracto de junio).')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Amenities/consumibles Sevilla (DIA, real)');

update events
   set notas = 'Natura Sevilla Sierpes 33,80 del 27/02, tarjeta Metal. Confirmado Stag 23/07. Es el UNICO gasto de amenities de febrero: hasta la migracion 048 convivia con la provision fija de 34,58, o sea que el mes contaba 68,38 habiendo gastado 33,80.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Amenities Natura Sevilla Sierpes';


-- 049 — la planilla manual de Stag contra el motor. Dos gastos de JACOBINE que Samavi ya se
-- cobró a la dueña (mini UPS 56,99 en feb, aspiradora 129,98 en mar) estaban cargados como coste
-- propio y en Nicasio: salen enteros. Una copia de llaves de 46,30 se reimputa de Nicasio a
-- Jacobine. Y entran 301,22 € que nunca pasaron por el banco (efectivo), sacados de las cuatro
-- listas de gastos de bolsillo del libro: Claudio 60,00 (ene) y 150,00 (mar) en Marechal, NRUA
-- 32,73 (Nicasio) y 28,67 (Alexander), y 82,22 de bolsillo en Jacobine.
-- 1) El mini UPS y la copia de llaves salen de las compras de hogar de Nicasio de febrero.
--    Quedan los 18,81 de la pasta de dientes + Ideal Home 20,45 + flores 83,50 = 122,76.
update events
   set importe = -122.76,
       notas   = 'Amazon 18,81 (pasta de dientes, 15/02) + Ideal Home 20,45 + Mon Parnasse flores 83,50. Salieron dos cosas que no eran de Nicasio: los 56,99 del Amazon del 12/02 eran el mini UPS de JACOBINE (56,99 + 20,00 de instalacion de Agustin = 77,00 que se le descontaron a la duena en su cuenta corriente, o sea coste neutro para Samavi), y los 46,30 de Ferreteria Diego de Leon eran la copia de llaves de JACOBINE segun la lista de gastos de bolsillo de Stag. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 2
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -226.05;

-- 2) La aspiradora sale de las compras de hogar de Nicasio de marzo.
--    Quedan los dos Día de Madrid: 21,64 + 10,71 = 32,35.
update events
   set importe = -32.35,
       notas   = 'Dia Madrid 21,64 + Dia Madrid 10,71. Los 129,98 del Amazon del 28/02 (liquidado el 01/03) eran la ASPIRADORA de JACOBINE: figura en la cuenta corriente de la duena como GASTOS 130,00 de marzo con la nota "aspiradora reposicion", o sea que Samavi ya se la cobro. Coste neutro: sale del P&L. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 3
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -162.33;

-- 3) La copia de llaves entra en Jacobine, que es donde se usó.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, '1A_JACO', 'OTROS', 'Copia de llaves (Ferretería Diego de León)', -46.30,
       'Cargo de 46,30 del 17/02 en el Revolut, tarjeta Metal. Estaba imputado a Nicasio por el barrido bancario del 23/07 (ferreteria de Madrid = compra de hogar de Madrid); la lista de gastos de bolsillo de Stag lo tiene en la columna de JACOBINE, "19/02/2026 copia de llaves". No se le descontó a la duena.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Copia de llaves (Ferretería Diego de León)');

-- 4) Lo pagado en efectivo, que nunca pasó por el banco.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, 'OTROS', v.concepto, v.importe, v.notas
from (values
  (2026, 1, '3G_MARE', 'Cristales (Claudio, efectivo)', -60.00,
   'Lista de gastos de bolsillo de Stag, "02/01/2026 cristales claudio". Claudio es el portero de Segovia 8. Pagado en efectivo, no pasa por el extracto: por eso el motor no lo veia. Tercer pago en efectivo a Claudio que aparece tarde (los otros 80,00 entraron por la migracion 044).'),
  (2026, 3, '3G_MARE', 'Arreglo de bañera (Claudio, efectivo)', -150.00,
   'Lista de gastos de bolsillo de Stag, "03/03/2026 arreglo banera claudio". Pagado en efectivo, sin factura, fuera del extracto.'),
  (2026, 2, '1A_NICA', 'NRUA — registro único de alojamiento', -32.73,
   'Lista de gastos de bolsillo de Stag, "24/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 2, '4B_ALEX', 'NRUA — registro único de alojamiento', -28.67,
   'Lista de gastos de bolsillo de Stag, "25/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 1, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -28.57,
   'Lista de gastos de bolsillo de Stag: "09/01/2026 amenities 28,57". Fuera del extracto. NO duplica la migracion 048, que solo cargo los cargos de DIA Sevilla del Revolut y enero no tenia ninguno. En la misma fecha hay 9,00 de "secadas diciembre" que NO se cargan: el devengo es de diciembre de 2025 y el motor esta fijado al ano en curso.'),
  (2026, 2, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -53.65,
   'Lista de gastos de bolsillo de Stag: ILSA 30,65 (menaje, 27/02) + amenities 10,00 (27/02) + secadas 8,50 (27/02) + secadas de enero 4,50 (pagadas el 05/02). Ninguno pasa por el extracto. La secada de 4,50 del 27/02 SI esta en el banco y ya estaba cargada aparte, no se repite aca.')
) as v(anio, mes, cod, concepto, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = v.cod
     and e.concepto = v.concepto);


-- 050 — dos respuestas de Stag rompen la 049: las secadas de su lista de bolsillo son la MISMA
-- plata que los cargos My Laundry del Revolut (estaban duplicadas, 13,00 €), e "ILSA" no era
-- menaje sino la operadora de los trenes iryo, o sea transporte → overhead corporativo.
-- 1) El evento de bolsillo de febrero se queda sólo con los amenities.
update events
   set importe  = -10.00,
       notas    = 'Amenities 10,00 del 27/02, de la lista de gastos de bolsillo de Stag; fuera del extracto. Salieron dos cosas que la 049 habia metido mal: las secadas (8,50 + 4,50) son la MISMA plata que los cargos My Laundry del Revolut que ya estaban cargados aparte —confirmado por Stag el 26/07, estaban duplicadas— y los 30,65 de "ILSA" no eran menaje sino un billete de tren de iryo (ILSA = Intermodalidad del Levante SA), que va al overhead corporativo, no a la propiedad.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Gastos de bolsillo (fuera de banco)'
   and importe = -53.65;

-- 2) El billete de iryo entra al overhead corporativo, que es donde Stag quiere el transporte.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, 'SAMAVI_GEN', 'CORPORATIVO', 'Tren iryo a Sevilla (ILSA, fuera de banco)', -30.65,
       'Lista de gastos de bolsillo de Stag, "27/02/2026 ILSA 30,65". ILSA = Intermodalidad del Levante SA, la operadora de iryo: es un billete de tren, confirmado por Stag el 26/07. No aparece en el extracto de febrero, o sea que se pago por fuera de la cuenta. Estaba imputado a Jacobine por la migracion 049 leyendo ILSA como marca de menaje.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Tren iryo a Sevilla (ILSA, fuera de banco)');


-- 051 — el transporte del día a día entra uno a uno. La migración 024 borró la provisión de
-- 200 €/mes creyendo que era un fantasma, pero el barrido del 23/07 no había cargado los taxis
-- precisamente PORQUE esa línea los cubría: quedaron sin provisión y sin evento (1.389,84 € en el
-- semestre, más que los 1.200 que habría provisionado). Stag confirma que son todos de empresa y
-- que no se vuelve a provisionar. Van a CORPORATIVO, así que no mueven la rentabilidad por piso.
-- Segunda parte: marca de procedencia en los seis apuntes que descansan solo en la planilla manual.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, 'SAMAVI_GEN', 'CORPORATIVO', 'Transporte (real bancos)', v.importe, v.notas
from (values
  (2026, 2, -332.34,
   'Iryo 83,77 (09/02) + SBB Suiza 86,59 y 106,33 (25/02) + Renfe 38,75 (26/02) + Uber 8,96 y 7,94 (27/02). Extracto Revolut febrero 2026. Todos confirmados como gasto de empresa por Stag el 26/07.'),
  (2026, 3, -786.29,
   'Cabify 6,96 (02/03) + Uber 20,95 (08/03) + Licencia 431 (taxi) 12,30 (16/03) + Uber 9,93, 20,91 y 13,90 (17/03) + iryo 87,63 y Uber 14,96 (19/03) + iryo 103,96 y Vueling 135,66 (23/03) + iryo 54,26 (25/03) + Vueling 311,09, FreeNow 8,00 y Uber 23,95 (26/03) + Uber 14,95 (27/03) = 839,41 brutos, MENOS el reembolso de iryo de 53,12 liquidado el 01/03. Extracto Revolut marzo 2026.'),
  (2026, 4, -201.37,
   'Iryo 149,59 y Uber 8,96 (liquidados el 01-02/04, iniciados el 31/03) + Uber 6,94 (01/04) + Uber 10,93 y 8,00 (04/04) + Uber 16,95 (13/04). Extracto Revolut abril 2026.'),
  (2026, 5, -16.93,
   'Uber 16,93 (29/05). Unico cargo de transporte del mes. Extracto Revolut mayo 2026.'),
  (2026, 6, -52.91,
   'Cabify 22,99 (10/06) + Uber 13,93 (24/06) + Cabify 15,99 (28/06). Extracto Revolut junio 2026.')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Transporte (real bancos)');

-- ── Y UNA MARCA DE PROCEDENCIA ──────────────────────────────────────────────────────
-- Stag avisó el 26/07 de que la planilla manual que pasó es como se manejaba ANTES del dashboard y
-- puede tener errores: hay que contrastar contra documentación real o contra su confirmación, no
-- asumir. Revisadas las cargas de la migración 049 una por una, seis apuntes descansan SÓLO en esa
-- planilla — no hay cargo bancario ni factura detrás, porque se pagaron en efectivo o por fuera:
--
--   3G_MARE  ene   60,00   cristales (Claudio)
--   3G_MARE  mar  150,00   arreglo de bañera (Claudio)
--   1A_NICA  feb   32,73   NRUA registro
--   4B_ALEX  feb   28,67   NRUA registro
--   1A_JACO  ene   28,57   amenities
--   1A_JACO  feb   10,00   amenities
--
-- Se quedan cargados —es el criterio de peor caso que el repo ya usa (022, 031, 034, 044)— pero la
-- nota lo dice, para que nadie los lea como conciliados. La reimputación de la copia de llaves
-- (46,30, de Nicasio a Jacobine) también sale de la planilla, aunque el cargo bancario sí existe.

update events
   set notas = notas || ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.'
 where anio = 2026
   and concepto in ('Cristales (Claudio, efectivo)', 'Arreglo de bañera (Claudio, efectivo)',
                    'NRUA — registro único de alojamiento', 'Gastos de bolsillo (fuera de banco)')
   and notas not like '%FUENTE: solo la planilla manual%';

update events
   set notas = notas || ' ⚑ La REIMPUTACION a Jacobine sale solo de la planilla manual de Stag; el cargo bancario si existe. Pendiente de confirmar que la copia de llaves era del piso de Sevilla y no de uno de Madrid.'
 where anio = 2026 and mes = 2 and propiedad_codigo = '1A_JACO'
   and concepto = 'Copia de llaves (Ferretería Diego de León)'
   and notas not like '%REIMPUTACION a Jacobine sale solo%';


-- 052 — la nómina de José verificada contra el BBVA. El TGSS no aparecía en el Revolut porque se
-- paga desde el BBVA: 204,33 en enero y 204,86 de febrero a junio, cargo por cargo. El modelo era
-- correcto — la refactura de limpieza de Jacobine gana, poco pero gana. Se afina a 11,23 (ene) y
-- 11,14 (feb-dic). Y se corrige la marca de la 051 sobre los dos NRUA: sí tienen respaldo bancario,
-- están en el BBVA.
update events
   set importe = 11.23,
       notas   = 'Nomina de enero 484,44 (pagada el 02/02 desde Revolut) + TGSS regimen general 204,33 (cargada el 30/01 en el BBVA) = 688,77, contra los 700 que se le descuentan a la duena. VERIFICADO contra banco el 26/07/2026, ya no es una suposicion.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 1
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set importe = 11.14,
       notas   = 'Nomina 484,00 + TGSS regimen general 204,86 = 688,86, contra los 700 que se le descuentan a la duena. La cuota de TGSS subio de 204,33 a 204,86 en febrero y se mantuvo; verificada cargo por cargo en los extractos del BBVA (27/02, 31/03, 30/04, 29/05, 30/06). El cargo de 370,75 que aparece al lado es el RETA de Stag, no el de Jose. VERIFICADO contra banco el 26/07/2026.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes >= 2
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set notas = replace(notas,
        ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.',
        ' ⚑ CORREGIDO 26/07: si tiene respaldo bancario, esta en el BBVA (no en el Revolut, por eso no aparecia): transferencia del 24/02 "F4 510 - NRUA" 32,73 para Nicasio y del 26/02 "F4 - 7784 - NRUA" 28,67 para Alexander.')
 where anio = 2026 and concepto = 'NRUA — registro único de alojamiento';


-- 053 — la renta de Alexander sube el 01/10: se agota la devolución del amoblamiento (3.064 € a
-- 12 meses = 255,31/mes descontados de la base). El coste pasa de 1.677,65 a 1.986,58 €/mes,
-- +3.707 €/año = el 94% del margen anual del piso, y ocurre solo el día que se prorroga el
-- contrato. Va a `avisos` (el mecanismo de la 045). Y se corrige la nota del aviso de contrato:
-- el preaviso de no prórroga es facultad de Alberto (cláusula 2.2), no de Samavi.
insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '4B_ALEX', date '2026-10-01', 'renta',
       'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.641,80 €/mes',
       -308.93,
       'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste en el modelo: 1.677,65 -> 1.986,58 EUR/mes (+308,93/mes, +3.707/ano), que es el 94% del margen anual de Alexander. OJO: el contrato dice 1.614,80 de renta (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 = 2 mensualidades lo confirma) pero la hoja de trabajo uso 1.641,80: 27 EUR/mes de diferencia que hay que aclarar con Alberto. La palanca es la clausula 4.3, que permite renegociar la contraprestacion cada 12 meses.'
where not exists (
  select 1 from avisos a where a.codigo = '4B_ALEX' and a.fecha = date '2026-10-01' and a.tipo = 'renta');

-- Y el aviso de contrato decía lo que no es: el preaviso NO lo da Samavi.
-- Cláusula 2.2: es LA PROPIEDAD quien puede cortar la prórroga, dentro de los 30 días anteriores
-- al vencimiento (01–30/09/2026). Cláusulas 3.2 y 3.8: Samavi no puede desistir, y las dificultades
-- económicas no son causa mayor. La única puerta de Samavi es la 4.3, renegociar.
-- El detalle vive en este comentario, no en la alerta: se lee en el móvil.
update listings
   set aviso_nota = 'Vence el contrato. Solo Alberto puede cortar la prórroga; la palanca de Samavi es renegociar (cláusula 4.3)'
 where codigo = '4B_ALEX';


-- 054 — la 053 se equivocó dos veces: (a) dijo que el motor no sabía de la subida de renta de
-- Alexander cuando la migración 022 ya la modelaba (events 92/8/9, oct-dic), y (b) usó los
-- 1.641,80 de la hoja de trabajo en vez de los 1.614,80 del contrato. El salto real en términos
-- de coste es +276,26/mes (+3.315/año), no +308,93. El aviso es la capa de ALERTA; el P&L ya lo
-- contaba. Sin doble conteo: `avisos` sólo alimenta v_alertas.
update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.614,80 €/mes',
       impacto_mes = -276.26,
       nota = 'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste modelado: 1.677,65 -> 1.953,91 EUR/mes (+276,26/mes, +3.315/ano), un 84% del margen anual del piso. El P&L de oct-dic YA lo cuenta desde la migracion 022 (events 92/8/9, -232,88 en terminos de transferencia); este aviso es solo la capa de alerta. PENDIENTE: el contrato dice 1.614,80 (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 lo confirma) pero la hoja de trabajo uso 1.641,80. Si Alberto factura 1.641,80, el salto es 308,93. Confirmarlo antes de renovar. La palanca es la clausula 4.3. Y en enero de 2027 hay que actualizar listings.renta_base: los events de la 022 solo llegan a diciembre.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';


-- 055 — la renta de octubre según el pacto VERBAL con Alberto (Stag, 27/07/2026): Alberto recibe
-- 1.614,80 EN CUENTA → base derivada 1.583,14. Los events del Q4 pasan de −232,88 (lectura literal
-- del contrato) a −200,58, y el aviso a +237,95/mes de coste (+2.855/año). Modela la lectura más
-- favorable por instrucción de Stag; la adenda de octubre debe fijar la cifra por escrito.
-- 1) Los events del Q4 pasan a la transferencia pactada: 1.614,80 − 1.414,22 = 200,58.
update events
   set importe = -200.58,
       notas   = 'Fin del prorrateo del amoblamiento: la transferencia pasa de 1.414,22 a 1.614,80 (pacto VERBAL confirmado por Stag el 27/07/2026: Alberto recibe 1.614,80 en cuenta; base derivada 1.583,14). La 022 habia cargado -232,88 con la lectura literal del contrato (base 1.614,80, transferencia 1.647,10). PENDIENTE la adenda que fije la cifra por escrito: sin ella el contrato permite a Alberto facturar 1.647,10.'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes in (10, 11, 12)
   and categoria = 'RENTA'
   and concepto = 'Renta sube Q4 (fin prorrateo mobiliario) — en transferencia'
   and importe = -232.88;

-- 2) El aviso cuenta la misma historia con el mismo número.
update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: Alberto pasa a recibir 1.614,80 €/mes (base 1.583,14)',
       impacto_mes = -237.95,
       nota = 'Pacto VERBAL (Stag, 27/07/2026): Alberto recibe 1.614,80 en cuenta -> base 1.583,14. Coste modelado 1.677,65 -> 1.915,60 (+237,95/mes, +2.855/ano, ~73% del margen anual del piso). Modela la lectura MAS FAVORABLE por instruccion de Stag, rompiendo el criterio de peor caso: el contrato literal daria coste 1.953,91 (+38,31/mes mas) y la planilla 1.986,58 (+70,98/mes mas). La adenda de octubre (clausulas 4.3 y 8.2) debe fijar por escrito "transferencia 1.614,80, base 1.583,14, IVA 21%, retencion 19%", formato del contrato de Marechal. Ademas, bajo el pacto verbal el descuento del prorrateo se aplico sobre base equivocada (1.641,80 en vez de 1.583,14): se transfirieron ~59,83/mes de mas desde oct-2025, ~598 en 10 meses — decidir en la adenda si se compensa. El P&L de oct-dic ya cuenta la subida via events (-200,58). En enero de 2027 actualizar listings.renta_base.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';


-- 056 — cierre de escrituras con la anon key (auditoría 27/07/2026): v_propiedades era
-- auto-actualizable y anon tenía INSERT/UPDATE/DELETE por default privileges (el RLS de
-- listings no aplica vía vista). La 008 cerró lecturas; esto cierra escrituras y deja los
-- default privileges en cero: toda vista nueva necesita su GRANT SELECT explícito.
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
do $$ begin
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on tables from anon, authenticated';
exception when insufficient_privilege or undefined_object then
  raise notice 'default ACL de supabase_admin no ajustado (sin permisos); revisar a mano';
end $$;
alter table airbnb_tx enable row level security;
alter table avisos enable row level security;
alter table bank_deposits enable row level security;
alter table limpieza_mensual enable row level security;
alter table suministros_mensual enable row level security;
update events set notas = replace(notas, 'a J.L. De La Torre 19/06', 'al dueño de MARE 19/06')
 where notas like '%J.L. De La Torre%';


-- 057 — el mes-borde fuera del "en tránsito" del cuadre (decisión Stag 27/07/2026): el
-- primer mes de la ventana de extractos arrastra payouts de estancias anteriores al
-- período (Revolut ene: +2.656,55 de dic-2025) — arranque, no tránsito. Se agregan
-- mes_borde y diferencia_acum_ajustada; el semáforo del panel usa la ajustada.
create or replace view v_cuadre_banco as
with rango as (
  select date_trunc('month', min(fecha))::date as desde,
         date_trunc('month', max(fecha))::date as hasta
    from bank_deposits
   where es_airbnb
), airbnb as (
  select case when c.codigo in ('1A_NICA','1A_JACO') then '7165' else '8920' end as iban,
         c.anio, c.mes,
         sum(c.payout_total_airbnb) as airbnb_pago
    from v_conciliacion_airbnb c
   where make_date(c.anio, c.mes, 1) >= (select desde from rango)
     and make_date(c.anio, c.mes, 1) <= (select hasta from rango)
   group by 1, c.anio, c.mes
), banco as (
  select iban,
         extract(year from fecha)::int as anio,
         extract(month from fecha)::int as mes,
         sum(importe) as banco_recibio,
         count(*) as depositos
    from bank_deposits
   where es_airbnb
   group by iban, 2, 3
), j as (
  select coalesce(a.iban, b.iban) as iban,
         coalesce(a.anio, b.anio) as anio,
         coalesce(a.mes, b.mes) as mes,
         round(coalesce(a.airbnb_pago, 0), 2) as airbnb_pago,
         round(coalesce(b.banco_recibio, 0), 2) as banco_recibio,
         coalesce(b.depositos, 0) as depositos
    from airbnb a
    full join banco b on a.iban = b.iban and a.anio = b.anio and a.mes = b.mes
)
select iban,
       case iban
         when '7165' then 'Revolut · Nicasio + Jacobine'
         when '8920' then 'BBVA · Alexander + Marechal'
         else iban
       end as cuenta,
       anio, mes, airbnb_pago, banco_recibio, depositos,
       round(banco_recibio - airbnb_pago, 2) as diferencia_mes,
       round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2)
         as diferencia_acum,
       row_number() over (partition by iban order by anio, mes) = 1 as mes_borde,
       round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes)
             - first_value(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2)
         as diferencia_acum_ajustada
  from j
 order by iban, anio, mes;


-- 058 — login, parte 1 de 2: allowlist de emails para Supabase Auth (aplicada 29/07/2026).
-- La anon key es pública y GoTrue expone /auth/v1/signup: sin esto, cualquiera podría
-- registrarse, salir con un JWT de rol authenticated y leer las 24 vistas. El trigger
-- rechaza en la base cualquier alta (o cambio de email) fuera de la allowlist.
-- La parte 2 (059, revocar SELECT de anon) se aplica SOLO con el frontend con login ya
-- desplegado — ver supabase/migrations/059_candado_anon.sql.

create table if not exists public.auth_email_allowlist (
  email text primary key check (email = lower(email)),
  nota  text
);
-- Sin GRANTs: tabla interna, solo la lee el trigger (security definer).

insert into public.auth_email_allowlist (email, nota) values
  ('info@stag-properties.com', 'Stag — CEO')
on conflict (email) do nothing;

create or replace function public.f_auth_bloquear_no_invitados()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is null
     or not exists (select 1 from public.auth_email_allowlist a
                     where a.email = lower(new.email)) then
    raise exception 'Alta no permitida para este email';
  end if;
  return new;
end;
$$;

revoke execute on function public.f_auth_bloquear_no_invitados() from public, anon, authenticated;

drop trigger if exists trg_auth_allowlist_ins on auth.users;
create trigger trg_auth_allowlist_ins
  before insert on auth.users
  for each row execute function public.f_auth_bloquear_no_invitados();

drop trigger if exists trg_auth_allowlist_upd on auth.users;
create trigger trg_auth_allowlist_upd
  before update of email on auth.users
  for each row execute function public.f_auth_bloquear_no_invitados();


-- 059 — login, parte 2 de 2: el candado (aplicada 30/07/2026, con el deploy con login ya
-- vivo). Anon pierde toda lectura: el dashboard se lee con sesión (rol authenticated).
-- Este revoke cierra también los "to anon" que las secciones anteriores replican.
-- REGLA PARA TODA SECCIÓN APENDIZADA DESPUÉS DE ESTA (el barrido ya no la cubre):
-- prohibido cualquier "to anon" — grants a authenticated SOLO. Un "to anon" apendizado
-- sobreviviría al rebuild y reabriría la lectura sin login solo en entornos
-- reconstruidos: divergencia silenciosa, indetectable desde el dashboard.

revoke select on all tables in schema public from anon;
revoke usage, select on all sequences in schema public from anon;


-- 060 — parametrización del período: el motor aprende "desde–hasta" (spec §5.2 y §8.2).
--
-- Hasta hoy el año en curso estaba grabado en la cadena de vistas: v_month_spine generaba
-- los meses "de enero a hoy" con now() adentro, y todo lo que cuelga de ella (días de
-- gestión, overhead, limpieza, suministros, P&L mensual) más 4 filtros now() propios
-- (ranking, costes, breakeven, canal) heredaban ese pin. Preguntarle al motor "¿y en
-- marzo?" no tenía dónde escribirse.
--
-- Diseño (el de la spec): funciones f_*(p_desde, p_hasta) con EXACTAMENTE la misma
-- aritmética que las vistas — mismo prorrateo de overhead por días bajo gestión sobre el
-- período completo, mismos casts, mismos round() — y las vistas actuales redefinidas como
-- WRAPPERS que llaman a su función con (1 de enero, hoy). El front no cambia ni un número
-- (verificado contra foto previa: las 10 vistas idénticas fila a fila). El motor sigue
-- viviendo en UN lugar: ahora son las funciones; las vistas son alias del caso "YTD".
--
-- Semántica del rango: MES COMPLETO. p_desde/p_hasta se truncan a su mes (el motor imputa
-- por mes; "hasta hoy" siempre incluyó el mes corriente entero como disponible). Rangos
-- invertidos devuelven 0 filas sin error. Rangos futuros devuelven costes con el fallback
-- "estimado" de siempre e ingreso on-the-books (el UI actual no los usa). Rangos pre-2026
-- devuelven ingreso/noches reales pero costes estimados: los costes reales solo están
-- cargados desde ene-2026 — el YoY de margen sigue vetado (spec §5.5), esto NO lo habilita.
--
-- Seguridad (doctrina 056/059): funciones SECURITY DEFINER (leen tablas crudas que
-- authenticated no ve) con search_path fijado; EXECUTE revocado de PUBLIC/anon en TODAS
-- y concedido a authenticated en TODAS (ver la lección al pie, en los GRANTs). La
-- superficie RPC pensada para el front son las 4 de la spec (f_ranking, f_costes,
-- f_breakeven, f_canal); las demás quedan ejecutables por necesidad técnica, no de uso.

-- ── 1) f_spine: el generador de meses por propiedad, ahora con rango ─────────────────
create or replace function f_spine(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer)
language sql stable
security definer set search_path = public
as $$
  select l.codigo,
         extract(year from gs.gs)::integer,
         extract(month from gs.gs)::integer
    from listings l
    cross join lateral generate_series(
      greatest(date_trunc('month', l.fecha_inicio::timestamptz),
               date_trunc('month', p_desde::timestamptz)),
      date_trunc('month', p_hasta::timestamptz),
      interval '1 mon') gs(gs)
$$;

-- ── 2) f_dias_gestion ────────────────────────────────────────────────────────────────
create or replace function f_dias_gestion(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, dias integer)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes, dias_gestion(l.fecha_inicio, s.anio, s.mes)
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
$$;

-- ── 3) f_samavi_gen_mensual: pool de overhead/corporativo por mes del rango ──────────
create or replace function f_samavi_gen_mensual(p_desde date, p_hasta date)
returns table(anio integer, mes integer, overhead numeric, corporativo numeric)
language sql stable
security definer set search_path = public
as $$
  select m.anio, m.mes,
         (select coalesce(sum(g.importe_mes), 0)
            from general_expenses g
           where not g.es_corporativo
             and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde::timestamptz)::date)
             and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
         - coalesce((select sum(e.importe) from events e
                      where e.categoria = 'SAMAVI_GEN' and e.anio = m.anio and e.mes = m.mes), 0)
           as overhead,
         (select coalesce(sum(g.importe_mes), 0)
            from general_expenses g
           where g.es_corporativo
             and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde::timestamptz)::date)
             and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
         - coalesce((select sum(e.importe) from events e
                      where e.categoria = 'CORPORATIVO' and e.anio = m.anio and e.mes = m.mes), 0)
           as corporativo
    from (select distinct s.anio, s.mes from f_spine(p_desde, p_hasta) s) m
$$;

-- ── 4) f_limpieza_mensual: real si hay factura, estimado si no ───────────────────────
create or replace function f_limpieza_mensual(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, coste numeric, fuente text,
              servicios integer, horas numeric, factura text)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes,
         case when lm.codigo is not null then -(lm.base_eur + lm.iva_eur)
              else -(l.limpieza_por_reserva * coalesce(b.reservas, 0::bigint)::numeric) end,
         case when lm.codigo is null then 'estimado'
              when lm.fiable then 'real'
              else 'real_revisar' end,
         lm.servicios, lm.horas, lm.factura
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
    left join limpieza_mensual lm on lm.codigo = s.codigo and lm.anio = s.anio and lm.mes = s.mes
$$;

-- ── 5) f_suministros_mensual ─────────────────────────────────────────────────────────
create or replace function f_suministros_mensual(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, coste numeric, fuente text,
              luz_eur numeric, internet_eur numeric, nota text)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes,
         case when sm.codigo is not null then -sm.total_eur
              else -l.suministros_mes end,
         case when sm.codigo is null then 'estimado'
              when sm.fiable then 'real'
              else 'real_revisar' end,
         sm.luz_eur, sm.internet_eur, sm.nota
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join suministros_mensual sm on sm.codigo = s.codigo and sm.anio = s.anio and sm.mes = s.mes
$$;

-- ── 6) f_pnl_mensual_propiedad: el P&L mensual completo, por rango ───────────────────
create or replace function f_pnl_mensual_propiedad(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, dias_mes integer, bruto numeric,
              ingreso_samavi numeric, comision_aparente numeric, noches bigint,
              reservas bigint, ocup_pct numeric, adr numeric, revpar numeric, alos numeric,
              renta numeric, limpieza numeric, suministros numeric, comunidad numeric,
              otros numeric, total_gastos_directos numeric, margen_directo numeric,
              ingreso_noches numeric, ingreso_cancelaciones numeric, iva_repercutido numeric,
              renta_iva numeric, limpieza_fuente text, comision_canal numeric,
              comision_canal_samavi numeric, suministros_fuente text)
language sql stable
security definer set search_path = public
as $$
  with ev as (
    select e.propiedad_codigo as codigo, e.anio, e.mes,
           coalesce(sum(e.importe) filter (where e.categoria = 'RENTA'), 0)       as ev_renta,
           coalesce(sum(e.importe) filter (where e.categoria = 'OTROS'), 0)       as ev_otros,
           coalesce(sum(e.importe) filter (where e.categoria = 'SUMINISTROS'), 0) as ev_suministros
      from events e
     group by e.propiedad_codigo, e.anio, e.mes
  ), base as (
    select s.codigo, s.anio, s.mes,
           days_in_month(s.anio, s.mes)                       as dias_mes,
           coalesce(n.bruto, 0)                               as bruto,
           coalesce(n.ingreso_samavi, 0)                      as ingreso_noches,
           coalesce(c.ingreso_cancelaciones, 0)               as ingreso_cancelaciones,
           coalesce(n.noches, 0::bigint)                      as noches,
           coalesce(b.reservas, 0::bigint)                    as reservas,
           coalesce(n.iva_repercutido, 0) + coalesce(c.iva_cancelaciones, 0) as iva_repercutido,
           coalesce(n.comision_canal, 0)                      as comision_canal,
           coalesce(n.comision_canal_samavi, 0)               as comision_canal_samavi,
           case when l.modelo = 'subarriendo' then -l.renta_base else 0 end
             + coalesce(ev.ev_renta, 0)                       as renta_transfer,
           l.renta_factura_desde is not null
             and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde::timestamptz)::date
                                                              as con_factura,
           l.renta_iva_pct, l.renta_retencion_pct,
           lp.coste                                           as limpieza,
           lp.fuente                                          as limpieza_fuente,
           sp.coste + coalesce(ev.ev_suministros, 0)          as suministros,
           sp.fuente                                          as suministros_fuente,
           -l.comunidad_ibi_mes                               as comunidad,
           -(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
             + coalesce(ev.ev_otros, 0)                       as otros
      from f_spine(p_desde, p_hasta) s
      join listings l on l.codigo = s.codigo
      join f_limpieza_mensual(p_desde, p_hasta) lp
        on lp.codigo = s.codigo and lp.anio = s.anio and lp.mes = s.mes
      join f_suministros_mensual(p_desde, p_hasta) sp
        on sp.codigo = s.codigo and sp.anio = s.anio and sp.mes = s.mes
      left join v_nights_monthly n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
      left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
      left join v_ingreso_cancelaciones c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
      left join ev on ev.codigo = s.codigo and ev.anio = s.anio and ev.mes = s.mes
  ), conv as (
    select b.*,
           case when b.con_factura
                then (1 + b.renta_iva_pct) / (1 + b.renta_iva_pct - b.renta_retencion_pct)
                else 1 end as factor,
           case when b.con_factura
                then b.renta_iva_pct / (1 + b.renta_iva_pct - b.renta_retencion_pct)
                else 0 end as factor_iva
      from base b
  ), final as (
    select c.*,
           round(c.renta_transfer * c.factor, 2)     as renta,
           round(c.renta_transfer * c.factor_iva, 2) as renta_iva
      from conv c
  )
  select f.codigo, f.anio, f.mes, f.dias_mes, f.bruto,
         f.ingreso_noches + f.ingreso_cancelaciones            as ingreso_samavi,
         f.bruto - f.ingreso_noches                            as comision_aparente,
         f.noches, f.reservas,
         round(f.noches::numeric / f.dias_mes::numeric, 4)     as ocup_pct,
         case when f.noches > 0 then round(f.bruto / f.noches::numeric, 2) else 0 end as adr,
         round(f.bruto / f.dias_mes::numeric, 2)               as revpar,
         case when f.reservas > 0 then round(f.noches::numeric / f.reservas::numeric, 2) else 0 end as alos,
         f.renta, f.limpieza, f.suministros, f.comunidad, f.otros,
         f.renta + f.limpieza + f.suministros + f.comunidad + f.otros as total_gastos_directos,
         f.ingreso_noches + f.ingreso_cancelaciones
           + f.renta + f.limpieza + f.suministros + f.comunidad + f.otros as margen_directo,
         f.ingreso_noches, f.ingreso_cancelaciones, f.iva_repercutido, f.renta_iva,
         f.limpieza_fuente,
         round(f.comision_canal, 2)                            as comision_canal,
         round(f.comision_canal_samavi, 2)                     as comision_canal_samavi,
         f.suministros_fuente
    from final f
$$;

-- ── 7) f_ranking: la vista reina, por rango (overhead prorrateado por días del RANGO) ─
create or replace function f_ranking(p_desde date, p_hasta date)
returns table(codigo text, ingreso_samavi numeric, bruto numeric, noches numeric,
              reservas numeric, noches_disponibles bigint, gastos_directos numeric,
              margen_directo numeric, cuota_samavi_gen numeric, margen_neto numeric,
              margen_neto_pct numeric, eur_noche_neto numeric, ocup_pct numeric,
              adr numeric, revpar numeric, ingreso_cancelaciones numeric,
              iva_repercutido numeric, contribucion numeric, contribucion_pct numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.ingreso_samavi)         as ingreso_samavi,
           sum(p.bruto)                  as bruto,
           sum(p.noches)                 as noches,
           sum(p.reservas)               as reservas,
           sum(p.dias_mes)               as noches_disponibles,
           sum(p.total_gastos_directos)  as gastos_directos,
           sum(p.margen_directo)         as margen_directo,
           sum(p.ingreso_cancelaciones)  as ingreso_cancelaciones,
           sum(p.iva_repercutido)        as iva_repercutido
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  ), dias as (
    select d.codigo, sum(d.dias) as dias
      from f_dias_gestion(p_desde, p_hasta) d
     group by d.codigo
  ), oh as (
    select coalesce(sum(g.overhead), 0) as total
      from f_samavi_gen_mensual(p_desde, p_hasta) g
  ), td as (
    select coalesce(sum(dias.dias), 0::numeric) as t from dias
  )
  select y.codigo, y.ingreso_samavi, y.bruto, y.noches, y.reservas, y.noches_disponibles,
         y.gastos_directos, y.margen_directo,
         round(-(select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2)
           as cuota_samavi_gen,
         round(y.margen_directo
               - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2)
           as margen_neto,
         case when y.ingreso_samavi > 0
              then round((y.margen_directo
                          - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)))
                         / y.ingreso_samavi, 4)
              else 0 end as margen_neto_pct,
         case when y.noches > 0
              then round((y.margen_directo
                          - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)))
                         / y.noches, 2)
              else 0 end as eur_noche_neto,
         case when y.noches_disponibles > 0
              then round(y.noches / y.noches_disponibles::numeric, 4) else 0 end as ocup_pct,
         case when y.noches > 0 then round(y.bruto / y.noches, 2) else 0 end as adr,
         case when y.noches_disponibles > 0
              then round(y.bruto / y.noches_disponibles::numeric, 2) else 0 end as revpar,
         y.ingreso_cancelaciones,
         round(y.iva_repercutido, 2) as iva_repercutido,
         round(y.margen_directo, 2)  as contribucion,
         case when y.ingreso_samavi > 0
              then round(y.margen_directo / y.ingreso_samavi, 4) else 0 end as contribucion_pct
    from ytd y
    join dias d on d.codigo = y.codigo
   order by round(y.margen_directo
                  - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2) desc
$$;

-- ── 8) f_costes ──────────────────────────────────────────────────────────────────────
create or replace function f_costes(p_desde date, p_hasta date)
returns table(codigo text, renta numeric, limpieza numeric, suministros numeric,
              comunidad numeric, otros numeric, total_directos numeric, overhead numeric,
              total_costes numeric, pct_sobre_ingreso numeric, renta_iva numeric,
              comision_canal numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.renta)                 as renta,
           sum(p.limpieza)              as limpieza,
           sum(p.suministros)           as suministros,
           sum(p.comunidad)             as comunidad,
           sum(p.otros)                 as otros,
           sum(p.total_gastos_directos) as total_directos,
           sum(p.ingreso_samavi)        as ingreso,
           sum(p.renta_iva)             as renta_iva,
           sum(p.comision_canal_samavi) as comision_canal_samavi
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  )
  select y.codigo,
         round(-y.renta, 2), round(-y.limpieza, 2), round(-y.suministros, 2),
         round(-y.comunidad, 2), round(-y.otros, 2), round(-y.total_directos, 2),
         round(-r.cuota_samavi_gen, 2),
         round(-(y.total_directos + r.cuota_samavi_gen), 2),
         case when y.ingreso > 0
              then round((-(y.total_directos + r.cuota_samavi_gen)) / y.ingreso, 4)
              else 0 end,
         round(-y.renta_iva, 2),
         round(y.comision_canal_samavi, 2)
    from ytd y
    join f_ranking(p_desde, p_hasta) r on r.codigo = y.codigo
$$;

-- ── 9) f_breakeven ───────────────────────────────────────────────────────────────────
create or replace function f_breakeven(p_desde date, p_hasta date)
returns table(codigo text, costes_fijos numeric, contribucion_noche numeric,
              noches_necesarias integer, ocup_breakeven numeric, ocup_actual numeric,
              colchon numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.ingreso_samavi) as ingreso,
           sum(p.noches)         as noches,
           sum(p.dias_mes)       as disponibles,
           sum(p.renta)          as renta,
           sum(p.limpieza)       as limpieza,
           sum(p.suministros)    as suministros,
           sum(p.comunidad)      as comunidad,
           sum(p.otros)          as otros
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  ), calc as (
    select y.codigo, y.noches, y.disponibles,
           (-(y.renta + y.suministros + y.comunidad + y.otros)) - r.cuota_samavi_gen as costes_fijos,
           case when y.noches > 0 then (y.ingreso + y.limpieza) / y.noches else 0 end as contrib_noche,
           case when y.disponibles > 0 then y.noches / y.disponibles::numeric else 0 end as ocup_actual
      from ytd y
      join f_ranking(p_desde, p_hasta) r on r.codigo = y.codigo
  )
  select c.codigo,
         round(c.costes_fijos, 2),
         round(c.contrib_noche, 2),
         case when c.contrib_noche > 0 then ceil(c.costes_fijos / c.contrib_noche)::integer
              else null end,
         case when c.contrib_noche > 0 and c.disponibles > 0
              then round(c.costes_fijos / c.contrib_noche / c.disponibles::numeric, 4)
              else null end,
         round(c.ocup_actual, 4),
         case when c.contrib_noche > 0 and c.disponibles > 0
              then round(c.ocup_actual - c.costes_fijos / c.contrib_noche / c.disponibles::numeric, 4)
              else null end
    from calc c
$$;

-- ── 10) f_canal (granularidad mes, como siempre tuvo v_canal_ytd) ────────────────────
create or replace function f_canal(p_desde date, p_hasta date)
returns table(codigo text, canal text, reservas bigint, ingreso numeric)
language sql stable
security definer set search_path = public
as $$
  select rn.codigo,
         coalesce(rn.source, 'directo/otro'),
         count(distinct rn.id),
         round(sum(rn.ingreso_samavi_night), 2)
    from v_reservation_nights rn
   where make_date(rn.anio, rn.mes, 1) >= date_trunc('month', p_desde::timestamptz)::date
     and make_date(rn.anio, rn.mes, 1) <= date_trunc('month', p_hasta::timestamptz)::date
   group by rn.codigo, coalesce(rn.source, 'directo/otro')
$$;

-- ── 11) Las vistas pasan a ser wrappers: el caso "año en curso" de cada función ──────
create or replace view v_month_spine as
  select * from f_spine(date_trunc('year', now())::date, now()::date);
create or replace view v_dias_gestion as
  select * from f_dias_gestion(date_trunc('year', now())::date, now()::date);
create or replace view v_samavi_gen_mensual as
  select * from f_samavi_gen_mensual(date_trunc('year', now())::date, now()::date);
-- Los casts de horas/luz_eur/internet_eur reponen la precisión original de la tabla
-- (numeric(8,2)/(10,2)): Postgres DESCARTA los typmod declarados en el returns table de
-- una función, y "create or replace view" exige calce exacto de tipo con la vista vieja.
create or replace view v_limpieza_mensual as
  select codigo, anio, mes, coste, fuente, servicios,
         horas::numeric(8,2) as horas, factura
    from f_limpieza_mensual(date_trunc('year', now())::date, now()::date);
create or replace view v_suministros_mensual as
  select codigo, anio, mes, coste, fuente,
         luz_eur::numeric(10,2) as luz_eur, internet_eur::numeric(10,2) as internet_eur, nota
    from f_suministros_mensual(date_trunc('year', now())::date, now()::date);
create or replace view v_pnl_mensual_propiedad as
  select * from f_pnl_mensual_propiedad(date_trunc('year', now())::date, now()::date);
create or replace view v_ranking_ytd as
  select * from f_ranking(date_trunc('year', now())::date, now()::date);
create or replace view v_costes_ytd as
  select * from f_costes(date_trunc('year', now())::date, now()::date);
create or replace view v_breakeven_ytd as
  select * from f_breakeven(date_trunc('year', now())::date, now()::date);
create or replace view v_canal_ytd as
  select * from f_canal(date_trunc('year', now())::date, now()::date);

-- ── 12) Permisos (regla 059: authenticated SOLO, nunca anon) ─────────────────────────
revoke execute on function
  f_spine(date, date), f_dias_gestion(date, date), f_samavi_gen_mensual(date, date),
  f_limpieza_mensual(date, date), f_suministros_mensual(date, date),
  f_pnl_mensual_propiedad(date, date), f_ranking(date, date), f_costes(date, date),
  f_breakeven(date, date), f_canal(date, date)
from public, anon, authenticated;

-- TODAS a authenticated, no solo las 4 de la spec — lección que costó ~10 min de
-- dashboard sin datos (30/07/2026): Postgres comprueba el EXECUTE de una función llamada
-- dentro de una vista contra el USUARIO QUE CONSULTA, no contra el dueño de la vista
-- (al revés que las referencias a tablas/vistas). Con las internas sin GRANT, v_kpis →
-- v_samavi_gen_mensual (wrapper) → f_samavi_gen_mensual devolvía 42501 a authenticated
-- y readView caía al fallback. No expone nada nuevo (devuelven lo que las vistas ya
-- muestran); anon sigue sin poder ejecutar ninguna. REGLA: toda f_ nueva que toque una
-- vista necesita su GRANT a authenticated aunque sea "interna".
grant execute on function
  f_spine(date, date), f_dias_gestion(date, date), f_samavi_gen_mensual(date, date),
  f_limpieza_mensual(date, date), f_suministros_mensual(date, date),
  f_pnl_mensual_propiedad(date, date), f_ranking(date, date), f_costes(date, date),
  f_breakeven(date, date), f_canal(date, date)
to authenticated;


-- 061 — candado de default privileges para FUNCIONES y SECUENCIAS + residuos de ACL.
-- Hallazgos de la revisión adversarial de la 060 (30/07/2026). Idempotente.
--
-- La 056 cerró los defaults de TABLAS, pero cada función nueva seguía naciendo con
-- EXECUTE para anon/authenticated (pg_default_acl objtype 'f') y cada secuencia con
-- USAGE+UPDATE. Con el motor ahora en funciones SECURITY DEFINER que leen tablas crudas
-- (060), una f_ futura sin su bloque de revoke quedaría legible con la anon key (pública)
-- vía /rest/v1/rpc/ — la misma fuga silenciosa que 008/056/059 cerraron para vistas, y
-- el dashboard no la delataría porque él lee como authenticated. Tras esto, la doctrina
-- queda completa: toda vista, FUNCIÓN o secuencia nueva nace SIN permisos; los GRANTs
-- son siempre explícitos, a authenticated, nunca a anon.

-- 1) Defaults de postgres (el rol con el que corren las migraciones): a cero.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated;

-- 2) supabase_admin: el do-block de la 056 falló EN SILENCIO (su default de tablas
--    seguía dando arwdDxtm a anon al auditar hoy). Se reintenta; verificar
--    pg_default_acl tras aplicar — no fiarse del notice.
--    RESULTADO (30/07/2026): volvió a fallar (insufficient_privilege). Queda como
--    limitación documentada: solo afecta a objetos creados por la PLATAFORMA; nuestras
--    migraciones corren como postgres, cuyos defaults SÍ quedaron a cero (verificado).
do $$ begin
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on tables from anon, authenticated';
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke execute on functions from public, anon, authenticated';
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on sequences from public, anon, authenticated';
exception when insufficient_privilege or undefined_object then
  raise notice 'default ACL de supabase_admin no ajustado (sin permisos); consta como limitación';
end $$;

-- 3) Residuos vivos sobre objetos EXISTENTES:
--    - UPDATE de anon en las 5 secuencias: la 059 revocó usage/select, pero UPDATE es
--      otro bit y permite nextval/setval (sin canal HTTP hoy; fuera de la regla igual).
--    - MAINTAIN (bit 'm', nuevo de PG17) en las vistas pre-056: la 056 revocó por lista
--      nominal y este bit no existía en ella.
revoke all on all sequences in schema public from anon, authenticated;
revoke maintain on all tables in schema public from anon, authenticated;

-- 4) Las dos helpers puras dejan de ser RPC anónima (nacieron con el default abierto).
--    authenticated CONSERVA el EXECUTE: hay vistas que las llaman en su cuerpo y ese
--    EXECUTE se comprueba contra el usuario que consulta (la lección de la 060).
revoke execute on function days_in_month(integer, integer), dias_gestion(date, integer, integer)
  from public, anon;
grant execute on function days_in_month(integer, integer), dias_gestion(date, integer, integer)
  to authenticated, service_role;

-- 5) Hardening gratis: pg_temp al final del search_path de las SECURITY DEFINER (forma
--    canónica; hoy inexplotable — los roles de API no crean objetos ni tablas temp).
alter function f_spine(date, date)                 set search_path = public, pg_temp;
alter function f_dias_gestion(date, date)          set search_path = public, pg_temp;
alter function f_samavi_gen_mensual(date, date)    set search_path = public, pg_temp;
alter function f_limpieza_mensual(date, date)      set search_path = public, pg_temp;
alter function f_suministros_mensual(date, date)   set search_path = public, pg_temp;
alter function f_pnl_mensual_propiedad(date, date) set search_path = public, pg_temp;
alter function f_ranking(date, date)               set search_path = public, pg_temp;
alter function f_costes(date, date)                set search_path = public, pg_temp;
alter function f_breakeven(date, date)             set search_path = public, pg_temp;
alter function f_canal(date, date)                 set search_path = public, pg_temp;
alter function f_auth_bloquear_no_invitados()      set search_path = public, pg_temp;


-- 062 — alta de Fede en la allowlist del login (30/07/2026). Idempotente.
-- Sin este insert el trigger de la 058 rechaza el alta: la allowlist gobierna, no el panel.
-- El usuario de auth.users NO se puede sembrar por SQL: se crea con signup/panel (ver README §4).

insert into public.auth_email_allowlist (email, nota) values
  ('fndelpercio@gmail.com', 'Fede — colaborador (automatizaciones)')
on conflict (email) do nothing;


-- 063 — PriceLabs fase B: sync nocturno del calendario forward a Supabase (roadmap
-- Fede 22–30/07/2026). Idempotente.
--
-- Qué entra: por piso y noche FUTURA, lo que PriceLabs sabe y Guesty no —
--   · precio publicado (price) vs recomendación pura del algoritmo (uncustomized_price)
--     vs override manual (user_price; -1 = sin override → null),
--   · si la noche está vendida (occupancy), a qué ADR y cuándo se reservó (lead time),
--   · demanda del mercado (demand_desc) y min-stay vigente,
--   · el mismo día del año pasado (STLY): vendida o no y a qué ADR.
-- Fuente: POST api.pricelabs.co/v1/listing_prices (misma carga que el MCP). El
-- listing_id de PriceLabs ES listings.guesty_listing_id (PMS = guesty): sin mapeo nuevo.
-- Las noches que pasan dejan de actualizarse → la tabla conserva la última foto de cada
-- noche (histórico barato de precio publicado + lead time). Dato operativo/forward: NO
-- toca el P&L devengado (el ingreso real sigue viniendo de reservations).
--
-- Seguridad (doctrina 056/059/061): la tabla nace sin permisos; escribe SOLO la Edge
-- Function pricelabs-sync (service_role, GRANT explícito — tras la 056 ni service_role
-- hereda nada). El front lee por f_pricelabs_forward/v_pricelabs_forward, GRANT a
-- authenticated SOLO — nunca a anon.

-- ── 1) Tabla RAW ─────────────────────────────────────────────────────────────────────
create table if not exists pricelabs_prices (
  codigo          text not null references listings(codigo),
  fecha           date not null,
  precio          numeric(8,2),   -- precio publicado ese día (lo que empuja PriceLabs)
  precio_usuario  numeric(8,2),   -- override manual; null = sin override
  precio_base     numeric(8,2),   -- recomendación sin personalizaciones
  min_stay        integer,
  reservado       boolean not null default false,
  booking_status  text,           -- 'Booked' / 'Booked (Check-In)' / 'Blocked' / null (libre)
  adr             numeric(8,2),   -- ADR de la reserva que cubre la noche
  fecha_reserva   date,           -- cuándo se reservó → lead time
  stly_reservado  boolean,        -- mismo día del año pasado: ¿vendido?
  stly_adr        numeric(8,2),
  demanda         text,           -- demand_desc de PriceLabs (mercado)
  no_vendible     boolean not null default false,  -- unbookable (hueco por min-stay, bloqueo)
  currency        text,
  refreshed_at    timestamptz,    -- último refresh de PriceLabs
  synced_at       timestamptz not null default now(),
  primary key (codigo, fecha)
);

-- Escritura: solo la Edge Function (service_role). Sin esto el upsert devuelve 42501.
grant select, insert, update, delete on pricelabs_prices to service_role;

-- ── 2) Estado del sync (mismo registro id=1 que guesty-sync) ─────────────────────────
alter table sync_state add column if not exists pricelabs_last_run timestamptz;
alter table sync_state add column if not exists pricelabs_last_error text;

-- ── 3) Motor: f_pricelabs_forward(desde, hasta) + wrapper "próximos 30 días" ─────────
-- Rango en DÍAS (dato diario forward), no en meses como las f_ del P&L: acá no hay
-- prorrateo de overhead que proteger. Ocupación sobre el total de noches del rango
-- (mismo criterio que el motor: disponibles = todas las noches). "No vendible" agrupa
-- los huecos de min-stay (unbookable) Y los bloqueos manuales (booking_status='Blocked',
-- visto en producción el 02/08: Jacobine y Marechal) — ninguno es noche vendible.
create or replace function f_pricelabs_forward(p_desde date, p_hasta date)
returns table(
  codigo text, noches integer, reservadas integer, no_vendibles integer, libres integer,
  ocupacion numeric, adr_reservado numeric, precio_medio_libre numeric,
  stly_ocupacion numeric, stly_adr numeric, refreshed_at timestamptz
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select p.codigo,
         count(*)::integer,
         (count(*) filter (where p.reservado))::integer,
         (count(*) filter (where not p.reservado
                             and (p.no_vendible or p.booking_status = 'Blocked')))::integer,
         (count(*) filter (where not p.reservado and not p.no_vendible
                             and p.booking_status is distinct from 'Blocked'))::integer,
         round((count(*) filter (where p.reservado))::numeric / count(*), 4),
         round(avg(p.adr) filter (where p.reservado), 2),
         round(avg(p.precio) filter (where not p.reservado and not p.no_vendible
                                       and p.booking_status is distinct from 'Blocked'), 2),
         case when count(*) filter (where p.stly_reservado is not null) > 0
              then round((count(*) filter (where p.stly_reservado))::numeric
                         / count(*) filter (where p.stly_reservado is not null), 4) end,
         round(avg(p.stly_adr), 2),
         max(p.refreshed_at)
    from pricelabs_prices p
   where p.fecha between p_desde and p_hasta
   group by p.codigo
$$;

create or replace view v_pricelabs_forward as
  select * from f_pricelabs_forward(current_date, current_date + 29);

-- ── 4) Permisos (regla 059/061: authenticated SOLO, nunca anon) ──────────────────────
revoke execute on function f_pricelabs_forward(date, date) from public, anon, authenticated;
grant execute on function f_pricelabs_forward(date, date) to authenticated;
grant select on v_pricelabs_forward to authenticated;


-- 064 — arreglos de la auditoría PriceLabs del 03/08/2026 (informe con 7 agentes y doble
-- auditoría adversarial; la reconciliación P&L dio 0 € de diferencia — estos defectos son
-- todos de la capa forward de la 063, ninguno toca el devengo). Idempotente.
--
-- (a) STLY fantasma: PriceLabs manda cadena VACÍA (no ausencia de campo) cuando no tiene
--     dato del año pasado, así que `"".startsWith("Booked")` daba false y "no gestionábamos
--     el piso" quedaba indistinguible de "estaba libre". v_pricelabs_forward publicaba
--     "0 % de ocupación el año pasado" para Marechal (opera desde dic-2025) y Alexander
--     (oct-2025): un YoY apoyado ahí inventaría +77 pp. Arreglo en dos capas: el sync v3
--     guarda null cuando (fecha − 1 año) < listings.fecha_inicio, y el motor revalida
--     contra fecha_inicio aunque la fila venga vieja.
-- (b) no_vendibles mezclaba dos hechos opuestos: noche BLOQUEADA (decisión nuestra o de
--     la dueña; sin palanca) y noche HUÉRFANA por min-stay (hueco de una noche que nadie
--     puede comprar; la palanca es bajar el mínimo esa noche). Se parten en dos columnas.
--     Además la ÚLTIMA fecha sincronizada sale "unbookable" por artefacto de borde
--     (PriceLabs no ve la noche siguiente): esa noche se cuenta como libre, no huérfana.
-- (c) v_freshness no decía nada de PriceLabs: la portada no podía distinguir dato vivo de
--     foto congelada (y la foto ESTUVO congelada desde el 02/08 sin que nada lo delatara).
-- (d) pricelabs_fotos: foto diaria insert-only del calendario, cimiento del pace (noches
--     ganadas por semana). La serie no se puede reconstruir hacia atrás: cada día sin
--     foto es curva perdida. ~1.460 filas/día (4 pisos × 365 noches).

-- ── 1) Datos: anular el STLY previo a la gestión de cada piso ────────────────────────
update pricelabs_prices p
   set stly_reservado = null, stly_adr = null
  from listings l
 where l.codigo = p.codigo
   and (p.fecha - interval '1 year')::date < l.fecha_inicio
   and (p.stly_reservado is not null or p.stly_adr is not null);

-- ── 2) Motor: f_pricelabs_forward con bloqueadas/huérfanas y STLY honesto ────────────
-- Cambia el juego de columnas → drop + create (el wrapper primero: depende de la función).
drop view if exists v_pricelabs_forward;
drop function if exists f_pricelabs_forward(date, date);

create function f_pricelabs_forward(p_desde date, p_hasta date)
returns table(
  codigo text, noches integer, reservadas integer, bloqueadas integer,
  huerfanas integer, libres integer,
  ocupacion numeric, adr_reservado numeric, precio_medio_libre numeric,
  stly_ocupacion numeric, stly_adr numeric, refreshed_at timestamptz
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with borde as (
    -- última fecha sincronizada por piso: su flag unbookable no es fiable (artefacto)
    select codigo, max(fecha) as fecha_borde from pricelabs_prices group by codigo
  )
  select p.codigo,
         count(*)::integer,
         (count(*) filter (where p.reservado))::integer,
         (count(*) filter (where not p.reservado and p.booking_status = 'Blocked'))::integer,
         (count(*) filter (where not p.reservado and p.booking_status is distinct from 'Blocked'
                             and p.no_vendible and p.fecha < b.fecha_borde))::integer,
         (count(*) filter (where not p.reservado and p.booking_status is distinct from 'Blocked'
                             and (not p.no_vendible or p.fecha >= b.fecha_borde)))::integer,
         round((count(*) filter (where p.reservado))::numeric / count(*), 4),
         round(avg(p.adr) filter (where p.reservado), 2),
         round(avg(p.precio) filter (where not p.reservado and p.booking_status is distinct from 'Blocked'
                                       and (not p.no_vendible or p.fecha >= b.fecha_borde)), 2),
         -- STLY solo sobre noches cuya fecha equivalente del año pasado ya gestionábamos
         -- Y con dato (is not null: una fila sin STLY de la API no es "no vendido").
         -- Si no queda ninguna (MARE/ALEX hasta oct/dic), NULL — nunca un 0 % inventado.
         case when count(*) filter (where p.stly_reservado is not null
                                      and (p.fecha - interval '1 year')::date >= l.fecha_inicio) > 0
              then round((count(*) filter (where p.stly_reservado
                                             and (p.fecha - interval '1 year')::date >= l.fecha_inicio))::numeric
                         / count(*) filter (where p.stly_reservado is not null
                                              and (p.fecha - interval '1 year')::date >= l.fecha_inicio), 4)
              end,
         round(avg(p.stly_adr) filter (where (p.fecha - interval '1 year')::date >= l.fecha_inicio), 2),
         max(p.refreshed_at)
    from pricelabs_prices p
    join listings l on l.codigo = p.codigo
    join borde b on b.codigo = p.codigo
   where p.fecha between p_desde and p_hasta
   group by p.codigo
$$;

create view v_pricelabs_forward as
  select * from f_pricelabs_forward(current_date, current_date + 29);

-- ── 3) v_freshness: el sello de PriceLabs junto al de Guesty ─────────────────────────
-- Columnas NUEVAS al final (create or replace lo permite); las tres primeras, intactas.
create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)                    as last_sync,
  (select max(make_date(anio, mes, 1)) from events)                 as costes_cargados_hasta,
  (select max(date_trunc('month', fecha))::date from bank_deposits) as cierre_hasta,
  (select pricelabs_last_run from sync_state where id = 1)          as pricelabs_last_run,
  (select pricelabs_last_error from sync_state where id = 1)        as pricelabs_last_error,
  (select max(refreshed_at) from pricelabs_prices)                  as pricelabs_refreshed;

-- ── 4) pricelabs_fotos: la foto diaria (solo escribe el sync) ────────────────────────
create table if not exists pricelabs_fotos (
  foto_fecha     date not null,
  codigo         text not null references listings(codigo),
  fecha          date not null,
  precio         numeric(8,2),
  reservado      boolean not null default false,
  no_vendible    boolean not null default false,
  booking_status text,
  primary key (foto_fecha, codigo, fecha)
);
grant select, insert, update, delete on pricelabs_fotos to service_role;

-- ── 5) Permisos (regla 059/061: authenticated SOLO, nunca anon) ──────────────────────
revoke execute on function f_pricelabs_forward(date, date) from public, anon, authenticated;
grant execute on function f_pricelabs_forward(date, date) to authenticated;
grant select on v_pricelabs_forward to authenticated;
-- v_freshness conserva su ACL al hacer replace (anon quedó fuera desde la 059); cinturón:
grant select on v_freshness to authenticated;
-- 065_recobros.sql — registro de recobros: plata adelantada que se repercute (04/08/2026).
--
-- Gastos que Samavi (o Stag de su bolsillo) adelanta y luego repercute a un tercero —
-- hoy, la dueña de JACO. Mientras sean recobrables son NEUTROS para Samavi y NUNCA
-- entran a `events` ni al P&L (precedente: mini UPS 77,00 y aspiradora 130,00, sacados
-- del P&L por la migración 049; acá entran como LIQUIDADOS, ya descontados a la dueña).
--
-- Nace del agujero que la 049 dejó documentado: "lo que se paga por fuera no llega al
-- motor salvo que alguien lo escriba". Los bizums a Agustín salen de la cuenta PERSONAL
-- de Stag: los extractos de Samavi no los traen y la conciliación mensual no los ve.
--
-- Ciclo de vida: PENDIENTE → LIQUIDADO (se le descontó a la dueña; si salió de la cuenta
-- personal, la plata vuelve a Stag o queda en cuenta con el socio — eso lo lleva
-- Confisic, fuera de este repo) o INCOBRABLE (no se acepta el descuento: deja de ser
-- neutro, se carga el gasto en `events` a mano en el cierre y acá queda la marca con
-- resuelto_nota OBLIGATORIA apuntando a ese event — nunca en los dos lados a la vez).
--
-- Revisión adversarial 04/08/2026: security definer en f_recobros (sin él, la vista da
-- 42501 a authenticated — el SQL Editor no lo delata porque consulta como postgres),
-- tope del wrapper sin borde de medianoche UTC, checks de estado simétricos, FK a listings.

-- ── 1) Tabla (cruda: RLS sin policies, el cliente solo lee vista/función) ──────────
create table if not exists recobros (
  id               bigint generated always as identity primary key,
  propiedad_codigo text not null references listings(codigo),
  fecha            date not null,                       -- fecha del pago
  concepto         text not null,                       -- texto que ve el dashboard
  importe          numeric(12,2) not null check (importe > 0),  -- a recuperar; siempre positivo
  pagado_por       text not null default 'STAG_PERSONAL'
                   check (pagado_por in ('STAG_PERSONAL', 'SAMAVI')),
  pagado_a         text,                                -- proveedor (Agustín, comercio…)
  medio            text,                                -- 'bizum' | 'efectivo' | 'tarjeta' | …
  estado           text not null default 'PENDIENTE'
                   check (estado in ('PENDIENTE', 'LIQUIDADO', 'INCOBRABLE')),
  resuelto_fecha   date,                                -- cuándo se liquidó / se dio por incobrable
  resuelto_nota    text,                                -- "descontado en la liquidación de ago-2026" / event cruzado
  notas            text,                                -- interno: NO se expone al cliente
  creado_en        timestamptz not null default now(),
  -- PENDIENTE ⇔ sin fecha de resolución; LIQUIDADO e INCOBRABLE la exigen.
  constraint recobros_estado_fecha
    check ((estado = 'PENDIENTE') = (resuelto_fecha is null)),
  -- INCOBRABLE exige la nota cruzada al event que carga el gasto (si no, se duplica el P&L).
  constraint recobros_incobrable_nota
    check (estado <> 'INCOBRABLE' or resuelto_nota is not null)
);

create index if not exists idx_recobros_lookup on recobros (propiedad_codigo, estado, fecha);

alter table recobros enable row level security;  -- sin policies: inaccesible desde el cliente

-- ── 2) Motor (patrón 060: función f_* parametrizada + vistas wrapper) ──────────────
-- Detalle por rango de FECHA DE PAGO. `notas` queda fuera a propósito (interno).
-- security definer: lee una tabla cruda que authenticated no ve (doctrina 060/064);
-- sin él, el cuerpo corre con los privilegios del que consulta y la vista da 42501.
create or replace function f_recobros(p_desde date, p_hasta date)
returns table (
  id               bigint,
  propiedad_codigo text,
  fecha            date,
  concepto         text,
  importe          numeric,
  pagado_por       text,
  pagado_a         text,
  medio            text,
  estado           text,
  resuelto_fecha   date,
  resuelto_nota    text,
  dias_pendiente   int
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select r.id, r.propiedad_codigo, r.fecha, r.concepto, r.importe,
         r.pagado_por, r.pagado_a, r.medio, r.estado,
         r.resuelto_fecha, r.resuelto_nota,
         case when r.estado = 'PENDIENTE'
              then (current_date - r.fecha)::int end as dias_pendiente
    from recobros r
   where r.fecha between p_desde and p_hasta
   order by r.fecha desc, r.id desc;
$$;

-- Wrapper de detalle: histórico completo, con tope holgado a propósito — un tope
-- current_date (UTC) escondería la fila fechada "hoy Madrid" entre las 00:00 y las
-- 02:00 CEST y desalinearía tarjeta y detalle. El rango fino queda para RPC.
create or replace view v_recobros as
  select * from f_recobros(date '2024-01-01', date '2099-12-31');

-- Pendientes agregados por propiedad — SIN filtro de fecha a propósito: una deuda vieja
-- no puede caerse de la tarjeta por antigüedad, que es exactamente como se pierde.
create or replace view v_recobros_pendientes as
select r.propiedad_codigo,
       count(*)::int                        as pagos,
       sum(r.importe)::numeric(12,2)        as total,
       min(r.fecha)                         as mas_viejo_fecha,
       (current_date - min(r.fecha))::int   as mas_viejo_dias,
       coalesce(sum(r.importe) filter (where r.pagado_por = 'STAG_PERSONAL'), 0)::numeric(12,2)
                                            as de_cuenta_personal
  from recobros r
 where r.estado = 'PENDIENTE'
 group by r.propiedad_codigo;

-- ── 3) Candado (lecciones 056/059/061: nada nace con permisos) ─────────────────────
-- GRANT a authenticated SOLO — jamás `to anon` (reabriría lectura sin login).
revoke execute on function f_recobros(date, date) from public, anon, authenticated;
grant  execute on function f_recobros(date, date) to authenticated;
grant select on v_recobros            to authenticated;
grant select on v_recobros_pendientes to authenticated;

-- ── 4) Seed (idempotente): el estado 2026 de la columna GASTOS de la cuenta ────────
-- Pendientes: los dos bizums a Agustín (muebles de los 2 baños descolgándose — faltan
-- las patas, generará otro recobro — y rieles inferiores de las 2 duchas repegados).
-- Liquidados: los dos descuentos históricos de la cuenta corriente de la dueña
-- (hoja 2026_JACOBINE_MADRE_INGRESOS), que la 049 sacó del P&L por neutros.
insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, v.pagado_por, v.pagado_a,
       v.medio, v.estado, v.resuelto_fecha, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2026-07-23',
   'Arreglo muebles de baño y rieles de ducha — mano de obra (1er pago)',
   40.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Muebles de los 2 baños descolgandose de la pared y rieles inferiores de las 2 duchas repegados. Reportado por Stag el 04/08/2026.'),
  ('1A_JACO', date '2026-08-04',
   'Arreglo muebles de baño y rieles de ducha — mano de obra (2º pago)',
   60.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Queda pendiente comprar las patas de los muebles (recobro aparte cuando se compren).'),
  ('1A_JACO', date '2026-02-12',
   'Mini UPS + instalación (reposición)',
   77.00, 'SAMAVI', 'Amazon + Agustín (instalación)', 'tarjeta',
   'LIQUIDADO', date '2026-02-28',
   'Descontado en la cuenta corriente de la dueña: GASTOS feb-2026 "compra mini UPS + instalación" (hoja 2026_JACOBINE_MADRE_INGRESOS).',
   'Amazon 56,99 (Revolut tarjeta Virtual, 12/02) + 20,00 a Agustin en efectivo (bolsillo de Stag, 02/03) = 76,99; a la duena se le descontaron 77,00 (1 centimo de redondeo de Stag). Estaba cargado por error como coste de Nicasio hasta la migracion 049.'),
  ('1A_JACO', date '2026-02-28',
   'Aspiradora (reposición)',
   130.00, 'SAMAVI', 'Amazon', 'tarjeta',
   'LIQUIDADO', date '2026-03-31',
   'Descontado en la cuenta corriente de la dueña: GASTOS mar-2026 "aspiradora reposición" (hoja 2026_JACOBINE_MADRE_INGRESOS).',
   'Cargo Revolut "Www.amazon* Te5ke0el5" 129,98 del 28/02 (liquidado el 01/03); a la duena se le descontaron 130,00. Estaba cargado por error como coste de Nicasio hasta la migracion 049.')
) as v(cod, fecha, concepto, importe, pagado_por, pagado_a, medio, estado, resuelto_fecha, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);
-- 066_cuenta_duena.sql — la cuenta corriente de la dueña de JACO, digitalizada (04/08/2026).
--
-- Pedido de Stag: ver dentro de la ficha de Jacobine cuánto dinero le pertenece a la
-- dueña en el año, y qué se le descuenta: la refactura de limpieza (700 €/mes) y los
-- gastos que Samavi adelanta y repercute (recobros de la 065: mini UPS, aspiradora,
-- bizums de Agustín cuando se liquiden).
--
-- SEMÁNTICA (etiquetada así en el UI — no confundir capas):
--   · Es la cuenta DEVENGADA del período: lo que le corresponde por las noches dormidas
--     (mismo prorrateo devengo/noche del motor) menos lo que se le descuenta. NO resta
--     las transferencias que Stag ya le hizo — los pagos viven en los bancos, no acá.
--   · pasivo_alquiler = pasivo_madre de la 033 prorrateado por noche:
--     host_payout − (host_payout + host_service_fee) × 30,25 %. La comisión se calcula
--     sobre la base con comisión de canal incluida (config Guesty verificada), o sea que
--     la comisión de canal la asume la dueña; el IVA va dentro del 30,25 (021).
--   · pasivo_cancelaciones = su parte de los cobros retenidos de canceladas (misma base
--     y mes de check-in que v_ingreso_cancelaciones, 047).
--   · limpieza = listings.refactura_limpieza_mes (columna nueva; 700 en JACO — el neto
--     Samavi vs nómina de José ya está en events "Modesto neto", capa Samavi, NO acá).
--   · descuentos = recobros LIQUIDADOS por mes de resolución (los PENDIENTES no bajan
--     la cuenta hasta que se liquidan; el UI los muestra aparte).
--   · listings.pasivo_base (20.985,83 en JACO) = saldo acumulado pre-2026 según el
--     Excel, SIN verificar contra banco: queda como referencia y NO se suma — 2025 y
--     antes vive en el proyecto de Admin & Fiscal (regla de la 049).

-- ── 1) La refactura de limpieza como parámetro del motor, no número mágico ─────────
alter table listings add column if not exists refactura_limpieza_mes numeric(12,2) not null default 0;
update listings set refactura_limpieza_mes = 700.00 where codigo = '1A_JACO';

-- ── 2) f_cuenta_duena(desde, hasta) — mensual, solo propiedades en modelo comisión ──
create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (
  codigo               text,
  anio                 int,
  mes                  int,
  pasivo_alquiler      numeric,   -- + le pertenece por las noches del mes
  pasivo_cancelaciones numeric,   -- + su parte de cobros retenidos de canceladas
  limpieza             numeric,   -- − refactura de limpieza del mes
  descuentos           numeric,   -- − recobros liquidados en el mes
  neto                 numeric    -- = a su favor en el mes (devengado)
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with noches as (
    select ri.codigo,
           extract(year  from g.d)::int as anio,
           extract(month from g.d)::int as mes,
           sum(ri.pasivo_madre / (ri.checkout_local - ri.checkin_local)) as pasivo
      from v_reservation_income ri,
           lateral generate_series(ri.checkin_local::timestamp,
                                   (ri.checkout_local - 1)::timestamp,
                                   interval '1 day') g(d)
     where ri.pasivo_madre <> 0
       and g.d::date between p_desde and p_hasta
     group by 1, 2, 3
  ),
  canc as (
    -- misma población y mes (check-in) que v_ingreso_cancelaciones (047)
    select r.codigo,
           extract(year  from r.checkin_local)::int as anio,
           extract(month from r.checkin_local)::int as mes,
           sum(coalesce(r.host_payout, 0)
               - (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0)) * l.comision_pct) as pasivo
      from reservations r
      join listings l on l.codigo = r.codigo
     where l.modelo = 'comision'
       and r.status = 'canceled'
       and coalesce(r.host_payout, 0) <> 0
       and r.checkin_local is not null
       and r.checkin_local between p_desde and p_hasta
     group by 1, 2, 3
  ),
  liq as (
    select rc.propiedad_codigo as codigo,
           extract(year  from rc.resuelto_fecha)::int as anio,
           extract(month from rc.resuelto_fecha)::int as mes,
           sum(rc.importe) as descuentos
      from recobros rc
     where rc.estado = 'LIQUIDADO'
       and rc.resuelto_fecha between p_desde and p_hasta
     group by 1, 2, 3
  )
  select s.codigo, s.anio, s.mes,
         round(coalesce(n.pasivo, 0)::numeric, 2)                    as pasivo_alquiler,
         round(coalesce(c.pasivo, 0)::numeric, 2)                    as pasivo_cancelaciones,
         -l.refactura_limpieza_mes                                   as limpieza,
         -round(coalesce(q.descuentos, 0)::numeric, 2)               as descuentos,
         round((coalesce(n.pasivo, 0) + coalesce(c.pasivo, 0)
                - l.refactura_limpieza_mes - coalesce(q.descuentos, 0))::numeric, 2) as neto
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join noches n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
    left join canc   c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
    left join liq    q on q.codigo = s.codigo and q.anio = s.anio and q.mes = s.mes
   where l.modelo = 'comision'
   order by s.codigo, s.anio, s.mes
$$;

-- Wrapper "año en curso", mismo rango que los demás wrappers de la 060.
create or replace view v_cuenta_duena as
  select * from f_cuenta_duena(date_trunc('year', now())::date, now()::date);

-- ── 3) Candado (056/059/061): authenticated SOLO, jamás anon ───────────────────────
revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
grant select on v_cuenta_duena to authenticated;
-- 067_cancelaciones_cuenta_duena.sql — la cuenta de la dueña hereda el filtro de la 047 (04/08/2026).
--
-- La revisión adversarial de la 066 lo demostró en producción: el CTE de cancelaciones
-- usaba el predicado pre-047 (`host_payout <> 0` a secas) y dejaba entrar la manual
-- cancelada fantasma de dic-2025 (GY con payout copiado 342,00 y cobrado 0,00): cualquier
-- rango por RPC que pisara dic-2025 le acreditaba a la dueña 238,55 € que nunca
-- existieron, y la PRÓXIMA manual cancelada de JACO con payout copiado contaminaría el
-- año en curso, divergiendo del P&L (que vía 047 no la reconoce).
--
-- Dos correcciones, solo en el CTE canc:
--   1) Predicado EXACTO de v_ingreso_cancelaciones (047): total_paid <> 0, o no-manual
--      con payout <> 0.
--   2) Atribución por MES de check-in (como el P&L agrupa), no por día: una retenida con
--      check-in más adelante dentro del mes en curso entraba al P&L (su mes está en el
--      spine) pero no a la cuenta — divergencia temporal entre capas.
-- Identidad verificada en las filas legítimas: parte dueña + ingreso Samavi + IVA =
-- host_payout retenido (ene: 210,68 + 103,28 + 21,69 = 335,65 ✓).

create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (
  codigo               text,
  anio                 int,
  mes                  int,
  pasivo_alquiler      numeric,
  pasivo_cancelaciones numeric,
  limpieza             numeric,
  descuentos           numeric,
  neto                 numeric
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with noches as (
    select ri.codigo,
           extract(year  from g.d)::int as anio,
           extract(month from g.d)::int as mes,
           sum(ri.pasivo_madre / (ri.checkout_local - ri.checkin_local)) as pasivo
      from v_reservation_income ri,
           lateral generate_series(ri.checkin_local::timestamp,
                                   (ri.checkout_local - 1)::timestamp,
                                   interval '1 day') g(d)
     where ri.pasivo_madre <> 0
       and g.d::date between p_desde and p_hasta
     group by 1, 2, 3
  ),
  canc as (
    -- población y mes idénticos a v_ingreso_cancelaciones (047)
    select r.codigo,
           extract(year  from r.checkin_local)::int as anio,
           extract(month from r.checkin_local)::int as mes,
           sum(coalesce(r.host_payout, 0)
               - (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0)) * l.comision_pct) as pasivo
      from reservations r
      join listings l on l.codigo = r.codigo
     where l.modelo = 'comision'
       and r.status = 'canceled'
       and (coalesce(r.total_paid, 0) <> 0
            or (r.source <> 'manual' and coalesce(r.host_payout, 0) <> 0))
       and r.checkin_local is not null
       and date_trunc('month', r.checkin_local)
           between date_trunc('month', p_desde::timestamp) and date_trunc('month', p_hasta::timestamp)
     group by 1, 2, 3
  ),
  liq as (
    select rc.propiedad_codigo as codigo,
           extract(year  from rc.resuelto_fecha)::int as anio,
           extract(month from rc.resuelto_fecha)::int as mes,
           sum(rc.importe) as descuentos
      from recobros rc
     where rc.estado = 'LIQUIDADO'
       and rc.resuelto_fecha between p_desde and p_hasta
     group by 1, 2, 3
  )
  select s.codigo, s.anio, s.mes,
         round(coalesce(n.pasivo, 0)::numeric, 2)                    as pasivo_alquiler,
         round(coalesce(c.pasivo, 0)::numeric, 2)                    as pasivo_cancelaciones,
         -l.refactura_limpieza_mes                                   as limpieza,
         -round(coalesce(q.descuentos, 0)::numeric, 2)               as descuentos,
         round((coalesce(n.pasivo, 0) + coalesce(c.pasivo, 0)
                - l.refactura_limpieza_mes - coalesce(q.descuentos, 0))::numeric, 2) as neto
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join noches n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
    left join canc   c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
    left join liq    q on q.codigo = s.codigo and q.anio = s.anio and q.mes = s.mes
   where l.modelo = 'comision'
   order by s.codigo, s.anio, s.mes
$$;

-- create or replace conserva los grants, pero el repo no deja candados implícitos:
revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
-- 068_revoke_public_funciones_recobros.sql — cierra la fuga /rpc/ de las f_ de la 065/066 (04/08/2026).
--
-- La revisión adversarial lo explotó en producción con la anon key (POST /rest/v1/rpc/
-- f_recobros → HTTP 200 con los recobros completos, sin login): f_recobros y
-- f_cuenta_duena nacieron ejecutables por PUBLIC (y anon lo hereda), y como son SECURITY
-- DEFINER saltan el RLS de recobros.
--
-- LECCIÓN (asentada en CLAUDE.md): el candado 061 NO alcanza para funciones. El default
-- CABLEADO de Postgres da EXECUTE a PUBLIC en cada función nueva y el pg_default_acl de
-- la 061 se SUMA a ese default en vez de anularlo. Por eso las 063/064 llevan un
-- `revoke execute … from public, anon, authenticated` explícito antes del grant; las
-- 065/066/067 lo omitieron. El smoke test "anon da 42501" solo probó las VISTAS, nunca
-- el camino /rpc/ — el punto ciego que la propia 061 documenta.
--
-- Se mantiene el grant a authenticated: las vistas wrapper (v_recobros, v_cuenta_duena)
-- comprueban ese EXECUTE contra el usuario que las consulta.
revoke execute on function f_recobros(date, date)     from public, anon;
revoke execute on function f_cuenta_duena(date, date) from public, anon;
-- 069_secreto_compartido_edge_functions.sql — cierra las Edge Functions (04/08/2026).
--
-- LA AUDITORÍA LO REPRODUJO DESDE INTERNET, SIN NINGUNA CREDENCIAL:
--   curl -X POST https://<ref>.supabase.co/functions/v1/guesty-sync
--   → HTTP 200 {"ok":true,...} y sync_state quedó escrito por esa request anónima.
-- Un GET pelado (pegar la URL en el navegador) hacía lo mismo.
--
-- DOS TRAMPAS QUE HAY QUE ENTENDER PARA NO REPETIRLO:
--
-- 1) guesty-sync tenía verify_jwt=false y el handler era `Deno.serve(async () => {…})`:
--    descartaba la request entera, así que no había ni cabecera que comprobar. El
--    comentario de config.toml decía "se protege con el secret de service_role" — era
--    FALSO, no existía tal comprobación.
--
-- 2) verify_jwt=true NO significa "solo usuarios logueados". El gateway solo valida que
--    el JWT esté bien FIRMADO, y la anon key es exactamente eso: un JWT válido del
--    proyecto, horneado en el bundle público del dashboard. Por eso pricelabs-sync, que
--    sí tenía verify_jwt=true, también se disparaba desde fuera: el auditor lo hizo con la
--    key que descargó del propio sitio. verify_jwt sube el listón de "cualquiera del
--    planeta" a "cualquiera que abrió el dashboard una vez". No es una puerta.
--
-- POR QUÉ IMPORTA: las dos funciones corren con SUPABASE_SERVICE_ROLE_KEY (bypassa RLS) y
-- escriben en reservations, listings, sync_state, pricelabs_prices y pricelabs_fotos.
-- Además, martillar el endpoint quema la cuota de la API de Guesty/PriceLabs y deja el
-- dashboard con datos viejos.
--
-- EL ARREGLO: un secreto propio que no es ninguna de las keys públicas. El cron lo manda
-- en la cabecera x-sync-secret; el handler pregunta a la base si es correcto ANTES de
-- hacer nada. El secreto vive cifrado en Vault y nunca sale: f_sync_secret_ok solo
-- responde sí/no y solo service_role puede ejecutarla (ni anon ni el dashboard pueden
-- siquiera probar a ciegas).
--
-- OJO AL ORDEN AL APLICARLO (si hay que rehacerlo): primero esta migración y la
-- reprogramación del cron (paso 4), DESPUÉS el deploy de las funciones. Al revés, el
-- sync queda rechazándose a sí mismo hasta que el cron se actualice, y en silencio.

-- 1) Secreto aleatorio de 32 bytes, vía la API oficial de Vault (el insert directo en
--    vault.secrets choca con los permisos de _crypto_aead_det_noncegen).
--    Idempotente: si ya existe, NO lo rota (rotarlo sin redesplegar rompería el cron).
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'sync_shared_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'sync_shared_secret',
      'Secreto compartido cron -> Edge Functions (guesty-sync, pricelabs-sync). Migracion 069.'
    );
  end if;
end $$;

-- 2) El verificador. security definer porque vault no es legible por el llamador.
--    Devuelve solo un booleano: el secreto no se puede extraer preguntando.
create or replace function f_sync_secret_ok(p_secreto text)
returns boolean
language sql stable
security definer set search_path = public, vault, pg_temp
as $$
  select coalesce(length(p_secreto), 0) >= 32
     and exists (
       select 1 from vault.decrypted_secrets
        where name = 'sync_shared_secret'
          and decrypted_secret = p_secreto
     );
$$;

-- 3) Candado (lección 068: el default cableado de Postgres da EXECUTE a PUBLIC).
--    Solo service_role — o sea, solo las Edge Functions.
revoke execute on function f_sync_secret_ok(text) from public, anon, authenticated;
grant  execute on function f_sync_secret_ok(text) to service_role;

-- 4) Reprogramación de los dos cron jobs — ver supabase/cron_setup.sql, que quedó
--    actualizado con el esquema definitivo (cabeceras desde Vault, sin keys inline).
--    No va acá porque cron.schedule no es idempotente y la URL lleva el project ref.

-- ── VERIFICACIÓN (hecha el 04/08/2026, tras desplegar las funciones) ────────────────
--   curl -X POST .../guesty-sync                                   → 401  (era 200)
--   curl .../guesty-sync                                           → 401  (era 200)
--   curl -X POST .../guesty-sync -H "Authorization: Bearer <anon>"  → 401
--   curl -X POST .../pricelabs-sync -H "Authorization: Bearer <anon>" → 401  (era 500, o sea entraba)
--   net.http_post con las cabeceras del cron (incluido x-sync-secret) → 200 {"ok":true}
-- 070_rls_tablas_huerfanas.sql — segunda capa en las tres tablas sin RLS (04/08/2026).
--
-- La auditoría las encontró y sus verificadores las descartaron como "no es agujero", con
-- razón: no tienen ningún GRANT para anon (candado 056/059), así que hoy nadie las lee.
-- Se activa igual porque este repo tiene un historial de permisos que se regalan solos
-- (008, 056, 061 y 068, todas fugas reales): el RLS es lo que convierte un GRANT puesto
-- por descuido en un no-evento en vez de en una fuga. Es el patrón de todas las demás
-- tablas crudas desde la 002.
--
-- No rompe nada — verificado antes de aplicar:
--   · pricelabs_prices / pricelabs_fotos: las escribe la Edge Function con service_role
--     (bypassa RLS) y las lee f_pricelabs_forward, security definer con owner postgres.
--   · auth_email_allowlist: la consulta el trigger f_auth_bloquear_no_invitados, que es
--     security definer y cuyo owner (postgres) tiene BYPASSRLS = true. Si no lo fuera,
--     activar RLS acá habría roto el alta de usuarios en silencio.
-- Sin policies: nadie que no bypasee RLS ve una sola fila.
alter table pricelabs_prices     enable row level security;
alter table pricelabs_fotos      enable row level security;
alter table auth_email_allowlist enable row level security;

-- Comprobado después, como authenticated: v_pricelabs_forward, v_freshness, v_kpis,
-- v_cuenta_duena, v_recobros, v_forward y v_alertas siguen devolviendo sus filas.
-- 071_cuenta_duena_2025.sql — la cuenta de la dueña arranca en 2025 (05/08/2026).
--
-- Stag llevaba esta cuenta a mano en la pestaña 2025_JACOBINE_MADRE_INGRESOS del Sheets
-- "STAG PROPERTIES MGMT — INGRESOS Y FINANZAS" (Drive 1qq89woZ9fMEXLUYGGUHiXPa_H8NbKeob).
-- Su planilla cerraba 2025 con 9.834,67 € a favor de la dueña. Verificado contra Guesty
-- reserva por reserva: las NOCHES coinciden los 7 meses (6/24/25/28/29/28/17) y 4 de 7
-- meses cuadran al céntimo en importe.
--
-- Las tres diferencias, identificadas una por una:
--   · 415,60 € — reserva HMJFKCR9FX (30/07→02/08/2025). La planilla la puso en agosto
--     (criterio del reporte de Airbnb); Guesty la tiene con check-in en julio. NO es un
--     error: es criterio, y se disuelve al imputar por noche.
--   · 1.183,33 € — reserva HM28X3ZTRT (30/12/2025→08/01/2026, 9 noches, bruto 2.948,50).
--     La planilla la contó entera en diciembre 2025; por noche son 2 noches de 2025 y 7
--     de 2026.
--   · 248,97 € de bruto (200,00 en agosto + 48,97 en septiembre) SIN respaldo en Guesty:
--     no hay reservas directas ni canceladas que los expliquen (comprobado: las canceladas
--     de 2025 tienen todas bruto y cobrado 0). Son ajustes manuales de la planilla.
--     Efecto sobre la dueña: 173,66 € acreditados de más.
--
-- Reconciliación exacta:
--   9.834,67 (planilla) − 173,66 (ajustes sin respaldo) − 1.183,33 (noches de 2026)
--   = 8.477,68 € — que es justo lo que arroja este motor. Cierra al céntimo.
--
-- Decisiones de Stag (05/08/2026): imputar POR NOCHE DORMIDA (mismo criterio que todo el
-- dashboard) y acreditarle su parte de las cancelaciones retenidas también en 2025 — en
-- 2025 no hubo ninguna cobrada, así que esa regla no mueve ese año.
--
-- 2025 NO se puede modelar con la refactura fija de 700 €/mes: ese importe se fijó en
-- noviembre de 2025; antes la limpieza se le pasaba a coste real y variaba mes a mes.

-- ── 1) Limpieza mensual real (sobreescribe la cuota fija de listings) ──────────────
create table if not exists duena_limpieza (
  propiedad_codigo text not null references listings(codigo),
  anio             int  not null,
  mes              int  not null check (mes between 1 and 12),
  importe          numeric(12,2) not null check (importe >= 0),
  nota             text,
  primary key (propiedad_codigo, anio, mes)
);
alter table duena_limpieza enable row level security;  -- sin policies: solo vía función

insert into duena_limpieza (propiedad_codigo, anio, mes, importe, nota) values
  ('1A_JACO', 2025,  6, 299.48, 'Coste real de limpieza (planilla 2025). Aun sin cuota fija.'),
  ('1A_JACO', 2025,  7, 592.90, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025,  8, 508.20, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025,  9, 707.85, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025, 10, 592.90, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025, 11, 700.00, 'Desde noviembre 2025 se fija la cuota mensual de 700 (nomina de Jose Modesto).'),
  ('1A_JACO', 2025, 12, 700.00, 'Cuota fija de 700.')
on conflict (propiedad_codigo, anio, mes) do nothing;

-- ── 2) Gastos 2025 repercutidos, como recobros ya liquidados ──────────────────────
-- Van a `recobros`, no a events: son plata que Samavi adelantó y le descontó a la dueña,
-- o sea neutros para el P&L — el mismo criterio que el mini UPS y la aspiradora de 2026.
insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, 'SAMAVI', v.pagado_a, v.medio,
       'LIQUIDADO', v.resuelto, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2025-05-31', 'Puesta a punto del piso (gastos de arranque)', 272.25,
   null::text, null::text, date '2025-06-30',
   'Descontado en la cuenta de la dueña: columna LIMPIEZA de abril-mayo 2025, nota "Gastos de arranque".',
   'La planilla lo anota en abril-mayo, antes de la primera reserva (JACO arranca el 01/06/2025), asi que en la cuenta cae en junio, el primer mes con actividad.'),
  ('1A_JACO', date '2025-07-31', 'Cortinas', 2044.00,
   'SOOFA', 'transferencia', date '2025-07-31',
   'Descontado en la cuenta de la dueña: columna GASTOS de julio 2025, nota "Cortinas".',
   'Gasto de equipamiento repercutido integro a la dueña.'),
  ('1A_JACO', date '2025-11-30', 'Reparación lavadora y puerta corredera del baño', 83.00,
   null, null, date '2025-11-30',
   'Descontado en la cuenta de la dueña: columna GASTOS de noviembre 2025.',
   'Nota de la planilla: "Lavadora perdida de agua, Reparacion puerta corrediza bano secundario".'),
  ('1A_JACO', date '2025-12-31', 'Equipamiento varios (wifi, calefactores, toalleros, CEE, nota simple)', 409.14,
   null, null, date '2025-12-31',
   'Descontado en la cuenta de la dueña: columna GASTOS de diciembre 2025.',
   'Nota de la planilla: "Wifi, ZH Vela, Calefactores, Wifi repetidor, Toalleros, Soporte papel higenico, CEE, Nota Simple Registro de la propiedad".')
) as v(cod, fecha, concepto, importe, pagado_a, medio, resuelto, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);

-- ── 3) El motor usa la limpieza real cuando existe; si no, la cuota fija ───────────
create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (
  codigo               text,
  anio                 int,
  mes                  int,
  pasivo_alquiler      numeric,
  pasivo_cancelaciones numeric,
  limpieza             numeric,
  descuentos           numeric,
  neto                 numeric
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with noches as (
    select ri.codigo,
           extract(year  from g.d)::int as anio,
           extract(month from g.d)::int as mes,
           sum(ri.pasivo_madre / (ri.checkout_local - ri.checkin_local)) as pasivo
      from v_reservation_income ri,
           lateral generate_series(ri.checkin_local::timestamp,
                                   (ri.checkout_local - 1)::timestamp,
                                   interval '1 day') g(d)
     where ri.pasivo_madre <> 0
       and g.d::date between p_desde and p_hasta
     group by 1, 2, 3
  ),
  canc as (
    -- población y mes idénticos a v_ingreso_cancelaciones (047)
    select r.codigo,
           extract(year  from r.checkin_local)::int as anio,
           extract(month from r.checkin_local)::int as mes,
           sum(coalesce(r.host_payout, 0)
               - (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0)) * l.comision_pct) as pasivo
      from reservations r
      join listings l on l.codigo = r.codigo
     where l.modelo = 'comision'
       and r.status = 'canceled'
       and (coalesce(r.total_paid, 0) <> 0
            or (r.source <> 'manual' and coalesce(r.host_payout, 0) <> 0))
       and r.checkin_local is not null
       and date_trunc('month', r.checkin_local)
           between date_trunc('month', p_desde::timestamp) and date_trunc('month', p_hasta::timestamp)
     group by 1, 2, 3
  ),
  liq as (
    select rc.propiedad_codigo as codigo,
           extract(year  from rc.resuelto_fecha)::int as anio,
           extract(month from rc.resuelto_fecha)::int as mes,
           sum(rc.importe) as descuentos
      from recobros rc
     where rc.estado = 'LIQUIDADO'
       and rc.resuelto_fecha between p_desde and p_hasta
     group by 1, 2, 3
  )
  select s.codigo, s.anio, s.mes,
         round(coalesce(n.pasivo, 0)::numeric, 2)                    as pasivo_alquiler,
         round(coalesce(c.pasivo, 0)::numeric, 2)                    as pasivo_cancelaciones,
         -- la limpieza real del mes manda; si no hay fila, la cuota fija de listings
         -coalesce(dl.importe, l.refactura_limpieza_mes)             as limpieza,
         -round(coalesce(q.descuentos, 0)::numeric, 2)               as descuentos,
         round((coalesce(n.pasivo, 0) + coalesce(c.pasivo, 0)
                - coalesce(dl.importe, l.refactura_limpieza_mes)
                - coalesce(q.descuentos, 0))::numeric, 2)            as neto
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join duena_limpieza dl
           on dl.propiedad_codigo = s.codigo and dl.anio = s.anio and dl.mes = s.mes
    left join noches n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
    left join canc   c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
    left join liq    q on q.codigo = s.codigo and q.anio = s.anio and q.mes = s.mes
   where l.modelo = 'comision'
   order by s.codigo, s.anio, s.mes
$$;

-- ── 4) La vista deja de ser "año en curso": la cuenta es acumulativa desde el inicio ──
-- f_spine ya recorta por listings.fecha_inicio, así que arrancar en 2024 no inventa meses.
create or replace view v_cuenta_duena as
  select * from f_cuenta_duena(date '2024-01-01', (now() at time zone 'Europe/Madrid')::date);

revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
grant  select on v_cuenta_duena to authenticated;

-- Resultado verificado en producción: 2025 = 8.477,68 € · 2026 (ene-jul) = 18.878,59 €
-- Total adeudado a la dueña, sin descontar pagos (no se le transfirió nada): 27.356,27 €
-- 072_pricelabs_pantalla.sql — API key en Vault + la pantalla de precios (05/08/2026).
--
-- Contexto: la fase B de PriceLabs (063/064) llevaba desde el 02/08 con el sync escrito
-- pero SIN la API key y, sobre todo, sin ninguna página que mostrara el dato — un grep de
-- "pricelabs" en web/ daba 0 resultados. Stag preguntó si valía la pena pagar los 4 USD/mes
-- y la respuesta honesta era "hoy no, porque no se ve en ningún lado". Pasó la key y pidió
-- la pantalla en el mismo movimiento.
--
-- LA KEY VA CIFRADA EN VAULT, no como env var ni en el repo: f_pricelabs_key() la entrega
-- solo a service_role y la Edge Function la pide por RPC (v5 de pricelabs-sync). Ventaja
-- sobre el secret de Supabase: se rota con un UPDATE en Vault, sin tocar el panel ni
-- redesplegar la función. Se mantiene el fallback a la env var por compatibilidad.
--
-- QUÉ RESPONDE LA PANTALLA: PriceLabs calcula un precio recomendado por noche, pero los
-- suelos manuales (los que Stag fijó el 03/08) lo pisan. Cuando el suelo queda por DEBAJO
-- de la recomendación en una noche que sigue LIBRE, esa noche se venderá más barata de lo
-- que el mercado admitiría. Al primer sync real: 22 noches en 60 días, 608 € de diferencia
-- (Jacobine 345 · Marechal 104 · Alexander 83 · Nicasio 76).
--
-- Todo esto es FORWARD y operativo: nunca entra al P&L devengado (regla del CLAUDE.md).

-- ── 1) La API key, cifrada. El valor NO va en el repo: se carga una vez a mano.
--    Para (re)cargarla o rotarla:
--      select vault.create_secret('<API_KEY>', 'pricelabs_api_key', 'PriceLabs API');
--      -- o, si ya existe:  update vault.secrets set secret = '<NUEVA>' where name = 'pricelabs_api_key';
create or replace function f_pricelabs_key()
returns text
language sql stable
security definer set search_path = public, vault, pg_temp
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'pricelabs_api_key';
$$;

revoke execute on function f_pricelabs_key() from public, anon, authenticated;
grant  execute on function f_pricelabs_key() to service_role;   -- solo la Edge Function

-- ── 2) Noche por noche: qué revisar y cuánto vale ─────────────────────────────────
create or replace function f_pricelabs_oportunidades(p_dias int default 60)
returns table (
  codigo        text,
  fecha         date,
  dias_hasta    int,
  publicado     numeric,
  recomendado   numeric,
  diferencia    numeric,
  min_stay      numeric,
  demanda       text,
  stly_reservado boolean
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select p.codigo,
         p.fecha,
         (p.fecha - (now() at time zone 'Europe/Madrid')::date)::int as dias_hasta,
         p.precio_usuario                       as publicado,
         p.precio_base                          as recomendado,
         round(p.precio_base - p.precio_usuario, 0) as diferencia,
         p.min_stay,
         p.demanda,
         p.stly_reservado
    from pricelabs_prices p
   where p.fecha >= (now() at time zone 'Europe/Madrid')::date
     and p.fecha <  (now() at time zone 'Europe/Madrid')::date + p_dias
     and not p.reservado
     and not p.no_vendible                       -- las bloqueadas no tienen palanca de precio
     and p.precio_usuario is not null
     and p.precio_base   is not null
     and p.precio_base > p.precio_usuario        -- solo lo que deja plata sobre la mesa
   order by p.fecha, p.codigo;
$$;

create or replace view v_pricelabs_oportunidades as
  select * from f_pricelabs_oportunidades(60);

-- ── 3) Resumen por piso, para el titular de la pantalla ───────────────────────────
create or replace view v_pricelabs_resumen as
with op as (
  select codigo, count(*)::int as noches, sum(diferencia) as euros,
         min(fecha) as primera, min(dias_hasta) as dias_primera
    from f_pricelabs_oportunidades(60)
   group by 1
),
fwd as (
  select codigo, reservadas, bloqueadas, huerfanas, libres, ocupacion,
         adr_reservado, stly_ocupacion, stly_adr, refreshed_at
    from v_pricelabs_forward
)
select f.codigo,
       coalesce(o.noches, 0)::int             as noches_baratas,
       coalesce(o.euros, 0)::numeric(12,0)    as euros_sobre_la_mesa,
       o.primera                              as primera_fecha,
       o.dias_primera,
       f.reservadas, f.bloqueadas, f.huerfanas, f.libres,
       f.ocupacion, f.adr_reservado,
       f.stly_ocupacion, f.stly_adr,
       f.refreshed_at
  from fwd f
  left join op o on o.codigo = f.codigo;

-- ── 4) Candado (068: toda f_ nueva nace ejecutable por PUBLIC) ────────────────────
revoke execute on function f_pricelabs_oportunidades(int) from public, anon, authenticated;
grant  execute on function f_pricelabs_oportunidades(int) to authenticated;
grant  select on v_pricelabs_oportunidades to authenticated;
grant  select on v_pricelabs_resumen       to authenticated;
