-- 020_freshness_cierre.sql — el sello de la portada decía "costes cargados hasta diciembre 2026".
--
-- Por qué mentía: costes_cargados_hasta = max(mes) de events, y los events están precargados
-- hacia adelante (la renta de ALEX de nov–dic, por ejemplo). Ese campo mide hasta dónde llega
-- la PROYECCIÓN, no hasta dónde está cerrado el mes. Leído en la portada daba a entender que
-- el año ya estaba conciliado.
--
-- El marcador honesto del cierre mensual es hasta dónde llega la conciliación bancaria: los
-- extractos que Stag sube cada mes (bank_deposits). Hoy: junio 2026.
--
-- Se AÑADE cierre_hasta en vez de redefinir costes_cargados_hasta, para no cambiar en silencio
-- el significado de un campo que ya leen otras páginas. La portada pasa a usar el nuevo.
-- v_freshness ya es pública (007) y bank_deposits sigue siendo interna: acá solo sale un mes
-- agregado, sin importes ni IBAN.

create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)            as last_sync,
  (select max(make_date(anio, mes, 1)) from events)         as costes_cargados_hasta,
  (select max(date_trunc('month', fecha))::date
     from bank_deposits)                                    as cierre_hasta;

grant select on v_freshness to anon, authenticated;
