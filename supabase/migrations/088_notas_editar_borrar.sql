-- 088_notas_editar_borrar.sql — corregir y borrar una nota recién dictada (19/08/2026).
--
-- La 087 dejó la bandeja append-only "para tener rastro". A las dos horas de estrenarla Stag
-- dictó una nota mal y se quedó sin salida: el rastro de un borrador no vale nada frente a no
-- poder arreglar lo que uno acaba de decir. La nota NO es el registro contable — el registro
-- es el `recobro`/`event` que sale de ella, más el cargo en el banco. Así que se abre, pero
-- con tres candados que mantienen el rastro donde sí importa:
--
--   1. Solo mientras esté SIN_PROCESAR. Una vez convertida en recobro o event, se congela:
--      ahí sí hay algo que depende de ella y cambiarla en silencio sería falsear el origen.
--   2. Solo notas PROPIAS. El autor se compara contra el email del JWT, no contra lo que
--      mande el cliente: nadie edita ni borra la nota de otro.
--   3. La versión anterior se guarda en `texto_previo`. Corregir no borra lo que se dijo
--      antes, que es exactamente el rastro que se quería conservar.

alter table notas_inbox
  add column if not exists editada_en   timestamptz,
  add column if not exists texto_previo text;

comment on column notas_inbox.texto_previo is
  'Versión inmediatamente anterior del texto (última corrección). El rastro que justifica abrir la edición.';

-- ── Editar ────────────────────────────────────────────────────────────────────────
create or replace function f_nota_editar(p_id bigint, p_texto text)
returns bigint
language plpgsql volatile
security definer set search_path = public, pg_temp
as $$
declare
  v_texto text := left(btrim(coalesce(p_texto, '')), 2000);
  v_autor text;
  v_filas int;
begin
  if v_texto = '' then
    raise exception 'La nota está vacía' using errcode = '22023';
  end if;

  v_autor := coalesce(
    nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', ''),
    'desconocido');

  update notas_inbox
     set texto_previo = texto,
         texto        = v_texto,
         editada_en   = now()
   where id = p_id
     and autor = v_autor            -- solo las propias
     and estado = 'SIN_PROCESAR';   -- una vez registrada, se congela
  get diagnostics v_filas = row_count;

  if v_filas = 0 then
    raise exception 'Esa nota ya no se puede corregir' using errcode = '42501';
  end if;
  return p_id;
end;
$$;

-- ── Borrar ────────────────────────────────────────────────────────────────────────
-- Borrado real, no marca de "descartada": una nota dictada por error no tiene que
-- ensuciar la bandeja: DESCARTADA es para lo que se revisó y se decidió no cargar.
create or replace function f_nota_borrar(p_id bigint)
returns bigint
language plpgsql volatile
security definer set search_path = public, pg_temp
as $$
declare
  v_autor text;
  v_filas int;
begin
  v_autor := coalesce(
    nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', ''),
    'desconocido');

  delete from notas_inbox
   where id = p_id and autor = v_autor and estado = 'SIN_PROCESAR';
  get diagnostics v_filas = row_count;

  if v_filas = 0 then
    raise exception 'Esa nota ya no se puede borrar' using errcode = '42501';
  end if;
  return p_id;
end;
$$;

-- ── La vista suma las columnas nuevas ─────────────────────────────────────────────
-- Ni `create or replace view` ni `create or replace function` admiten cambiar la firma:
-- hay que tirar la vista, después la función (en ese orden: la vista depende de ella) y
-- recrear las dos. Y volver a GRANTear — con el candado de la 056/061 nacen sin permisos,
-- y sin el grant la pantalla deja de leer.
drop view     if exists v_notas_inbox;
drop function if exists f_notas_inbox();

create function f_notas_inbox()
returns table (
  id           bigint,
  texto        text,
  autor        text,
  creado_en    timestamptz,
  estado       text,
  resultado    text,
  procesado_en timestamptz,
  editada_en   timestamptz,
  texto_previo text
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select n.id, n.texto, n.autor, n.creado_en, n.estado, n.resultado, n.procesado_en,
         n.editada_en, n.texto_previo
    from notas_inbox n
   order by n.creado_en desc, n.id desc
   limit 100;
$$;

create view v_notas_inbox as select * from f_notas_inbox();

-- ── Candado (068: el revoke va ANTES del grant, y anon nunca entra) ───────────────
revoke execute on function f_nota_editar(bigint, text) from public, anon, authenticated;
grant  execute on function f_nota_editar(bigint, text) to authenticated;
revoke execute on function f_nota_borrar(bigint)       from public, anon, authenticated;
grant  execute on function f_nota_borrar(bigint)       to authenticated;
revoke execute on function f_notas_inbox()             from public, anon, authenticated;
grant  execute on function f_notas_inbox()             to authenticated;
grant  select  on v_notas_inbox                        to authenticated;
