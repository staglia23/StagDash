-- 094_ano_contra_ano.sql — el año contra el año pasado, en tres espejos (decisión Stag, 01/09/2026).
--
-- ── QUÉ TRAE ────────────────────────────────────────────────────────────────────
-- 1) listings.dormitorios — la categoría del compset de PriceLabs se elige por nº de
--    dormitorios (confirmados contra PriceLabs el 01/09: NICA/ALEX/MARE 1, JACO 3).
-- 2) pricelabs_mercado — serie MENSUAL del barrio por piso (bloque "Market KPI" del
--    neighborhood data del Customer API: revenue, noches vendidas/disponibles, booking
--    window, LOS). ~25 meses hacia atrás. La escribe pricelabs-sync en su corrida diaria.
-- 3) pricelabs_mercado_fotos — foto diaria insert-only de los percentiles de precio
--    FUTUROS del barrio (25/50/75/90 + mediana pagada). PriceLabs no da su histórico:
--    igual que pricelabs_fotos (064), empieza a acumularse hoy y no se reconstruye
--    hacia atrás.
-- 4) f_yoy_mensual — devengado por noche del motor (v_reservation_nights) con ADR SIN
--    limpieza (alojamiento de money_raw, patrón 032), comparable con el mercado, que
--    tampoco la incluye. Columnas _ly (mismo mes del año previo) y flags de
--    comparabilidad: piso sin año previo → NULL, nunca un 0 inventado (cicatriz 064).
-- 5) f_pace_yoy — lo ya vendido por mes futuro vs cómo CERRÓ ese mes el año pasado
--    (pricelabs_prices con las guardas 064: STLY nulo antes de fecha_inicio).
-- 6) f_pricelabs_mercado — la serie del barrio con su año previo al lado.
-- 7) v_freshness — columna mercado_synced AL FINAL (create or replace solo anexa).
--
-- El YoY de margen sigue VETADO (spec §5.5: costes 2025 sin cargar). Esto es ingreso/
-- noches/ADR/ocupación por piso, like-for-like; el pace es dato forward y en pantalla
-- va etiquetado "ya reservado" — nunca entra al P&L devengado.
--
-- El índice macro regional (STR Index Madrid/Andalucía) NO está en el Customer API
-- (verificado 01/09: solo existe vía MCP o CSV manual) — queda fuera del sync.

-- ── 1) Dormitorios: la llave de la categoría del compset ───────────────────────
alter table listings add column if not exists dormitorios integer;

update listings set dormitorios = 1 where codigo in ('1A_NICA', '4B_ALEX', '3G_MARE') and dormitorios is distinct from 1;
update listings set dormitorios = 3 where codigo = '1A_JACO' and dormitorios is distinct from 3;

-- ── 2) La serie mensual del barrio (RAW, escribe solo la Edge Function) ─────────
create table if not exists pricelabs_mercado (
  codigo             text not null references listings(codigo),
  mes                date not null,             -- primer día del mes
  categoria          text not null,             -- categoría de dormitorios usada ("1", "3"…)
  n_listings         integer,                   -- tamaño del compset
  noches_vendidas    numeric,
  noches_disponibles numeric,
  revenue            numeric,                   -- EUR, alojamiento sin limpieza
  booking_window     numeric,                   -- mediana de días reserva→estancia
  los                numeric,                   -- estancia media (noches/reserva)
  fuente             text,                      -- "Nearby Listings" / "Market Dashboard: …"
  synced_at          timestamptz not null default now(),
  primary key (codigo, mes)
);
grant select, insert, update, delete on pricelabs_mercado to service_role;

-- Foto diaria de los percentiles forward: el cimiento de la "mediana pagada histórica".
create table if not exists pricelabs_mercado_fotos (
  foto_fecha     date not null,
  codigo         text not null references listings(codigo),
  fecha          date not null,                 -- noche futura a la que refieren los precios
  mediana_pagada numeric,                       -- Median Booked Price (vendido de verdad)
  p25            numeric,
  p50            numeric,
  p75            numeric,
  p90            numeric,
  n_reservas     integer,
  primary key (foto_fecha, codigo, fecha)
);
grant select, insert, update, delete on pricelabs_mercado_fotos to service_role;

