-- 087_notas_inbox.sql — la bandeja de entrada: dictar un gasto desde el móvil (19/08/2026).
--
-- El problema que resuelve: la hoja `2026_JACOBINE_MADRE_INGRESOS` está muerta (Stag dejó
-- de actualizarla) y lo que se paga por fuera solo llega al motor si alguien lo escribe.
-- Hasta hoy, "escribirlo" significaba escribirle a Claude en una sesión: si no hay sesión,
-- el gasto no existe en ningún lado. Esta tabla es el sitio donde dejarlo en el momento,
-- desde el iPhone, con el micrófono del teclado.
--
-- ⚠ ES LA PRIMERA ESCRITURA QUE EL DASHBOARD EXPONE AL CLIENTE. Toda la doctrina del repo
-- (056, 059, 061, 068) dice "el cliente solo lee vistas", así que el radio de daño se acota
-- a propósito:
--   · `f_nota_add` SOLO puede insertar texto en esta tabla. No toca events, ni recobros, ni
--     nada de lo que sale un número. Una nota mal dictada no puede mover el P&L.
--   · Nada del motor lee `notas_inbox`: no hay vista de negocio que dependa de ella.
--   · No hay UPDATE ni DELETE expuestos: la bandeja es append-only. Corregir = dictar otra
--     nota. El paso de SIN_PROCESAR a REGISTRADA lo hace una migración, con revisión humana.
-- Si algún día se quiere que el cliente escriba en `events` o `recobros`, NO se hace
-- extendiendo esta función: eso es otra decisión y necesita su propia revisión.
--
-- Ciclo de vida: SIN_PROCESAR → REGISTRADA (se convirtió en recobro/event; `resultado` dice
-- en cuál) o DESCARTADA (no era un gasto; `resultado` dice por qué). Igual que en `recobros`,
-- el estado resuelto EXIGE explicación: una nota que desaparece sin rastro es una nota que
-- se perdió.

-- ── 1) Tabla (cruda: RLS sin policies, el cliente solo entra por función) ──────────
create table if not exists notas_inbox (
  id           bigint generated always as identity primary key,
  texto        text not null,                        -- lo dictado, tal cual
  autor        text not null,                        -- email de la sesión que la dejó
  creado_en    timestamptz not null default now(),
  estado       text not null default 'SIN_PROCESAR'
               check (estado in ('SIN_PROCESAR', 'REGISTRADA', 'DESCARTADA')),
  resultado    text,                                 -- "recobro #12" / "event ago-2026" / motivo
  procesado_en timestamptz,
  constraint notas_inbox_texto_util
    check (length(btrim(texto)) between 1 and 2000),
  -- SIN_PROCESAR ⇔ sin fecha de proceso; los otros dos estados la exigen.
  constraint notas_inbox_estado_fecha
    check ((estado = 'SIN_PROCESAR') = (procesado_en is null)),
  -- Y exigen decir en qué terminó: sin esto, una nota puede evaporarse sin dejar rastro.
  constraint notas_inbox_resultado
    check (estado = 'SIN_PROCESAR' or resultado is not null)
);

create index if not exists idx_notas_inbox_estado
  on notas_inbox (estado, creado_en desc);

alter table notas_inbox enable row level security;  -- sin policies: inaccesible directo

-- ── 2) Escritura: la única función de escritura del dashboard ──────────────────────
-- security definer porque `authenticated` no tiene INSERT sobre la tabla (ni debe tenerlo:
-- con un grant directo, la anon key de mañana podría heredarlo por un default privilege
-- olvidado — la cicatriz de la 056). El autor sale del JWT, no del cliente: el navegador no
-- puede decir "esto lo escribió otro".
create or replace function f_nota_add(p_texto text)
returns bigint
language plpgsql volatile
security definer set search_path = public, pg_temp
as $$
declare
  v_texto text := left(btrim(coalesce(p_texto, '')), 2000);
  v_autor text;
  v_hoy   int;
  v_id    bigint;
begin
  if v_texto = '' then
    raise exception 'La nota está vacía' using errcode = '22023';
  end if;

  -- Claims del JWT de la request. nullif antes del cast: sin sesión el setting es '' y
  -- ''::jsonb revienta con 22P02 en vez de dar null.
  v_autor := coalesce(
    nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', ''),
    'desconocido');

  -- Freno de mano: una sesión secuestrada no puede llenar la tabla de basura mientras
  -- nadie mira. 100 notas/día es ~20× lo que un cierre mensual movido necesita.
  select count(*) into v_hoy
    from notas_inbox
   where autor = v_autor and creado_en > now() - interval '1 day';
  if v_hoy >= 100 then
    raise exception 'Demasiadas notas en 24 h' using errcode = '54000';
  end if;

  insert into notas_inbox (texto, autor) values (v_texto, v_autor) returning id into v_id;
  return v_id;
end;
$$;

-- ── 3) Lectura (patrón 060/065: f_* security definer + vista wrapper) ──────────────
-- Sin parámetros de período a propósito: esto no es motor de negocio, es un cuaderno.
-- Tope de 100: la bandeja se vacía procesándola, no scrolleándola.
create or replace function f_notas_inbox()
returns table (
  id           bigint,
  texto        text,
  autor        text,
  creado_en    timestamptz,
  estado       text,
  resultado    text,
  procesado_en timestamptz
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select n.id, n.texto, n.autor, n.creado_en, n.estado, n.resultado, n.procesado_en
    from notas_inbox n
   order by n.creado_en desc, n.id desc
   limit 100;
$$;

create or replace view v_notas_inbox as
  select * from f_notas_inbox();

-- ── 4) Candado (lecciones 056/059/061/068: nada nace con permisos) ─────────────────
-- El revoke de public/anon es OBLIGATORIO y va ANTES del grant: el default cableado de
-- Postgres da EXECUTE a PUBLIC en cada función nueva y el pg_default_acl de la 061 se SUMA
-- a ese default en vez de anularlo. Sin esto, `anon` podría escribir notas vía /rpc/ sin
-- login (que es exactamente la fuga que la 068 tuvo que cerrar).
revoke execute on function f_nota_add(text)  from public, anon, authenticated;
grant  execute on function f_nota_add(text)  to authenticated;
revoke execute on function f_notas_inbox()   from public, anon, authenticated;
grant  execute on function f_notas_inbox()   to authenticated;
grant  select  on v_notas_inbox              to authenticated;
