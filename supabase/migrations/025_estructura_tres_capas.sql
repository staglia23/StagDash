-- 025_estructura_tres_capas.sql — el cambio estructural del motor (Stag, 25/07/2026).
--
-- Hasta hoy el motor tenía DOS capas: ingreso − costes directos − overhead prorrateado por
-- peso de ingreso = margen neto. Eso mezclaba tres preguntas distintas en un solo número y,
-- peor, repartía el overhead con una base que NO es comparable entre propiedades.
--
-- ⚑ EL ERROR METODOLÓGICO QUE SE CORRIGE
--   Jacobine registra como ingreso solo su comisión (25 % del bruto); las otras tres registran
--   el host_payout completo. Mismo piso, misma carga operativa, pero contablemente Jacobine
--   "factura" cuatro veces menos. Repartir un coste común con una regla que se mide distinto
--   en cada unidad no es una preferencia: es un error. Evidencia: Jacobine hace 50 check-ins
--   (los otros 55–57) y soportaba el 12 % del overhead mientras Alexander soportaba el 28 %.
--   Efecto perverso adicional: subir el ADR de una propiedad le AUMENTABA su cuota de overhead
--   — el modelo penalizaba exactamente lo que se quiere que pase.
--
-- ⚑ LAS TRES CAPAS
--   1. CONTRIBUCIÓN = ingreso − costes directos.
--      Es lo que decide si te quedás con un piso: si desaparece, el overhead NO desaparece,
--      solo se reparte entre los demás. (Alexander aporta 10.115 € YTD: soltarlo dejaría a
--      Samavi 10.115 € peor, aunque su "margen neto" fuera negativo.)
--   2. MARGEN OPERATIVO = contribución − overhead de gestión, prorrateado por DÍAS BAJO
--      GESTIÓN. Elegido sobre "partes iguales" porque se autoajusta cuando una propiedad entra
--      o sale a mitad de año (Samavi va a sumar pisos de terceros), y sobre "por reservas o
--      noches" porque es neutral al rendimiento: el overhead se devenga por tener el piso en
--      cartera, se venda o no.
--   3. RESULTADO SAMAVI = suma de márgenes operativos − COSTES CORPORATIVOS, que NO se
--      prorratean: financieros (intereses e hipoteca), litigio heredado (BLT Law), formación
--      y marketing de crecimiento. No son coste de gestionar pisos; prorratearlos mezclaba el
--      resultado operativo con el financiero y hacía que cada piso pareciera peor de lo que es.
--
-- El resultado consolidado de Samavi NO cambia ni un euro: cada coste se pone donde se decide.
--
-- Regla 008: toda vista nueva lleva su GRANT o su REVOKE explícito.

-- ── 1) Marcar qué es corporativo ────────────────────────────────────────────────
alter table general_expenses add column if not exists es_corporativo boolean not null default false;

-- events.categoria tenía un CHECK cerrado a RENTA/OTROS/SAMAVI_GEN (001_schema).
-- Se abre a CORPORATIVO manteniendo la garantía de que no entren categorías sueltas.
alter table events drop constraint if exists events_categoria_check;
alter table events add  constraint events_categoria_check
  check (categoria = any (array['RENTA', 'OTROS', 'SAMAVI_GEN', 'CORPORATIVO']));

update general_expenses set es_corporativo = true
 where concepto in ('Brand Partners (marketing)',
                    'Seguro vida préstamo (Allianz 499,51/año)');

-- Los eventos corporativos salen de SAMAVI_GEN a su propia categoría.
update events set categoria = 'CORPORATIVO'
 where categoria = 'SAMAVI_GEN'
   and concepto in ('BLT Law — 6ª y última cuota gestores anteriores',
                    'Notaría escritura préstamo (Herrand)',
                    'Intereses préstamo BBVA (prefabricada)',
                    'Curso fiscalidad (Hotmart)',
                    'Servicio digital web (N. Casale)');

-- ── 2) Días bajo gestión: la nueva base de reparto ──────────────────────────────
-- Días del mes en que la propiedad ya estaba en cartera. Un piso que entra el 20 de octubre
-- solo carga 12 días de overhead de octubre, no el mes entero.
create or replace function dias_gestion(p_inicio date, p_anio int, p_mes int)
returns int language sql immutable as $$
  select case
    when p_inicio is null then days_in_month(p_anio, p_mes)
    when date_trunc('month', p_inicio) > make_date(p_anio, p_mes, 1) then 0
    when date_trunc('month', p_inicio) = make_date(p_anio, p_mes, 1)
      then days_in_month(p_anio, p_mes) - extract(day from p_inicio)::int + 1
    else days_in_month(p_anio, p_mes)
  end;