-- ── 3) f_yoy_mensual: el devengado contra su año previo ────────────────────────
-- ADR/RevPAR sobre ALOJAMIENTO (sin limpieza): comparable con PriceLabs y con el
-- barrio. El ADR del P&L (f_pnl) sigue siendo bruto con limpieza — conviven, cada
-- uno etiquetado en pantalla.
create or replace function f_yoy_mensual(p_desde date, p_hasta date)
returns table(
  codigo text, anio integer, mes integer,
  noches integer, ocupacion numeric, adr numeric, revpar numeric,
  noches_ly integer, ocupacion_ly numeric, adr_ly numeric, revpar_ly numeric,
  comparable boolean, arranque_ly boolean)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with aloj as (
    -- alojamiento sin limpieza por reserva (patrón 032: vive en money_raw)
    select r.id,
           coalesce((r.money_raw::jsonb->>'fareAccommodationAdjusted')::numeric,
                    (r.money_raw::jsonb->>'fareAccommodation')::numeric, 0) as alojamiento,
           (r.checkout_local - r.checkin_local)::numeric                    as noches_res
      from reservations r
     where r.checkout_local > r.checkin_local
  ),
  mensual as (
    -- devengo por noche del motor (mismas exclusiones que el P&L) + el año previo entero
    select n.codigo,
           extract(year  from n.night)::integer as anio,
           extract(month from n.night)::integer as mes,
           count(*)::integer                    as noches,
           sum(a.alojamiento / a.noches_res)    as alojamiento
      from v_reservation_nights n
      join aloj a on a.id = n.id
     where n.night between (date_trunc('month', p_desde::timestamptz) - interval '1 year')::date
                       and (date_trunc('month', p_hasta::timestamptz) + interval '1 mon' - interval '1 day')::date
     group by 1, 2, 3
  )
  select s.codigo, s.anio, s.mes,
         coalesce(m.noches, 0),
         round(coalesce(m.noches, 0)::numeric / days_in_month(s.anio, s.mes), 3),
         case when coalesce(m.noches, 0) > 0 then round(m.alojamiento / m.noches, 2) else 0 end,
         round(coalesce(m.alojamiento, 0) / days_in_month(s.anio, s.mes), 2),
         case when cmp.ok then coalesce(ly.noches, 0) end,
         case when cmp.ok then round(coalesce(ly.noches, 0)::numeric / days_in_month(s.anio - 1, s.mes), 3) end,
         case when cmp.ok then (case when coalesce(ly.noches, 0) > 0 then round(ly.alojamiento / ly.noches, 2) else 0 end) end,
         case when cmp.ok then round(coalesce(ly.alojamiento, 0) / days_in_month(s.anio - 1, s.mes), 2) end,
         cmp.ok,
         (make_date(s.anio - 1, s.mes, 1) = date_trunc('month', l.fecha_inicio)::date)
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join mensual m  on m.codigo = s.codigo and m.anio = s.anio     and m.mes = s.mes
    left join mensual ly on ly.codigo = s.codigo and ly.anio = s.anio - 1 and ly.mes = s.mes
    cross join lateral (
      select make_date(s.anio - 1, s.mes, 1) >= date_trunc('month', l.fecha_inicio)::date as ok) cmp
$$;

revoke execute on function f_yoy_mensual(date, date) from public, anon, authenticated;
grant  execute on function f_yoy_mensual(date, date) to authenticated;

-- ── 4) f_pace_yoy: lo vendido para lo que viene vs cómo cerró el año pasado ────
-- stly_reservado en pricelabs_prices refiere a la misma fecha del año pasado, que a
-- esta altura ya es pasado cerrado → "cómo terminó". Guardas 064: STLY solo cuenta
-- filas no nulas Y posteriores a fecha_inicio; si no queda ninguna, stly_valido=false
-- (el piso no existía — la pantalla dice eso, no "0 %").
create or replace function f_pace_yoy(p_desde date, p_hasta date)
returns table(
  codigo text, anio integer, mes integer, dias integer,
  noches_otb integer, adr_otb numeric,
  noches_ly integer, adr_ly numeric, stly_valido boolean)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select p.codigo,
         extract(year  from p.fecha)::integer,
         extract(month from p.fecha)::integer,
         count(*)::integer,
         (count(*) filter (where p.reservado))::integer,
         round(avg(p.adr) filter (where p.reservado and p.adr is not null), 2),
         (count(*) filter (where p.stly_reservado
                             and (p.fecha - interval '1 year')::date >= l.fecha_inicio))::integer,
         round(avg(p.stly_adr) filter (where p.stly_reservado and p.stly_adr is not null
                             and (p.fecha - interval '1 year')::date >= l.fecha_inicio), 2),
         bool_or(p.stly_reservado is not null
                   and (p.fecha - interval '1 year')::date >= l.fecha_inicio)
    from pricelabs_prices p
    join listings l on l.codigo = p.codigo
   where p.fecha between p_desde and p_hasta
   group by 1, 2, 3
