-- 027_enjoy_travel_corporativo.sql — el último viaje pendiente de clasificar.
--
-- Los 66,04 € de "Viajes tarjeta (Enjoy Travel)" de junio quedaron fuera de la migración 026
-- porque no se le habían preguntado a Stag. Confirmado el 25/07/2026: también es desarrollo
-- de negocio, así que va al bloque corporativo y deja de prorratearse entre las propiedades.
--
-- Con esto, los tres viajes de 2026 (feb 1.447,64 · mar 600,73 · jun 66,04 = 2.114,41 €) están
-- fuera del overhead operativo.

update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN' and anio = 2026
   and concepto = 'Viajes tarjeta (Enjoy Travel)';