$$;

create or replace view v_dias_gestion as
select s.codigo, s.anio, s.mes, dias_gestion(l.fecha_inicio, s.anio, s.mes) as dias
from v_month_spine s join listings l on l.codigo = s.codigo;

revoke all on v_dias_gestion from anon, authenticated;   -- andamiaje interno

-- ── 3) El pool mensual se parte en operativo y corporativo ──────────────────────
create or replace view v_samavi_gen_mensual as
select m.anio, m.mes,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where not g.es_corporativo
      and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria = 'SAMAVI_GEN' and e.anio = m.anio and e.mes = m.mes), 0) as overhead,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where g.es_corporativo
      and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria = 'CORPORATIVO' and e.anio = m.anio and e.mes = m.mes), 0) as corporativo
from (select distinct anio, mes from v_month_spine) m;

-- ── 4) P&L mensual por propiedad: overhead por días de gestión ──────────────────
-- ⚑ Las columnas van ENUMERADAS, no con p.*: esta vista se creó en 003 con un p.* que quedó
--   congelado en 22 columnas, así que las que 009/021/022 añadieron a v_pnl_mensual_propiedad
--   nunca llegaron hasta acá. Con p.* un create or replace explota ("cannot change name of
--   view column"). Enumerar deja el orden bajo control y evita que vuelva a pasar.
create or replace view v_pnl_neto_propiedad as
with tot as (select anio, mes, sum(dias) as tot_dias from v_dias_gestion group by anio, mes)
select
  p.codigo, p.anio, p.mes, p.dias_mes, p.bruto, p.ingreso_samavi, p.comision_aparente,
  p.noches, p.reservas, p.ocup_pct, p.adr, p.revpar, p.alos,
  p.renta, p.limpieza, p.suministros, p.comunidad, p.otros,
  p.total_gastos_directos, p.margen_directo,
  round(-g.overhead * (dg.dias::numeric / nullif(t.tot_dias, 0)), 2)                    as cuota_samavi_gen,
  round(p.margen_directo - g.overhead * (dg.dias::numeric / nullif(t.tot_dias, 0)), 2)  as margen_neto,
  round(p.margen_directo, 2)                                                            as contribucion
from v_pnl_mensual_propiedad p
join v_dias_gestion dg      on dg.codigo = p.codigo and dg.anio = p.anio and dg.mes = p.mes
join tot t                  on t.anio = p.anio and t.mes = p.mes
join v_samavi_gen_mensual g on g.anio = p.anio and g.mes = p.mes;

-- ── 5) Ranking YTD: misma base ──────────────────────────────────────────────────
create or replace view v_ranking_ytd as
with ytd as (
  select codigo,
    sum(ingreso_samavi)         as ingreso_samavi,
    sum(bruto)                  as bruto,
    sum(noches)                 as noches,
    sum(reservas)               as reservas,
    sum(dias_mes)               as noches_disponibles,
    sum(total_gastos_directos)  as gastos_directos,
    sum(margen_directo)         as margen_directo,
    sum(ingreso_cancelaciones)  as ingreso_cancelaciones,
    sum(iva_repercutido)        as iva_repercutido
  from v_pnl_mensual_propiedad
  where anio = extract(year from now())::int
  group by codigo
),
dias as (
  select codigo, sum(dias) as dias
  from v_dias_gestion where anio = extract(year from now())::int group by codigo
),
oh as (select coalesce(sum(overhead), 0) as total from v_samavi_gen_mensual where anio = extract(year from now())::int),
td as (select coalesce(sum(dias), 0) as t from dias)
select
  y.codigo, y.ingreso_samavi, y.bruto, y.noches, y.reservas, y.noches_disponibles,
  y.gastos_directos, y.margen_directo,
  round(-(select total from oh) * (d.dias::numeric / nullif((select t from td), 0)), 2) as cuota_samavi_gen,
  round(y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0)), 2) as margen_neto,
  case when y.ingreso_samavi > 0
       then round((y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0))) / y.ingreso_samavi, 4)
       else 0 end as margen_neto_pct,
  case when y.noches > 0
       then round((y.margen_directo - (select total from oh) * (d.dias::numeric / nullif((select t from td), 0))) / y.noches, 2)
       else 0 end as eur_noche_neto,
  case when y.noches_disponibles > 0 then round(y.noches::numeric / y.noches_disponibles, 4) else 0 end as ocup_pct,
  case when y.noches > 0 then round(y.bruto / y.noches, 2) else 0 end as adr,
  case when y.noches_disponibles > 0 then round(y.bruto / y.noches_disponibles, 2) else 0 end as revpar,
  y.ingreso_cancelaciones,
  round(y.iva_repercutido, 2) as iva_repercutido,
  round(y.margen_directo, 2)  as contribucion,
  case when y.ingreso_samavi > 0 then round(y.margen_directo / y.ingreso_samavi, 4) else 0 end as contribucion_pct