$$;

revoke execute on function f_pace_yoy(date, date) from public, anon, authenticated;
grant  execute on function f_pace_yoy(date, date) to authenticated;

-- ── 5) f_pricelabs_mercado: el barrio, mes a mes, con su año previo al lado ────
-- ADR = revenue / noches vendidas; ocupación = vendidas / disponibles (la API no la
-- trae directa). muestra_chica marca ventanas parciales (p.ej. ago-2024 llega con
-- ~180 días disponibles frente a ~5.500 de un mes normal: ese ADR no es fiable).
create or replace function f_pricelabs_mercado(p_desde date, p_hasta date)
returns table(
  codigo text, mes date,
  adr_mercado numeric, ocupacion_mercado numeric,
  adr_mercado_ly numeric, ocupacion_mercado_ly numeric,
  n_listings integer, categoria text, muestra_chica boolean)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select m.codigo, m.mes,
         round(m.revenue / nullif(m.noches_vendidas, 0), 2),
         round(m.noches_vendidas / nullif(m.noches_disponibles, 0), 3),
         round(ly.revenue / nullif(ly.noches_vendidas, 0), 2),
         round(ly.noches_vendidas / nullif(ly.noches_disponibles, 0), 3),
         m.n_listings, m.categoria,
         coalesce(m.noches_disponibles < coalesce(m.n_listings, 0) * 10, true)
    from pricelabs_mercado m
    left join pricelabs_mercado ly
      on ly.codigo = m.codigo and ly.mes = (m.mes - interval '1 year')::date
   where m.mes between date_trunc('month', p_desde::timestamptz)::date
                   and date_trunc('month', p_hasta::timestamptz)::date
$$;

revoke execute on function f_pricelabs_mercado(date, date) from public, anon, authenticated;
grant  execute on function f_pricelabs_mercado(date, date) to authenticated;

-- ── 6) Vistas wrapper (rango relativo a hoy, Europe/Madrid) ────────────────────
-- v_yoy_mensual: los últimos 24 meses CERRADOS (el mes en curso quedaría a medio
-- vender y su ADR mentiría). Cubre el gráfico "2026 vs 2025" (filas del año con sus
-- _ly) y la línea propia larga para "vos contra el barrio".
create or replace view v_yoy_mensual as
  select * from f_yoy_mensual(
    (date_trunc('month', (now() at time zone 'Europe/Madrid')) - interval '24 mon')::date,
    (date_trunc('month', (now() at time zone 'Europe/Madrid')) - interval '1 day')::date);
grant select on v_yoy_mensual to authenticated;

-- v_pace_yoy: del mes en curso a +9 (10 meses de embudo hacia adelante).
create or replace view v_pace_yoy as
  select * from f_pace_yoy(
    date_trunc('month', (now() at time zone 'Europe/Madrid'))::date,
    (date_trunc('month', (now() at time zone 'Europe/Madrid')) + interval '10 mon' - interval '1 day')::date);
grant select on v_pace_yoy to authenticated;

-- v_pricelabs_mercado: todo lo que el barrio tenga (~25 meses + el mes en curso).
create or replace view v_pricelabs_mercado as
  select * from f_pricelabs_mercado(
    (date_trunc('month', (now() at time zone 'Europe/Madrid')) - interval '26 mon')::date,
    (now() at time zone 'Europe/Madrid')::date);
grant select on v_pricelabs_mercado to authenticated;

-- ── 7) v_freshness: el dato de mercado también se delata si envejece ───────────
-- Columna nueva AL FINAL (064: create or replace solo permite anexar).
create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)                    as last_sync,
  (select max(make_date(anio, mes, 1)) from events)                 as costes_cargados_hasta,
  (select max(date_trunc('month', fecha))::date from bank_deposits) as cierre_hasta,
  (select pricelabs_last_run from sync_state where id = 1)          as pricelabs_last_run,
  (select pricelabs_last_error from sync_state where id = 1)        as pricelabs_last_error,
  (select max(refreshed_at) from pricelabs_prices)                  as pricelabs_refreshed,
  (select max(synced_at) from pricelabs_mercado)                    as mercado_synced;
grant select on v_freshness to authenticated;
