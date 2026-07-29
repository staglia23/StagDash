-- 059 — login, parte 2 de 2: el candado. Idempotente. APLICADA el 30/07/2026, con el
-- deploy con login ya vivo y verificado (secuencia obligada: en cuanto esto corre, la
-- anon key deja de leer las vistas, y un frontend sin login se quedaría sin datos —
-- readView devolvería el fallback [] y el dashboard pintaría ceros, peor que un error).
-- Verificado tras aplicar: anon → "permission denied" en las 24 vistas; el dashboard
-- con sesión sigue rindiendo datos completos.
--
-- Cierra el último tramo del modelo de seguridad: la 008 tapó la fuga de lectura por
-- reserva, la 056 las escrituras y los default privileges, y esta quita la lectura
-- anónima de los agregados. Desde aquí, leer el dashboard exige un usuario de la
-- allowlist (058) con sesión iniciada. La anon key queda solo como "api key" de
-- GoTrue/PostgREST, sin ningún DATO de negocio legible. (Literalmente le queda EXECUTE
-- sobre days_in_month/dias_gestion vía el grant implícito a PUBLIC — aritmética de fechas
-- pura, sin acceso a tablas; revocarlo exigiría tocar PUBLIC y arriesgar las vistas que
-- las usan para authenticated. Se acepta.)
--
-- Blanket a propósito (como la 056): hoy anon solo tiene SELECT sobre las 24 vistas del
-- dashboard, pero enumerarlas dejaría pasar cualquier vista futura que un GRANT copiado
-- de una migración vieja vuelva a abrir "to anon, authenticated" por inercia.
-- Regla desde ahora (también en CLAUDE.md): vistas nuevas se GRANTean a authenticated
-- SOLO — un "to anon" copiado por inercia reabre la lectura sin login.

revoke select on all tables in schema public from anon;
revoke usage, select on all sequences in schema public from anon;

-- Verificación tras aplicar: un GET anónimo debe quedar fuera —
--   curl -s "https://enlslwuokresrwbqpyeo.supabase.co/rest/v1/v_kpis?select=*" \
--     -H "apikey: <anon>" → debe devolver "permission denied", no datos.
