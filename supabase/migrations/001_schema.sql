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
