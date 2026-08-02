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