from ytd y join dias d on d.codigo = y.codigo
order by margen_neto desc;

-- ── 6) KPIs: margen_neto_ytd pasa a ser el RESULTADO DE SAMAVI (tras corporativos) ──
-- Es lo que de verdad ganó el negocio, y es lo que titula la portada. El desglose por capas
-- queda en las columnas nuevas.
create or replace view v_kpis as
with corp as (
  select coalesce(sum(corporativo), 0) as total
  from v_samavi_gen_mensual where anio = extract(year from now())::int
)
select
  round(sum(r.margen_neto) - (select total from corp), 2)                                       as margen_neto_ytd,
  round(sum(r.ingreso_samavi), 2)                                                               as ingreso_samavi_ytd,
  round(sum(r.bruto), 2)                                                                        as bruto_ytd,
  sum(r.noches)                                                                                 as noches_ytd,
  sum(r.noches_disponibles)                                                                     as noches_disponibles_ytd,
  case when sum(r.noches_disponibles) > 0 then round(sum(r.noches)::numeric / sum(r.noches_disponibles), 4) else 0 end as ocupacion_ytd,
  case when sum(r.noches) > 0 then round(sum(r.bruto) / sum(r.noches), 2) else 0 end            as adr_ytd,
  case when sum(r.noches_disponibles) > 0 then round(sum(r.bruto) / sum(r.noches_disponibles), 2) else 0 end as revpar_ytd,
  case when sum(r.ingreso_samavi) > 0
       then round((sum(r.margen_neto) - (select total from corp)) / sum(r.ingreso_samavi), 4) else 0 end as margen_neto_pct_ytd,
  (select last_run from sync_state where id = 1)                                                as last_sync,
  round(sum(r.margen_neto), 2)                                                                  as margen_operativo_ytd,
  round((select total from corp), 2)                                                            as corporativo_ytd,
  round(sum(r.margen_directo), 2)                                                               as contribucion_ytd
from v_ranking_ytd r;

-- ── 7) Tendencia mensual: coherente con el KPI (incluye corporativos) ───────────
create or replace view v_trend_mensual as
select p.anio, p.mes,
  round(sum(p.ingreso_samavi), 2)                                        as ingreso_samavi,
  round(sum(p.margen_directo), 2)                                        as margen_directo,
  round(sum(p.margen_neto) - max(g.corporativo), 2)                      as margen_neto,
  round(max(g.corporativo), 2)                                           as corporativo
from v_pnl_neto_propiedad p
join v_samavi_gen_mensual g on g.anio = p.anio and g.mes = p.mes
group by p.anio, p.mes
order by p.anio, p.mes;

