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
