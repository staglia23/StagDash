-- 034_suministros_reales.sql — los suministros dejan de ser un fijo inventado (Stag, 25/07/2026).
--
-- Mismo patrón que la limpieza (031): una tabla con el dato real, una vista que decide en un solo
-- sitio si el motor usa el real o el estimado, y una etiqueta para que el dashboard pueda decirlo.
--
-- ── DE DÓNDE SALE ───────────────────────────────────────────────────────────────
-- 31 facturas de la carpeta Confisic 2026 (Total Energies, Galápago/papernest, Movistar), leídas
-- una a una con verificación de base+IVA=total en cada una. Prorrateadas POR DÍA: ninguna factura
-- coincide con un mes natural, así que imputar por fecha de emisión desplazaría el coste.
--
-- ── SOLO ENTRAN LOS MESES CON COBERTURA COMPLETA ────────────────────────────────
-- Un mes al que le falta una semana de facturación NO es un dato real, es un dato bajo. Cobertura
-- verificada por CUPS, no por carpeta (el archivado va desfasado uno o dos meses respecto de la
-- emisión, así que la carpeta del mes no dice nada):
--   · 1A_NICA (…492DT1P + gas): cubierto 01.01 → 11.05  → entran ene, feb, mar, abr.
--   · 4B_ALEX (…519XG1P):       cubierto 24.01 → 12.07  → entran feb, mar, abr, may, jun.
--   · 3G_MARE (…514DE1P):       cubierto 12.01 → 12.07 con un hueco de 8 días (05–11.04)
--                                                      → entran feb, mar, may, jun.
-- Lo que queda fuera cae al estimado y se etiqueta. Los huecos abiertos están en el informe:
-- NICA no tiene NINGUNA factura desde el 11.05 (dos ciclos del piso más caro), y falta el tramo
-- de enero de ALEX y MARE, que es de la comercializadora anterior.
--
-- ── EL INTERNET ES UNA HIPÓTESIS, Y VA MARCADA ──────────────────────────────────
-- Movistar factura 55,00 €/mes clavados (la serie más sólida del ejercicio: seis meses sin
-- variación) pero UNA sola factura cubre DOS fibras de Calle Segovia y el PDF enmascara el piso
-- de instalación. Por la regla de negocio son ALEX y MARE. Se reparte 27,50/27,50 y se marca
-- `fiable = false`: el reparto real por línea es 30,00/25,00, así que el error máximo es 2,50 €
-- por piso y mes. Se cierra cuando Stag diga qué fijo (…84 o …89) está en cada piso.
-- Nicasio no lleva internet acá: su fibra es la de Orange y ya está en el overhead (028).
--
-- ── EL AGUA NO ENTRA ────────────────────────────────────────────────────────────
-- La de Alexander ya está cargada como events SUMINISTROS (028) y la vista los suma aparte:
-- meterla acá sería contarla dos veces. De Nicasio y Marechal no hay un solo recibo en el
-- semestre; la hipótesis es que va dentro de la cuota de comunidad, y NO está verificada.
--
-- El IVA va incluido, mismo criterio que renta (022) y limpieza (031): peor caso, no deducible.
-- OJO: seis agentes independientes leyeron que desde febrero de 2026 la luz de ALEX y MARE está
-- a nombre de la SOCIEDAD, no personal. Si Confisic lo confirma, ese IVA es deducible y este
-- criterio se invierte — pero se cambia en un solo sitio.

create table if not exists suministros_mensual (
  anio         int  not null,
  mes          int  not null check (mes between 1 and 12),
  codigo       text not null references listings(codigo),
  luz_eur      numeric(10,2) not null default 0,   -- luz + gas, con IVA
  internet_eur numeric(10,2) not null default 0,
  total_eur    numeric(10,2) not null default 0,
  fiable       boolean       not null default true,
  nota         text,
  cargado_at   timestamptz   not null default now(),
  primary key (anio, mes, codigo)
);

comment on table suministros_mensual is
  'Coste real de suministros por propiedad y mes, prorrateado por día. Solo meses con cobertura completa.';

revoke all on suministros_mensual from anon, authenticated;

