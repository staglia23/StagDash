-- 026_viajes_a_corporativo.sql — los viajes son desarrollo de negocio, no gestión de pisos.
--
-- Confirmado por Stag el 25/07/2026 al preguntarle si eran desplazamientos para gestionar las
-- propiedades o para desarrollar el negocio. Siendo lo segundo, van al bloque corporativo
-- (migración 025) y dejan de prorratearse entre las cuatro propiedades: no son coste de
-- tenerlas en cartera.
--
--   · feb  1.447,64 €  — tarjeta (ITA / Booking / Iberia)
--   · mar    600,73 €  — viaje por carretera (Hertz / hotel / gasolina / peajes)
--
-- Pendiente de confirmar: los 66,04 € de junio (Enjoy Travel), que no se preguntaron.
-- El resultado consolidado de Samavi no cambia; sí bajan los costes de las cuatro propiedades.

update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN' and anio = 2026
   and concepto in ('Viajes tarjeta (ITA/Booking/Iberia)',
                    'Viaje por carretera (Hertz/hotel/gasolina/peajes)');
