-- 095_jacobine_dos_dormitorios.sql — Jacobine tiene 2 dormitorios, no 3 (corrección de
-- Stag, 01/09/2026).
--
-- La 094 fijó dormitorios=3 tomándolo del registro del listing en PriceLabs
-- (no_of_bedrooms=3, heredado del PMS). Stag lo corrige: son 2. El compset del barrio se
-- elige por este número, así que el dato de mercado de JACO cargado ayer comparaba contra
-- pisos de 3 dormitorios (153 listings) en vez de los de 2 (185).
--
-- OJO fuera de este repo: si Guesty también dice 3, conviene corregirlo ahí — PriceLabs
-- calcula sus propias comparativas de mercado con ese número, no solo nosotros.
--
-- Las filas de mercado de JACO se borran (quirúrgico: solo JACO, solo tablas que llena el
-- sync) y la próxima corrida las regenera con categoria='2'. Tras aplicar esto: relanzar
-- el sync a mano (bloque de cron_setup.sql) para no esperar a las 07:10.

update listings set dormitorios = 2 where codigo = '1A_JACO' and dormitorios is distinct from 2;

delete from pricelabs_mercado where codigo = '1A_JACO';
delete from pricelabs_mercado_fotos where codigo = '1A_JACO';
