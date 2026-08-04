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
