-- 069_secreto_compartido_edge_functions.sql — cierra las Edge Functions (04/08/2026).
--
-- LA AUDITORÍA LO REPRODUJO DESDE INTERNET, SIN NINGUNA CREDENCIAL:
--   curl -X POST https://<ref>.supabase.co/functions/v1/guesty-sync
--   → HTTP 200 {"ok":true,...} y sync_state quedó escrito por esa request anónima.
-- Un GET pelado (pegar la URL en el navegador) hacía lo mismo.
--
-- DOS TRAMPAS QUE HAY QUE ENTENDER PARA NO REPETIRLO:
--
-- 1) guesty-sync tenía verify_jwt=false y el handler era `Deno.serve(async () => {…})`:
--    descartaba la request entera, así que no había ni cabecera que comprobar. El
--    comentario de config.toml decía "se protege con el secret de service_role" — era
--    FALSO, no existía tal comprobación.
--
-- 2) verify_jwt=true NO significa "solo usuarios logueados". El gateway solo valida que
--    el JWT esté bien FIRMADO, y la anon key es exactamente eso: un JWT válido del
--    proyecto, horneado en el bundle público del dashboard. Por eso pricelabs-sync, que
--    sí tenía verify_jwt=true, también se disparaba desde fuera: el auditor lo hizo con la
--    key que descargó del propio sitio. verify_jwt sube el listón de "cualquiera del
--    planeta" a "cualquiera que abrió el dashboard una vez". No es una puerta.
--
-- POR QUÉ IMPORTA: las dos funciones corren con SUPABASE_SERVICE_ROLE_KEY (bypassa RLS) y
-- escriben en reservations, listings, sync_state, pricelabs_prices y pricelabs_fotos.
-- Además, martillar el endpoint quema la cuota de la API de Guesty/PriceLabs y deja el
-- dashboard con datos viejos.
--
-- EL ARREGLO: un secreto propio que no es ninguna de las keys públicas. El cron lo manda
-- en la cabecera x-sync-secret; el handler pregunta a la base si es correcto ANTES de
-- hacer nada. El secreto vive cifrado en Vault y nunca sale: f_sync_secret_ok solo
-- responde sí/no y solo service_role puede ejecutarla (ni anon ni el dashboard pueden
-- siquiera probar a ciegas).
--
-- OJO AL ORDEN AL APLICARLO (si hay que rehacerlo): primero esta migración y la
-- reprogramación del cron (paso 4), DESPUÉS el deploy de las funciones. Al revés, el
-- sync queda rechazándose a sí mismo hasta que el cron se actualice, y en silencio.

-- 1) Secreto aleatorio de 32 bytes, vía la API oficial de Vault (el insert directo en
--    vault.secrets choca con los permisos de _crypto_aead_det_noncegen).
--    Idempotente: si ya existe, NO lo rota (rotarlo sin redesplegar rompería el cron).
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'sync_shared_secret') then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'sync_shared_secret',
      'Secreto compartido cron -> Edge Functions (guesty-sync, pricelabs-sync). Migracion 069.'
    );
  end if;
end $$;

-- 2) El verificador. security definer porque vault no es legible por el llamador.
--    Devuelve solo un booleano: el secreto no se puede extraer preguntando.
create or replace function f_sync_secret_ok(p_secreto text)
returns boolean
language sql stable
security definer set search_path = public, vault, pg_temp
as $$
  select coalesce(length(p_secreto), 0) >= 32
     and exists (
       select 1 from vault.decrypted_secrets
        where name = 'sync_shared_secret'
          and decrypted_secret = p_secreto
     );
$$;

-- 3) Candado (lección 068: el default cableado de Postgres da EXECUTE a PUBLIC).
--    Solo service_role — o sea, solo las Edge Functions.
revoke execute on function f_sync_secret_ok(text) from public, anon, authenticated;
grant  execute on function f_sync_secret_ok(text) to service_role;

-- 4) Reprogramación de los dos cron jobs — ver supabase/cron_setup.sql, que quedó
--    actualizado con el esquema definitivo (cabeceras desde Vault, sin keys inline).
--    No va acá porque cron.schedule no es idempotente y la URL lleva el project ref.

-- ── VERIFICACIÓN (hecha el 04/08/2026, tras desplegar las funciones) ────────────────
--   curl -X POST .../guesty-sync                                   → 401  (era 200)
--   curl .../guesty-sync                                           → 401  (era 200)
--   curl -X POST .../guesty-sync -H "Authorization: Bearer <anon>"  → 401
--   curl -X POST .../pricelabs-sync -H "Authorization: Bearer <anon>" → 401  (era 500, o sea entraba)
--   net.http_post con las cabeceras del cron (incluido x-sync-secret) → 200 {"ok":true}
