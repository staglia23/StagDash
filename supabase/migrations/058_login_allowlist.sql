-- 058 — login, parte 1 de 2: allowlist de emails para Supabase Auth. Idempotente.
--
-- El dashboard pasa de "URL pública que lee con la anon key" a login con Supabase Auth.
-- Problema a cerrar ANTES de habilitar nada: la anon key es pública por diseño y GoTrue
-- expone /auth/v1/signup — cualquiera podría registrarse, obtener un JWT de rol
-- authenticated y leer las 24 vistas (que desde siempre tienen GRANT a ese rol).
-- Este trigger rechaza en la base cualquier alta (o cambio de email) que no esté en la
-- allowlist, sin depender de la configuración del panel de Supabase.
--
-- La parte 2 (059) revoca el SELECT de anon sobre las vistas y se aplica SOLO cuando el
-- frontend con login ya esté desplegado — si no, el dashboard vivo se queda sin datos.

create table if not exists public.auth_email_allowlist (
  email text primary key check (email = lower(email)),
  nota  text
);
-- Sin GRANTs: tabla interna, solo la lee el trigger (security definer).
-- Post-056 nace sin permisos para anon/authenticated, que es exactamente lo que se quiere.

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

-- El trigger corre como owner (postgres); nadie más necesita ejecutar la función.
revoke execute on function public.f_auth_bloquear_no_invitados() from public, anon, authenticated;

drop trigger if exists trg_auth_allowlist_ins on auth.users;
create trigger trg_auth_allowlist_ins
  before insert on auth.users
  for each row execute function public.f_auth_bloquear_no_invitados();

-- El flujo de cambio de email de GoTrue también pasa por acá: sin esto, un usuario válido
-- podría migrar su cuenta a un email fuera de la allowlist y la lista dejaría de gobernar.
drop trigger if exists trg_auth_allowlist_upd on auth.users;
create trigger trg_auth_allowlist_upd
  before update of email on auth.users
  for each row execute function public.f_auth_bloquear_no_invitados();
