-- 061 — candado de default privileges para FUNCIONES y SECUENCIAS + residuos de ACL.
-- Hallazgos de la revisión adversarial de la 060 (30/07/2026). Idempotente.
--
-- La 056 cerró los defaults de TABLAS, pero cada función nueva seguía naciendo con
-- EXECUTE para anon/authenticated (pg_default_acl objtype 'f') y cada secuencia con
-- USAGE+UPDATE. Con el motor ahora en funciones SECURITY DEFINER que leen tablas crudas
-- (060), una f_ futura sin su bloque de revoke quedaría legible con la anon key (pública)
-- vía /rest/v1/rpc/ — la misma fuga silenciosa que 008/056/059 cerraron para vistas, y
-- el dashboard no la delataría porque él lee como authenticated. Tras esto, la doctrina
-- queda completa: toda vista, FUNCIÓN o secuencia nueva nace SIN permisos; los GRANTs
-- son siempre explícitos, a authenticated, nunca a anon.

-- 1) Defaults de postgres (el rol con el que corren las migraciones): a cero.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated;

-- 2) supabase_admin: el do-block de la 056 falló EN SILENCIO (su default de tablas
--    seguía dando arwdDxtm a anon al auditar hoy). Se reintenta; verificar
--    pg_default_acl tras aplicar — no fiarse del notice.
--    RESULTADO (30/07/2026): volvió a fallar (insufficient_privilege). Queda como
--    limitación documentada: solo afecta a objetos creados por la PLATAFORMA; nuestras
--    migraciones corren como postgres, cuyos defaults SÍ quedaron a cero (verificado).
do $$ begin
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on tables from anon, authenticated';
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke execute on functions from public, anon, authenticated';
  execute 'alter default privileges for role supabase_admin in schema public '
       || 'revoke all on sequences from public, anon, authenticated';
exception when insufficient_privilege or undefined_object then
  raise notice 'default ACL de supabase_admin no ajustado (sin permisos); consta como limitación';
end $$;

-- 3) Residuos vivos sobre objetos EXISTENTES:
--    - UPDATE de anon en las 5 secuencias: la 059 revocó usage/select, pero UPDATE es
--      otro bit y permite nextval/setval (sin canal HTTP hoy; fuera de la regla igual).
--    - MAINTAIN (bit 'm', nuevo de PG17) en las vistas pre-056: la 056 revocó por lista
--      nominal y este bit no existía en ella.
revoke all on all sequences in schema public from anon, authenticated;
revoke maintain on all tables in schema public from anon, authenticated;

-- 4) Las dos helpers puras dejan de ser RPC anónima (nacieron con el default abierto).
--    authenticated CONSERVA el EXECUTE: hay vistas que las llaman en su cuerpo y ese
--    EXECUTE se comprueba contra el usuario que consulta (la lección de la 060).
revoke execute on function days_in_month(integer, integer), dias_gestion(date, integer, integer)
  from public, anon;
grant execute on function days_in_month(integer, integer), dias_gestion(date, integer, integer)
  to authenticated, service_role;

-- 5) Hardening gratis: pg_temp al final del search_path de las SECURITY DEFINER (forma
--    canónica; hoy inexplotable — los roles de API no crean objetos ni tablas temp).
alter function f_spine(date, date)                 set search_path = public, pg_temp;
alter function f_dias_gestion(date, date)          set search_path = public, pg_temp;
alter function f_samavi_gen_mensual(date, date)    set search_path = public, pg_temp;
alter function f_limpieza_mensual(date, date)      set search_path = public, pg_temp;
alter function f_suministros_mensual(date, date)   set search_path = public, pg_temp;
alter function f_pnl_mensual_propiedad(date, date) set search_path = public, pg_temp;
alter function f_ranking(date, date)               set search_path = public, pg_temp;
alter function f_costes(date, date)                set search_path = public, pg_temp;
alter function f_breakeven(date, date)             set search_path = public, pg_temp;
alter function f_canal(date, date)                 set search_path = public, pg_temp;
alter function f_auth_bloquear_no_invitados()      set search_path = public, pg_temp;
