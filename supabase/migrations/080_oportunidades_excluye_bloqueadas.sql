-- 080 · La pantalla de precios no puede ofrecer palanca sobre una noche BLOQUEADA
--
-- Hallazgo del 14/08/2026. f_pricelabs_oportunidades (migración 072) filtraba por
-- `not p.no_vendible` con el comentario "las bloqueadas no tienen palanca de precio", pero
-- una noche bloqueada en el calendario llega desde PriceLabs con:
--        reservado = false   ·   no_vendible = false   ·   booking_status = 'Blocked'
-- o sea que pasaba el filtro. Hoy no se cuela ninguna fila de puro azar (esas noches vienen
-- con precio_usuario null y el filtro exige que no lo sea), pero es una coincidencia, no una
-- defensa: en cuanto una noche bloqueada tenga un override de precio, aparece en /precios como
-- euros sobre la mesa que NO existen, y lleva a bajar precio sobre inventario cerrado.
--
-- Deja de ser hipotético justo ahora: Jacobine tiene 190 noches en 'Blocked' (una ventana de
-- reserva cerrada más allá de ~6 meses, que alcanza a Semana Santa y Feria de 2027) y Marechal
-- tiene 4 (los viajes de control de Stag). Son exactamente las fechas donde más tentador es
-- poner un precio a mano.
--
-- El criterio correcto ya lo usa f_pricelabs_forward desde la 064: se alinea con él.
-- OJO al artefacto de borde de la 064: la última fecha del horizonte de cada piso también llega
-- como bloqueada sin serlo — queda excluida igual, que es lo que corresponde.

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
     and not p.no_vendible
     and coalesce(p.booking_status, '') <> 'Blocked'   -- ← 080: bloqueada = sin palanca de precio
     and p.precio_usuario is not null
     and p.precio_base   is not null
     and p.precio_base > p.precio_usuario        -- solo lo que deja plata sobre la mesa
   order by p.fecha, p.codigo;
$$;

-- Los privilegios no se heredan al reemplazar: se rehacen con el patrón de la 061/068.
revoke execute on function f_pricelabs_oportunidades(int) from public, anon, authenticated;
grant  execute on function f_pricelabs_oportunidades(int) to authenticated;
