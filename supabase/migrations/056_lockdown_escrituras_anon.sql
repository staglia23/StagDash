-- 056 — cierre de escrituras con la anon key (auditoría 27/07/2026). Idempotente.
--
-- Hallazgo: v_propiedades era la única vista auto-actualizable del esquema (select simple
-- sobre listings, owner postgres, sin security_invoker) y anon/authenticated tenían
-- INSERT/UPDATE/DELETE por los default privileges de Supabase. Con la anon key (pública,
-- horneada en el bundle) se podía cambiar renta_base/modelo/fecha_inicio o insertar pisos
-- fantasma que diluyen el prorrateo del overhead — el RLS de listings no aplica porque la
-- vista ejecuta como su owner. La 008 cerró lecturas; esto cierra escrituras.

-- 1) Revocar escrituras sobre todo lo existente (tablas Y vistas; los GRANT SELECT quedan).
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from anon, authenticated;

-- 2) Que ningún objeto futuro nazca con privilegios para anon/authenticated:
--    el GRANT SELECT pasa a ser SIEMPRE explícito por migración (política de CLAUDE.md).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
do $$ begin
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on tables from anon, authenticated';
exception when insufficient_privilege or undefined_object then
  raise notice 'default ACL de supabase_admin no ajustado (sin permisos); revisar a mano';
end $$;

-- 3) RLS como segunda capa en las tablas que solo estaban protegidas por el revoke
--    (sin policies = deny-all para roles no-owner; service_role no se ve afectado).
alter table airbnb_tx enable row level security;
alter table avisos enable row level security;
alter table bank_deposits enable row level security;
alter table limpieza_mensual enable row level security;
alter table suministros_mensual enable row level security;

-- 4) PII fuera de textos: el nombre del dueño de MARE estaba en la nota de un event.
update events set notas = replace(notas, 'a J.L. De La Torre 19/06', 'al dueño de MARE 19/06')
 where notas like '%J.L. De La Torre%';
