-- 031_limpieza_real.sql — la limpieza deja de estimarse (Stag, 25/07/2026).
--
-- Hasta acá el motor calculaba la limpieza como `limpieza_por_reserva × reservas` (43,80 €).
-- Es una media que no ve las horas extra, los rentings dobles ni los servicios SUR, y en seis
-- meses subestimaba a Alexander en 250 € y a Nicasio en 172 €.
--
-- Ahora entra el dato real: seis facturas de Ecocleans (Facilities Services BMR SLU) leídas
-- una a una contra su RESUMEN SERVICIOS MENSUAL, con las tres identidades cerradas al céntimo
-- en cada mes (Σ horas = línea de limpieza · Σ renting = línea de renting · Σ servicios = kits).
--
-- ── LA TABLA ES EL PUNTO DE ENTRADA DE LA CONCILIACIÓN ──────────────────────────
-- `limpieza_mensual` está pensada para que la escriba el Apps Script que ya hace la
-- conciliación (Ecocleans_Auto.js): una fila por propiedad y mes al final de conciliarMes().
-- Por eso lleva `fiable`: el script sabe cuándo su extracción fila-a-fila NO cuadra con el
-- resumen (usaHorasResumen / usaRentingResumen). Cuando no cuadra, el dato entra igual pero
-- marcado, y el dashboard lo puede etiquetar en vez de fingir precisión.
--
-- ── LO QUE NO ENTRA, Y POR QUÉ ──────────────────────────────────────────────────
-- Las facturas traen dos abonos que corrigen meses anteriores y no son atribuibles a un piso:
--   · ene  −52,50 €  "Descuento amenities baño diciembre 2025"  (corrige 2025)
--   · mar  −12,30 €  "Error facturación febrero, 45 min de más" (corrige febrero)
-- La tabla guarda los servicios REALIZADOS en el mes, así que la suma por propiedad queda
-- 64,80 € (base) por encima de lo pagado al banco en ene–jun. Es correcto: son correcciones de
-- período anterior, no coste del mes. Si algún día se quieren en el modelo, van como events.
--
-- Junio factura 23 kits contra 24 servicios (un servicio sin amenities) y el resumen no dice
-- cuál. Se cargan 24 × 1,80 €: 1,80 € de base de más, no atribuible. Con eso, la suma por
-- propiedad de ene–jun (7.217,80 € c/IVA) menos los abonos y ese kit reconcilia con los
-- 7.137,22 € pagados.
--
-- El IVA se guarda aparte y se suma al coste, igual que en la renta (migración 022): peor caso,
-- IVA no deducible. Si Confisic confirma que sí lo es, se cambia en un solo sitio.

create table if not exists limpieza_mensual (
  anio         int  not null,
  mes          int  not null check (mes between 1 and 12),
  codigo       text not null references listings(codigo),
  servicios    int           not null default 0,
  horas        numeric(8,2)  not null default 0,
  limpieza_eur numeric(10,2) not null default 0,   -- horas × precio/hora
  kits_eur     numeric(10,2) not null default 0,   -- amenities
  renting_eur  numeric(10,2) not null default 0,   -- renting textil
  base_eur     numeric(10,2) not null default 0,
  iva_eur      numeric(10,2) not null default 0,
  factura      text,
  fiable       boolean       not null default true, -- la extracción cuadró con la factura
  cargado_at   timestamptz   not null default now(),
  primary key (anio, mes, codigo)
);

comment on table limpieza_mensual is
  'Coste real de limpieza por propiedad y mes. La escribe la conciliación de Ecocleans.';

-- Tabla RAW: se lee solo a través de las vistas.
revoke all on limpieza_mensual from anon, authenticated;

insert into limpieza_mensual
  (anio, mes, codigo, servicios, horas, limpieza_eur, kits_eur, renting_eur, base_eur, iva_eur, factura)