insert into suministros_mensual (anio, mes, codigo, luz_eur, internet_eur, total_eur, fiable, nota)
values
  (2026, 1, '1A_NICA', 159.69,  0.00, 159.69, true,  'Luz+gas TotalEnergies, contrato dual a nombre de la sociedad'),
  (2026, 2, '1A_NICA', 138.70,  0.00, 138.70, true,  null),
  (2026, 3, '1A_NICA', 106.95,  0.00, 106.95, true,  null),
  (2026, 4, '1A_NICA',  82.44,  0.00,  82.44, true,  'Gas con consumo 0 kWh: solo término fijo (~83 €/año)'),
  (2026, 2, '4B_ALEX', 126.92, 27.50, 154.42, false, 'Internet: reparto hipotético 27,50 de los 55,00 de Movistar'),
  (2026, 3, '4B_ALEX',  92.58, 27.50, 120.08, false, 'Internet: reparto hipotético'),
  (2026, 4, '4B_ALEX',  68.63, 27.50,  96.13, false, 'Internet: reparto hipotético'),
  (2026, 5, '4B_ALEX',  76.36, 27.50, 103.86, false, 'Internet: reparto hipotético'),
  (2026, 6, '4B_ALEX',  89.08, 27.50, 116.58, false, 'Internet: reparto hipotético'),
  (2026, 2, '3G_MARE',  96.43, 27.50, 123.93, false, 'Internet: reparto hipotético'),
  (2026, 3, '3G_MARE',  76.07, 27.50, 103.57, false, 'Internet: reparto hipotético'),
  (2026, 5, '3G_MARE',  61.24, 27.50,  88.74, false, 'Internet: reparto hipotético'),
  (2026, 6, '3G_MARE',  77.69, 27.50, 105.19, false, 'Internet: reparto hipotético')
on conflict (anio, mes, codigo) do nothing;

-- Un solo sitio decide qué coste de suministros usa el motor, para YTD y para forward.
create or replace view v_suministros_mensual as
select
  s.codigo, s.anio, s.mes,
  case when sm.codigo is not null then -sm.total_eur
       else -l.suministros_mes end                                as coste,
  case when sm.codigo is null then 'estimado'
       when sm.fiable          then 'real'
       else                         'real_revisar' end            as fuente,
  sm.luz_eur, sm.internet_eur, sm.nota
from v_month_spine s
join listings l              on l.codigo = s.codigo
left join suministros_mensual sm on sm.codigo=s.codigo and sm.anio=s.anio and sm.mes=s.mes;

grant select on v_suministros_mensual to anon, authenticated;

-- El motor consume la vista. Los events SUMINISTROS (el agua de Alexander) siguen sumándose
-- aparte, que es lo correcto: son reembolsos puntuales, no la factura recurrente.
create or replace view v_pnl_mensual_propiedad as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0)       as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0)       as ev_otros,
    coalesce(sum(importe) filter (where categoria='SUMINISTROS'),0) as ev_suministros
  from events
  group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    coalesce(n.bruto,0)                  as bruto,
    coalesce(n.ingreso_samavi,0)         as ingreso_noches,
    coalesce(c.ingreso_cancelaciones,0)  as ingreso_cancelaciones,
    coalesce(n.noches,0)                 as noches,
    coalesce(b.reservas,0)               as reservas,
    coalesce(n.iva_repercutido,0) + coalesce(c.iva_cancelaciones,0) as iva_repercutido,
    coalesce(n.comision_canal,0)         as comision_canal,
    coalesce(n.comision_canal_samavi,0)  as comision_canal_samavi,
    ((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0)) as renta_transfer,
    (l.renta_factura_desde is not null
      and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date) as con_factura,
    l.renta_iva_pct, l.renta_retencion_pct,
    lp.coste                                                                                as limpieza,
    lp.fuente                                                                               as limpieza_fuente,
    (sp.coste + coalesce(ev.ev_suministros,0))                                              as suministros,
    sp.fuente                                                                               as suministros_fuente,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  join v_limpieza_mensual lp          on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
  join v_suministros_mensual sp       on sp.codigo=s.codigo and sp.anio=s.anio and sp.mes=s.mes
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
),
conv as (
  select b.*,
    case when b.con_factura
         then (1 + b.renta_iva_pct) / (1 + b.renta_iva_pct - b.renta_retencion_pct)
         else 1 end as factor,
    case when b.con_factura
         then b.renta_iva_pct / (1 + b.renta_iva_pct - b.renta_retencion_pct)
         else 0 end as factor_iva
  from base b
),
final as (
  select c.*,
    round(c.renta_transfer * c.factor, 2)     as renta,
    round(c.renta_transfer * c.factor_iva, 2) as renta_iva
  from conv c
)
select
  codigo, anio, mes, dias_mes, bruto,
  (ingreso_noches + ingreso_cancelaciones)                            as ingreso_samavi,
  (bruto - ingreso_noches)                                            as comision_aparente,
  noches, reservas,
  round(noches::numeric / dias_mes, 4)                                as ocup_pct,
  case when noches > 0 then round(bruto / noches, 2) else 0 end       as adr,
  round(bruto / dias_mes, 2)                                          as revpar,
  case when reservas > 0 then round(noches::numeric / reservas, 2) else 0 end as alos,
  renta, limpieza, suministros, comunidad, otros,
  (renta + limpieza + suministros + comunidad + otros)                as total_gastos_directos,
  (ingreso_noches + ingreso_cancelaciones
     + renta + limpieza + suministros + comunidad + otros)            as margen_directo,
  ingreso_noches,
  ingreso_cancelaciones,
  iva_repercutido,
  renta_iva,
  limpieza_fuente,
  round(comision_canal, 2)        as comision_canal,
  round(comision_canal_samavi, 2) as comision_canal_samavi,
  suministros_fuente
