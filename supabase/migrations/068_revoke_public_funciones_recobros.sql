-- 068_revoke_public_funciones_recobros.sql — cierra la fuga /rpc/ de las f_ de la 065/066 (04/08/2026).
--
-- La revisión adversarial lo explotó en producción con la anon key (POST /rest/v1/rpc/
-- f_recobros → HTTP 200 con los recobros completos, sin login): f_recobros y
-- f_cuenta_duena nacieron ejecutables por PUBLIC (y anon lo hereda), y como son SECURITY
-- DEFINER saltan el RLS de recobros.
--
-- LECCIÓN (asentada en CLAUDE.md): el candado 061 NO alcanza para funciones. El default
-- CABLEADO de Postgres da EXECUTE a PUBLIC en cada función nueva y el pg_default_acl de
-- la 061 se SUMA a ese default en vez de anularlo. Por eso las 063/064 llevan un
-- `revoke execute … from public, anon, authenticated` explícito antes del grant; las
-- 065/066/067 lo omitieron. El smoke test "anon da 42501" solo probó las VISTAS, nunca
-- el camino /rpc/ — el punto ciego que la propia 061 documenta.
--
-- Se mantiene el grant a authenticated: las vistas wrapper (v_recobros, v_cuenta_duena)
-- comprueban ese EXECUTE contra el usuario que las consulta.
revoke execute on function f_recobros(date, date)     from public, anon;
revoke execute on function f_cuenta_duena(date, date) from public, anon;