values
  (2026,  1,'1A_NICA',  8, 14.00, 229.60, 14.40,  92.32,  336.32,  70.63,'F260063'),
  (2026,  1,'4B_ALEX',  7, 10.50, 172.20, 12.60,  92.68,  277.48,  58.27,'F260063'),
  (2026,  1,'3G_MARE',  9, 13.50, 221.40, 16.20,  93.96,  331.56,  69.63,'F260063'),
  (2026,  2,'1A_NICA', 10, 20.25, 332.10, 18.00, 124.00,  474.10,  99.56,'F260090'),
  (2026,  2,'4B_ALEX',  7, 11.33, 185.81, 12.60, 111.28,  309.69,  65.03,'F260090'),
  (2026,  2,'3G_MARE',  7, 11.00, 180.40, 12.60,  73.08,  266.08,  55.88,'F260090'),
  (2026,  3,'1A_NICA',  7, 14.00, 229.60, 12.60,  73.08,  315.28,  66.21,'F260127'),
  (2026,  3,'4B_ALEX',  9, 12.00, 196.80, 16.20,  93.96,  306.96,  64.46,'F260127'),
  (2026,  3,'3G_MARE',  9, 12.17, 199.59, 16.20,  93.96,  309.75,  65.05,'F260127'),
  (2026,  4,'1A_NICA',  7, 14.25, 233.70, 12.60,  73.08,  319.38,  67.07,'F260156'),
  (2026,  4,'4B_ALEX',  9, 13.50, 221.40, 16.20, 103.76,  341.36,  71.69,'F260156'),
  (2026,  4,'3G_MARE', 10, 16.00, 262.40, 18.00, 104.40,  384.80,  80.81,'F260156'),
  (2026,  5,'1A_NICA',  7, 14.00, 229.60, 12.60,  92.68,  334.88,  70.32,'F260201'),
  (2026,  5,'4B_ALEX', 11, 15.00, 246.00, 19.80, 163.84,  429.64,  90.22,'F260201'),
  (2026,  5,'3G_MARE',  7, 10.50, 172.20, 12.60,  73.08,  257.88,  54.15,'F260201'),
  (2026,  6,'1A_NICA',  8, 16.00, 262.40, 14.40,  83.52,  360.32,  75.67,'F260506'),
  (2026,  6,'4B_ALEX',  9, 13.00, 213.20, 16.20, 122.36,  351.76,  73.87,'F260506'),
  (2026,  6,'3G_MARE',  7, 10.50, 172.20, 12.60,  73.08,  257.88,  54.15,'F260506')
on conflict (anio, mes, codigo) do nothing;

-- ── LA VISTA: real cuando hay factura, estimado cuando no ───────────────────────
-- Un solo sitio decide qué coste de limpieza usa el motor, para YTD y para forward.
-- Jacobine (Sevilla) no la limpia Ecocleans: siempre cae al estimado, y así queda etiquetado.
create or replace view v_limpieza_mensual as
select
  s.codigo, s.anio, s.mes,
  case when lm.codigo is not null
       then -(lm.base_eur + lm.iva_eur)
       else -(l.limpieza_por_reserva * coalesce(b.reservas, 0)) end as coste,
  case when lm.codigo is null      then 'estimado'
       when lm.fiable              then 'real'
       else                             'real_revisar' end          as fuente,
  lm.servicios, lm.horas, lm.factura
from v_month_spine s
join listings l                on l.codigo = s.codigo
left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
left join limpieza_mensual lm  on lm.codigo = s.codigo and lm.anio = s.anio and lm.mes = s.mes;

grant select on v_limpieza_mensual to anon, authenticated;

-- ── EL MOTOR CONSUME LA VISTA ───────────────────────────────────────────────────
-- Único cambio de fondo: `limpieza` sale de v_limpieza_mensual. Se añade `limpieza_fuente`
-- al final (create or replace solo permite añadir columnas, nunca reordenar ni quitar).
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
    ((case when l.modelo='subarriendo' then -l.renta_base else 0 end) + coalesce(ev.ev_renta,0)) as renta_transfer,
    (l.renta_factura_desde is not null
      and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde)::date) as con_factura,
    l.renta_iva_pct, l.renta_retencion_pct,
    lp.coste                                                                                as limpieza,
    lp.fuente                                                                               as limpieza_fuente,
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                    as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_month_spine s
  join listings l                     on l.codigo = s.codigo
  join v_limpieza_mensual lp          on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
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
  limpieza_fuente
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
    (-l.suministros_mes + coalesce(ev.ev_suministros,0))                                    as suministros,
    -l.comunidad_ibi_mes                                                                    as comunidad,
    (-(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
       + coalesce(ev.ev_otros,0))                                                           as otros
  from v_forward_spine s
  join listings l                     on l.codigo = s.codigo
  left join v_limpieza_mensual lp     on lp.codigo=s.codigo and lp.anio=s.anio and lp.mes=s.mes
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