from final;

-- Forward: los meses futuros no tienen factura, así que caen solos al estimado.
create or replace view v_margen_asegurado as
with ev as (
  select propiedad_codigo as codigo, anio, mes,
    coalesce(sum(importe) filter (where categoria='RENTA'),0)       as ev_renta,
    coalesce(sum(importe) filter (where categoria='OTROS'),0)       as ev_otros,
    coalesce(sum(importe) filter (where categoria='SUMINISTROS'),0) as ev_suministros
  from events group by propiedad_codigo, anio, mes
),
base as (
  select
    s.codigo, s.anio, s.mes, days_in_month(s.anio, s.mes) as dias_mes,
    dias_gestion(l.fecha_inicio, s.anio, s.mes)           as dias_gest,
    coalesce(n.bruto, 0) as bruto, coalesce(n.ingreso_samavi, 0) as ingreso_noches,
    coalesce(c.ingreso_cancelaciones, 0) as ingreso_cancelaciones,
    coalesce(n.noches, 0) as noches, coalesce(b.reservas, 0) as reservas,
    (((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0))
      * case when l.renta_factura_desde is not null
                  and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date
             then (1 + l.renta_iva_pct) / (1 + l.renta_iva_pct - l.renta_retencion_pct)
             else 1 end)                                                                    as renta,
    coalesce(lp.coste, -(l.limpieza_por_reserva * coalesce(b.reservas,0)))                   as limpieza,
    (coalesce(sp.coste, -l.suministros_mes) + coalesce(ev.ev_suministros,0))                 as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_limpieza_mensual lp     on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
  left join v_suministros_mensual sp  on sp.codigo=s.codigo and sp.anio=s.anio and sp.mes=s.mes
  left join v_nights_monthly n        on n.codigo=s.codigo and n.anio=s.anio and n.mes=s.mes
  left join v_bookings_monthly b      on b.codigo=s.codigo and b.anio=s.anio and b.mes=s.mes
  left join v_ingreso_cancelaciones c on c.codigo=s.codigo and c.anio=s.anio and c.mes=s.mes
  left join ev                        on ev.codigo=s.codigo and ev.anio=s.anio and ev.mes=s.mes
),
oh as (
  select m.anio, m.mes,
    (select coalesce(sum(g.importe_mes), 0) from general_expenses g
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
  round(b.bruto, 2) as bruto,
  round(b.ingreso_noches + b.ingreso_cancelaciones, 2) as ingreso_asegurado,
  b.noches as noches_vendidas,
  round(b.noches::numeric / b.dias_mes, 4) as ocup_vendida,
  round(b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as gastos_directos,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros, 2) as margen_directo,
  round(-o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2) as cuota_samavi_gen,
  round(b.ingreso_noches + b.ingreso_cancelaciones
        + b.renta + b.limpieza + b.suministros + b.comunidad + b.otros
        - o.overhead * (b.dias_gest::numeric / nullif(t.tot_dias, 0)), 2) as margen_neto
from base b
join oh  o on o.anio = b.anio and o.mes = b.mes
join tot t on t.anio = b.anio and t.mes = b.mes;

grant select on v_margen_asegurado to anon, authenticated;
