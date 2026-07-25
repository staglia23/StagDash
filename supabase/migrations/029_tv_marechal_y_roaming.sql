-- 029_tv_marechal_y_roaming.sql — cierre de la línea de Orange (Stag, 25/07/2026).
--
-- Al leer las seis facturas de Orange del año quedó claro que la línea de overhead no era
-- "fibra pisos + dispositivos" sino: una fibra (Nicasio, ya extraída en 028), tres móviles,
-- dispositivos a plazos, roaming internacional y compras de aplicaciones.
--
-- ── LA TV VA A MARECHAL ─────────────────────────────────────────────────────────
-- La TV Xiaomi está físicamente en Marechal. Misma regla que el mobiliario de Sequra (Marechal)
-- y el de Klarna (Alexander): si el gasto está en un piso concreto y es atribuible sin juicio,
-- va directo; si se comparte entre los cuatro, va al overhead. Mantener la regla importa más
-- que el importe — una excepción "porque es poco" deja un criterio que nadie puede aplicar
-- después.
-- Las facturas muestran el plazo 44/48 en enero y el PAGO ANTICIPADO en marzo por 460,78 €,
-- que ya estaba cargado como evento de overhead ("Orange amortización equipos"). Ese evento
-- pasa a ser coste directo de 3G_MARE. Las cuotas de ene-feb (17,76 × 2 = 35,52 €) quedan
-- dentro del promedio de la línea: inmaterial y no vale la pena desagregarlas.
--
-- ── EL ROAMING ES CORPORATIVO ───────────────────────────────────────────────────
-- Mismo criterio que los viajes (026 y 027): es desarrollo de negocio, no gestión de pisos.
-- Documentado en las facturas: 120,25 € (ene) + 29,89 € (mar) + 28,10 € (jun) = 178,24 € en
-- seis meses = 29,71 €/mes. Se mueve por promedio porque la línea de Orange ya es un promedio
-- mensual; cuando exista la ingesta de facturas reales (paso 3) esto pasa a ser exacto.
--
-- Móviles y dispositivos (AirPods, Watch, iPhone) se quedan en el overhead operativo: son
-- herramienta compartida de gestión y no hay forma de repartirlos entre pisos sin inventar.

update events
   set propiedad_codigo = '3G_MARE',
       categoria        = 'OTROS',
       concepto         = 'TV Xiaomi de Marechal (Orange, pago anticipado del plazo)'
 where propiedad_codigo = 'SAMAVI_GEN' and anio = 2026 and mes = 3
   and concepto = 'Orange amortización equipos (tarjeta)';

update general_expenses
   set importe_mes = 271.67,
       concepto    = 'Orange — móviles y dispositivos'
 where concepto = 'Orange — móviles, dispositivos y roaming';

insert into general_expenses (concepto, importe_mes, desde, hasta, es_corporativo)
select 'Roaming internacional (Orange)', 29.71, null, null, true
where not exists (select 1 from general_expenses where concepto = 'Roaming internacional (Orange)');
