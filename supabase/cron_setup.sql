-- cron_setup.sql — agenda la ingesta guesty-sync cada 3 horas (pg_cron + pg_net)
--
-- ⚠️ NO está en migrations/ a propósito: tiene placeholders. Ejecutalo A MANO en el
--    SQL Editor de Supabase UNA VEZ, después de desplegar la función guesty-sync,
--    reemplazando <PROJECT_REF> y <SERVICE_ROLE_KEY>.
--
-- Alternativa sin SQL: Dashboard → Integrations → Cron → "Create job" apuntando a la
-- Edge Function guesty-sync con schedule "0 */3 * * *".

-- 1) Extensiones (idempotente)
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 2) Guardar la service_role key en Vault (no dejarla en texto plano en el job)
--    Reemplazá <SERVICE_ROLE_KEY> por la key de Settings → API. Ejecutar una sola vez.
select vault.create_secret('<SERVICE_ROLE_KEY>', 'guesty_sync_service_key', 'service_role para invocar guesty-sync');

-- 3) Agendar cada 3 horas (UTC). Reemplazá <PROJECT_REF> (está en la URL del proyecto).
select cron.schedule(
  'guesty-sync-3h',
  '0 */3 * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.functions.supabase.co/guesty-sync',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
                                       where name = 'guesty_sync_service_key')
    ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 150000
  );
  $$
);

-- ── Utilidades ──────────────────────────────────────────────────────────────
-- Ver jobs agendados:          select jobid, schedule, jobname from cron.job;
-- Ver últimas ejecuciones:     select * from cron.job_run_details order by start_time desc limit 10;
-- Cambiar frecuencia:          select cron.alter_job((select jobid from cron.job where jobname='guesty-sync-3h'), schedule := '0 */6 * * *');
-- Borrar el job:               select cron.unschedule('guesty-sync-3h');
