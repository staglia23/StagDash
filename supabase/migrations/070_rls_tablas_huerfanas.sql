-- 070_rls_tablas_huerfanas.sql — segunda capa en las tres tablas sin RLS (04/08/2026).
--
-- La auditoría las encontró y sus verificadores las descartaron como "no es agujero", con
-- razón: no tienen ningún GRANT para anon (candado 056/059), así que hoy nadie las lee.
-- Se activa igual porque este repo tiene un historial de permisos que se regalan solos
-- (008, 056, 061 y 068, todas fugas reales): el RLS es lo que convierte un GRANT puesto
-- por descuido en un no-evento en vez de en una fuga. Es el patrón de todas las demás
-- tablas crudas desde la 002.
--
-- No rompe nada — verificado antes de aplicar:
--   · pricelabs_prices / pricelabs_fotos: las escribe la Edge Function con service_role
--     (bypassa RLS) y las lee f_pricelabs_forward, security definer con owner postgres.
--   · auth_email_allowlist: la consulta el trigger f_auth_bloquear_no_invitados, que es
--     security definer y cuyo owner (postgres) tiene BYPASSRLS = true. Si no lo fuera,
--     activar RLS acá habría roto el alta de usuarios en silencio.
-- Sin policies: nadie que no bypasee RLS ve una sola fila.
alter table pricelabs_prices     enable row level security;
alter table pricelabs_fotos      enable row level security;
alter table auth_email_allowlist enable row level security;

-- Comprobado después, como authenticated: v_pricelabs_forward, v_freshness, v_kpis,
-- v_cuenta_duena, v_recobros, v_forward y v_alertas siguen devolviendo sus filas.
