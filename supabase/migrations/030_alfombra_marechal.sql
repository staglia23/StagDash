-- 030_alfombra_marechal.sql — limpieza de alfombra de Marechal (Stag, 25/07/2026).
--
-- Aparece en la factura F260176 de Ecocleans (abril) como servicio puntual de tapicería,
-- fuera de las líneas de limpieza / amenities / renting. Stag confirmó que la alfombra es de
-- Marechal, así que es coste directo de la propiedad y no overhead.
--
-- Va como event y no en `limpieza_mensual` (migración 031) a propósito: esa tabla guarda el
-- servicio recurrente de limpieza por propiedad, no los puntuales de tapicería. Si se mezclan,
-- el coste por servicio deja de ser comparable entre meses.

insert into events (propiedad_codigo, anio, mes, categoria, concepto, importe)
select '3G_MARE', 2026, 4, 'OTROS', 'Limpieza de alfombra (Ecocleans F260176, servicio puntual)', -60.50
where not exists (
  select 1 from events where propiedad_codigo = '3G_MARE' and anio = 2026 and mes = 4
    and concepto like 'Limpieza de alfombra%');
