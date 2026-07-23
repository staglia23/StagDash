-- 012_cuadre.sql — /cuadre: el motor se verifica a sí mismo (roadmap 22/07/2026;
-- reemplaza los "chequeos aleatorios" que propuso Fede por validación automática).
-- Una fila por chequeo: el front SOLO renderiza — la definición de "cuadrar" vive acá.
--   · estado: 'ok' | 'alerta' | 'info' (info = dato de contexto, no pasa/falla)
--   · esperado/obtenido: los dos caminos del cálculo; unidad dice cómo formatear.
--   · Tolerancias: 0,05 € en sumas redondeadas una vez; 0,50 € donde el redondeo se
--     acumula por fila (cuotas por propiedad-mes, canal por propiedad-canal).
-- Regla 008: vista nueva nace pública por default privileges → GRANT explícito.
-- No expone PII: solo agregados, contadores y fechas de proceso.

create or replace view v_cuadre as
with a as (select extract(year from now())::int as anio),
mensual as (
  select coalesce(sum(ingreso_samavi), 0)         as ingreso,
         coalesce(sum(ingreso_noches), 0)         as ingreso_noches,
         coalesce(sum(ingreso_cancelaciones), 0)  as cancelaciones,
         coalesce(sum(margen_directo), 0)         as margen_directo
  from v_pnl_mensual_propiedad where anio = (select anio from a)
),
kpi    as (select ingreso_samavi_ytd, margen_neto_ytd from v_kpis),
oh     as (select coalesce(sum(overhead), 0) as total from v_samavi_gen_mensual where anio = (select anio from a)),
cuotas as (select coalesce(sum(cuota_samavi_gen), 0) as suma from v_pnl_neto_propiedad where anio = (select anio from a)),
canal  as (select coalesce(sum(ingreso), 0) as ingreso from v_canal_ytd),
fisica as (select count(*) as n from v_pnl_mensual_propiedad where noches > dias_mes),
ilegibles as (
  select count(*) as n from reservations r
  where r.status in ('confirmed', 'checked_in', 'checked_out')
    and (r.checkin_local is null or r.checkout_local is null or r.checkout_local <= r.checkin_local)
),
sync as (
  select last_run, round((extract(epoch from (now() - last_run)) / 3600)::numeric, 1) as horas
  from sync_state where id = 1
),
conc as (select max(make_date(anio, mes, 1)) as hasta from events where concepto ilike '%real bancos%')
select * from (
  select 1 as orden, 'ingreso_ytd' as chequeo,
    'El ingreso YTD es la suma de los meses' as titulo,
    case when abs(m.ingreso - k.ingreso_samavi_ytd) <= 0.05 then 'ok' else 'alerta' end as estado,
    round(m.ingreso, 2) as esperado, k.ingreso_samavi_ytd as obtenido, 'eur' as unidad,
    'Suma mensual por propiedad vs la tarjeta de la portada.' as detalle
  from mensual m, kpi k
  union all
  select 2, 'margen_neto_ytd', 'Margen neto = margen directo − overhead',
    case when abs(k.margen_neto_ytd - (m.margen_directo - o.total)) <= 0.05 then 'ok' else 'alerta' end,
    round(m.margen_directo - o.total, 2), k.margen_neto_ytd, 'eur',
    'La cascada completa (prorrateo incluido) devuelve el mismo total que la resta directa.'
  from mensual m, kpi k, oh o
  union all
  select 3, 'prorrateo_overhead', 'El overhead prorrateado suma el 100 %',
    case when abs(-c.suma - o.total) <= 0.5 then 'ok' else 'alerta' end,
    round(o.total, 2), round(-c.suma, 2), 'eur',
    'Las cuotas por propiedad reconstruyen el pool de gastos generales, sin perder ni duplicar.'
  from cuotas c, oh o
  union all
  select 4, 'canal_vs_ingreso', 'El mix por canal cuadra con el ingreso por noches',
    case when abs(cn.ingreso - m.ingreso_noches) <= 0.5 then 'ok' else 'alerta' end,
    round(m.ingreso_noches, 2), round(cn.ingreso, 2), 'eur',
    'Los canales suman el ingreso devengado por noche; las cancelaciones retenidas van aparte.'
  from canal cn, mensual m
  union all
  select 5, 'cancelaciones_aparte', 'Ingreso = noches + cancelaciones retenidas',
    case when abs(m.ingreso - (m.ingreso_noches + m.cancelaciones)) <= 0.01 then 'ok' else 'alerta' end,
    round(m.ingreso, 2), round(m.ingreso_noches + m.cancelaciones, 2), 'eur',
    'La línea separada de cancelaciones no toca noches, ocupación ni ADR.'
  from mensual m
  union all
  select 6, 'ocupacion_fisica', 'Ningún mes con más noches que días',
    case when f.n = 0 then 'ok' else 'alerta' end,
    0, f.n, 'casos',
    'Noches devengadas ≤ días del mes, en todas las propiedades.'
  from fisica f
  union all
  select 7, 'reservas_ilegibles', 'Todas las reservas activas son contables',
    case when i.n = 0 then 'ok' else 'alerta' end,
    0, i.n, 'casos',
    'Una reserva confirmada sin fechas válidas quedaría fuera del devengo sin avisar.'
  from ilegibles i
  union all
  select 8, 'sync_guesty', 'Datos de Guesty al día',
    case when s.horas <= 6 then 'ok' else 'alerta' end,
    6, s.horas, 'horas',
    'El sync corre cada 3 h; más de 6 h sin correr es un problema, no un retraso.'
  from sync s
  union all
  select 9, 'conciliacion_bancos', 'Conciliado contra bancos',
    'info',
    null::numeric, extract(month from c.hasta)::numeric, 'mes',
    'Último mes con gastos reales de bancos cargados (ritual de cierre mensual).'
  from conc c
) checks
order by orden;

grant select on v_cuadre to anon, authenticated;
