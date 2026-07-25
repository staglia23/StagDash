-- 024_viajes_fantasma.sql — fuera la línea fija de "Viajes corporativos (transporte)".
--
-- Mismo caso que 'Otros AEAT/admin' (eliminado el 25/07/2026, commit 5f87ed7) y con el mismo
-- razonamiento: era una provisión fija de 200 €/mes que nunca se consumía, mientras los viajes
-- REALES entran como events conciliados contra banco. Contarla era doble conteo, y subestimaba
-- el margen de las cuatro propiedades.
--
-- Viajes reales cargados como eventos en 2026 (todos confirmados como gasto de negocio por
-- Stag el 25/07/2026):
--   · feb  1.447,64 €  — tarjeta (ITA / Booking / Iberia)
--   · mar    600,73 €  — viaje por carretera (Hertz / hotel / gasolina / peajes)
--   · jun     66,04 €  — tarjeta (Enjoy Travel)
--   Total 2.114,41 € frente a 1.400 € que habría provisionado la línea fija en 7 meses.
--
-- Efecto: el pool de overhead baja 200 €/mes. Alexander, que soporta el 28,36 % del overhead,
-- recupera unos 57 €/mes (≈681 €/año).
--
-- Las comidas de negocio ya se habían sacado de esta línea el 25/07 y entran como eventos.

delete from general_expenses where concepto = 'Viajes corporativos (transporte)';
