-- 037 — v_costes_ytd expone comision_canal (la que soporta Samavi), para que el simulador
-- pueda calcular el punto de equilibrio de la captación por canal directo: el ahorro por
-- noche directa ES el coste del canal por noche, y eso es lo máximo que se puede gastar en
-- captarla antes de que deje de convenir. Umbral derivado, no inventado.
--
-- NOTA (29/07/2026): este archivo se repone retroactivamente. El commit 57dcd76 aplicó la
-- migración en producción pero nunca creó el archivo ni copió el cuerpo a apply_all.sql
-- (que hasta hoy conservaba la definición de la 022, sin comision_canal — un rebuild desde
-- ahí rompía el simulador). Definición recuperada de producción con pg_get_viewdef.

create or replace view v_costes_ytd as
with ytd as (
  select codigo,
         sum(renta)                 as renta,
         sum(limpieza)              as limpieza,
         sum(suministros)           as suministros,
         sum(comunidad)             as comunidad,
         sum(otros)                 as otros,
         sum(total_gastos_directos) as total_directos,
         sum(ingreso_samavi)        as ingreso,
         sum(renta_iva)             as renta_iva,
         sum(comision_canal_samavi) as comision_canal_samavi
    from v_pnl_mensual_propiedad
   where anio = extract(year from now())::int
   group by codigo
)
select
  y.codigo,
  round(-y.renta, 2)                                 as renta,
  round(-y.limpieza, 2)                              as limpieza,
  round(-y.suministros, 2)                           as suministros,
  round(-y.comunidad, 2)                             as comunidad,
  round(-y.otros, 2)                                 as otros,
  round(-y.total_directos, 2)                        as total_directos,
  round(-r.cuota_samavi_gen, 2)                      as overhead,
  round(-(y.total_directos + r.cuota_samavi_gen), 2) as total_costes,
  case when y.ingreso > 0
       then round((-(y.total_directos + r.cuota_samavi_gen)) / y.ingreso, 4)
       else 0 end                                    as pct_sobre_ingreso,
  round(-y.renta_iva, 2)                             as renta_iva,
  round(y.comision_canal_samavi, 2)                  as comision_canal
from ytd y
join v_ranking_ytd r on r.codigo = y.codigo;

grant select on v_costes_ytd to anon, authenticated;
