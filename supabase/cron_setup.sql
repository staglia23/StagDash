-- cron_setup.sql — agenda los dos syncs (pg_cron + pg_net). Estado real desde el 04/08/2026.
--
-- ⚠️ NO está en migrations/ a propósito: `cron.schedule` no es idempotente y la URL lleva
--    el project ref. Se ejecuta A MANO en el SQL Editor cuando hay que (re)crear los jobs.
--    Este archivo YA refleja lo aplicado en producción: no hay placeholders que rellenar,
--    salvo el bootstrap de la anon key (paso 2) si el proyecto fuera otro.
--
-- ── LA PUERTA (migración 069) ───────────────────────────────────────────────────────
-- Las dos Edge Functions exigen la cabecera `x-sync-secret`. Antes de la 069 cualquiera
-- en internet las disparaba: guesty-sync no miraba la request, y en pricelabs-sync el
-- verify_jwt=true se satisfacía con la anon key, que es pública (va en el bundle del
-- dashboard). Las funciones corren con service_role, así que un anónimo podía hacerlas
-- escribir en la base y quemar la cuota de Guesty/PriceLabs.
--
-- Ningún token va inline en cron.job: todos salen de Vault. Si se recrean estos jobs,
-- mantener SIEMPRE la cabecera x-sync-secret o el sync empezará a dar 401 en silencio
-- (el síntoma sería v_freshness envejeciendo sin error visible en el dashboard).

-- 1) Extensiones (idempotente)
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 2) Bootstrap de secretos en Vault. `sync_shared_secret` lo crea la migración 069.
--    `anon_key_publica` NO es un secreto real (es pública por diseño); vive en Vault solo
--    para no dejar el token en texto plano dentro de cron.job. Descomentar y rellenar
--    únicamente si se está montando el proyecto de cero:
-- select vault.create_secret('<ANON_KEY>', 'anon_key_publica',
--   'Anon key publica: la exige el gateway (verify_jwt=true). NO es un secreto real.');

-- 3) guesty-sync — cada 3 horas (UTC)
select cron.unschedule('guesty-sync-3h');
select cron.schedule('guesty-sync-3h', '0 */3 * * *', $job$
  select net.http_post(
    url     := 'https://enlslwuokresrwbqpyeo.supabase.co/functions/v1/guesty-sync',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'apikey',        (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key_publica'),
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key_publica'),
      'x-sync-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'sync_shared_secret')
    ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 150000
  );
$job$);

-- 4) pricelabs-sync — 1×/día a las 07:10 UTC (PriceLabs refresca ~06:00 UTC).
--    Requiere además el secret PRICELABS_API_KEY en la función (pendiente de Stag: sin él
--    la corrida falla y queda anotada en sync_state.pricelabs_last_error).
select cron.unschedule('pricelabs-sync-daily');
select cron.schedule('pricelabs-sync-daily', '10 7 * * *', $job$
  select net.http_post(
    url     := 'https://enlslwuokresrwbqpyeo.supabase.co/functions/v1/pricelabs-sync',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'apikey',        (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key_publica'),
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key_publica'),
      'x-sync-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'sync_shared_secret')
    ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 150000
  );
$job$);

-- ── COMPROBACIONES ──────────────────────────────────────────────────────────────────
-- Los dos jobs mandan el secreto y ninguno lleva tokens inline:
--   select jobname, command like '%x-sync-secret%' as manda_secreto,
--          command !~ 'Bearer [A-Za-z0-9._-]{20}'  as sin_token_inline
--     from cron.job;
--
-- La puerta rechaza a un anónimo (debe dar 401 en las dos):
--   curl -s -o /dev/null -w '%{http_code}\n' -X POST https://enlslwuokresrwbqpyeo.supabase.co/functions/v1/guesty-sync
--
-- Y deja pasar al cron (debe dar 200 con ok:true): copiar el net.http_post del paso 3 y
--   select status_code, content from net._http_response order by id desc limit 1;