-- ── 8) Margen asegurado hacia adelante: misma base de reparto ───────────────────
create or replace view v_margen_asegurado as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0) as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0) as ev_otros
  from events group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    dias_gestion(l.fecha_inicio, s.anio, s.mes)           as dias_gest,
    coalesce(n.bruto, 0)                 as bruto,
    coalesce(n.ingreso_samavi, 0)        as ingreso_noches,
    coalesce(c.ingreso_cancelaciones, 0) as ingreso_cancelaciones,
    coalesce(n.noches, 0)                as noches,
    coalesce(b.reservas, 0)              as reservas,
    (((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0))
      * case when l.renta_factura_desde is not null
                  and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date
             then (1 + l.renta_iva_pct) / (1 + l.renta_iva_pct - l.renta_retencion_pct)
             else 1 end)                                                                        as renta,
    -(l.limpieza_por_reserva * coalesce(b.reservas,0))                                          as limpieza,
    -l.suministros_mes                                                                          as suministros,
    -l.comunidad_ibi_mes                                                                        as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                               as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
),
oh as (
  select m.anio, m.mes,
    (select coalesce(sum(g.importe_mes), 0)
       from general_expenses g
      where not g.es_corporativo
        and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
        and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
    - coalesce((select sum(importe) from events e
                where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
  from (select distinct anio, mes from v_forward_spine) m
),
tot as (select anio, mes, sum(dias_gest) as tot_dias from base group by anio, mes)
select
  b.codigo, b.anio, b.mes, b.dias_mes,
  round(b.bruto, 2)                                       as bruto,
  round(b.ingreso_noches + b.ingreso_cancelaciones, 2)    as ingreso_asegurado,
  b.noches                                                as noches_vendidas,
  round(b.noches::numeric / b.dias_mes, 4)                as ocup_vendida,
  round(b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as gastos_directos,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as margen_directo,
  round(-o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2)   as cuota_samavi_gen,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros
        - o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2)  as margen_neto
from base b
join oh  o on o.anio = b.anio and o.mes = b.mes
join tot t on t.anio = b.anio and t.mes = b.mes;

grant select on v_margen_asegurado to anon, authenticated;

-- ── 9) El puente de las tres capas, para /analisis ──────────────────────────────
create or replace view v_resultado_samavi as
with r as (
  select coalesce(sum(margen_directo), 0) as contribucion,
         coalesce(sum(cuota_samavi_gen), 0) as overhead_operativo,
         coalesce(sum(margen_neto), 0) as margen_operativo,
         coalesce(sum(ingreso_samavi), 0) as ingreso
  from v_ranking_ytd
),
c as (select coalesce(sum(corporativo), 0) as corporativo
      from v_samavi_gen_mensual where anio = extract(year from now())::int)
select
  round(r.ingreso, 2)                                as ingreso_samavi,
  round(r.contribucion, 2)                           as contribucion,
  round(-r.overhead_operativo, 2)                    as overhead_operativo,
  round(r.margen_operativo, 2)                       as margen_operativo,
  round(c.corporativo, 2)                            as costes_corporativos,
  round(r.margen_operativo - c.corporativo, 2)       as resultado_samavi
from r, c;

grant select on v_resultado_samavi to anon, authenticated;

-- ── 10) El cuadre aprende las tres capas ────────────────────────────────────────
-- Chequeo 2 pasa a validar la cascada COMPLETA (operativo + corporativo) y el 3 valida que
-- las cuotas reconstruyan el pool OPERATIVO. Se añade el 10: el puente de capas cierra.
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
oh     as (select coalesce(sum(overhead), 0) as total, coalesce(sum(corporativo), 0) as corp
           from v_samavi_gen_mensual where anio = (select anio from a)),
cuotas as (select coalesce(sum(cuota_samavi_gen), 0) as suma from v_pnl_neto_propiedad where anio = (select anio from a)),
capas  as (select contribucion, overhead_operativo, margen_operativo, costes_corporativos, resultado_samavi from v_resultado_samavi),
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
  select 2, 'margen_neto_ytd', 'Resultado = contribución − overhead − corporativos',
    case when abs(k.margen_neto_ytd - (m.margen_directo - o.total - o.corp)) <= 0.05 then 'ok' else 'alerta' end,
    round(m.margen_directo - o.total - o.corp, 2), k.margen_neto_ytd, 'eur',
    'La cascada de tres capas devuelve el mismo total que la resta directa.'
  from mensual m, kpi k, oh o
  union all
  select 3, 'prorrateo_overhead', 'El overhead operativo prorrateado suma el 100 %',
    case when abs(-c.suma - o.total) <= 0.5 then 'ok' else 'alerta' end,
    round(o.total, 2), round(-c.suma, 2), 'eur',
    'Las cuotas por días de gestión reconstruyen el pool operativo, sin perder ni duplicar.'
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
  union all
  select 10, 'puente_capas', 'Las tres capas cierran entre sí',
    case when abs((cp.contribucion - cp.overhead_operativo - cp.costes_corporativos) - cp.resultado_samavi) <= 0.05
         then 'ok' else 'alerta' end,
    round(cp.contribucion - cp.overhead_operativo - cp.costes_corporativos, 2), cp.resultado_samavi, 'eur',
    'Contribución − overhead de gestión − costes corporativos = resultado de Samavi.'
  from capas cp
) checks
order by orden;

grant select on v_cuadre to anon, authenticated;
