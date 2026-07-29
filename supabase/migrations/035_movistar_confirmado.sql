-- 035 — reparto de Movistar confirmado por Stag: línea barata (25,00 c/IVA) a Alexander,
-- cara (30,00) a Marechal. Los 13 meses-propiedad de suministros dejan de ser hipótesis.
--
-- NOTA (29/07/2026): este archivo se repone retroactivamente. El commit 177360a aplicó la
-- migración en producción y copió el cuerpo a apply_all.sql, pero nunca creó el archivo.
-- Idempotente: el WHERE ancla sobre el valor provisional (27,50) que ya no existe.

update suministros_mensual
   set internet_eur = 25.00, total_eur = round(luz_eur + 25.00, 2), fiable = true
 where codigo = '4B_ALEX' and anio = 2026 and internet_eur = 27.50;

update suministros_mensual
   set internet_eur = 30.00, total_eur = round(luz_eur + 30.00, 2), fiable = true
 where codigo = '3G_MARE' and anio = 2026 and internet_eur = 27.50;
