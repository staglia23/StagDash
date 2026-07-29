-- 060 — parametrización del período: el motor aprende "desde–hasta" (spec §5.2 y §8.2).
--
-- Hasta hoy el año en curso estaba grabado en la cadena de vistas: v_month_spine generaba
-- los meses "de enero a hoy" con now() adentro, y todo lo que cuelga de ella (días de
-- gestión, overhead, limpieza, suministros, P&L mensual) más 4 filtros now() propios
-- (ranking, costes, breakeven, canal) heredaban ese pin. Preguntarle al motor "¿y en
-- marzo?" no tenía dónde escribirse.
--
-- Diseño (el de la spec): funciones f_*(p_desde, p_hasta) con EXACTAMENTE la misma
-- aritmética que las vistas — mismo prorrateo de overhead por días bajo gestión sobre el
-- período completo, mismos casts, mismos round() — y las vistas actuales redefinidas como
-- WRAPPERS que llaman a su función con (1 de enero, hoy). El front no cambia ni un número
-- (verificado contra foto previa: las 10 vistas idénticas fila a fila). El motor sigue
-- viviendo en UN lugar: ahora son las funciones; las vistas son alias del caso "YTD".
--
-- Semántica del rango: MES COMPLETO. p_desde/p_hasta se truncan a su mes (el motor imputa
-- por mes; "hasta hoy" siempre incluyó el mes corriente entero como disponible). Rangos
-- invertidos devuelven 0 filas sin error. Rangos futuros devuelven costes con el fallback
-- "estimado" de siempre e ingreso on-the-books (el UI actual no los usa). Rangos pre-2026
-- devuelven ingreso/noches reales pero costes estimados: los costes reales solo están
-- cargados desde ene-2026 — el YoY de margen sigue vetado (spec §5.5), esto NO lo habilita.
--
-- Seguridad (doctrina 056/059): funciones SECURITY DEFINER (leen tablas crudas que
-- authenticated no ve) con search_path fijado; EXECUTE revocado de PUBLIC/anon en TODAS
-- y concedido a authenticated en TODAS (ver la lección al pie, en los GRANTs). La
-- superficie RPC pensada para el front son las 4 de la spec (f_ranking, f_costes,
-- f_breakeven, f_canal); las demás quedan ejecutables por necesidad técnica, no de uso.

-- ── 1) f_spine: el generador de meses por propiedad, ahora con rango ─────────────────
create or replace function f_spine(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer)
language sql stable
security definer set search_path = public
as $$
  select l.codigo,
         extract(year from gs.gs)::integer,
         extract(month from gs.gs)::integer
    from listings l
    cross join lateral generate_series(
      greatest(date_trunc('month', l.fecha_inicio::timestamptz),
               date_trunc('month', p_desde::timestamptz)),
      date_trunc('month', p_hasta::timestamptz),
      interval '1 mon') gs(gs)
$$;

-- ── 2) f_dias_gestion ────────────────────────────────────────────────────────────────
create or replace function f_dias_gestion(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, dias integer)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes, dias_gestion(l.fecha_inicio, s.anio, s.mes)
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
$$;

-- ── 3) f_samavi_gen_mensual: pool de overhead/corporativo por mes del rango ──────────
create or replace function f_samavi_gen_mensual(p_desde date, p_hasta date)
returns table(anio integer, mes integer, overhead numeric, corporativo numeric)
language sql stable
security definer set search_path = public
as $$
  select m.anio, m.mes,
         (select coalesce(sum(g.importe_mes), 0)
            from general_expenses g
           where not g.es_corporativo
             and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde::timestamptz)::date)
             and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
         - coalesce((select sum(e.importe) from events e
                      where e.categoria = 'SAMAVI_GEN' and e.anio = m.anio and e.mes = m.mes), 0)
           as overhead,
         (select coalesce(sum(g.importe_mes), 0)
            from general_expenses g
           where g.es_corporativo
             and (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde::timestamptz)::date)
             and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
         - coalesce((select sum(e.importe) from events e
                      where e.categoria = 'CORPORATIVO' and e.anio = m.anio and e.mes = m.mes), 0)
           as corporativo
    from (select distinct s.anio, s.mes from f_spine(p_desde, p_hasta) s) m
$$;

-- ── 4) f_limpieza_mensual: real si hay factura, estimado si no ───────────────────────
create or replace function f_limpieza_mensual(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, coste numeric, fuente text,
              servicios integer, horas numeric, factura text)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes,
         case when lm.codigo is not null then -(lm.base_eur + lm.iva_eur)
              else -(l.limpieza_por_reserva * coalesce(b.reservas, 0::bigint)::numeric) end,
         case when lm.codigo is null then 'estimado'
              when lm.fiable then 'real'
              else 'real_revisar' end,
         lm.servicios, lm.horas, lm.factura
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
    left join limpieza_mensual lm on lm.codigo = s.codigo and lm.anio = s.anio and lm.mes = s.mes
$$;

-- ── 5) f_suministros_mensual ─────────────────────────────────────────────────────────
create or replace function f_suministros_mensual(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, coste numeric, fuente text,
              luz_eur numeric, internet_eur numeric, nota text)
language sql stable
security definer set search_path = public
as $$
  select s.codigo, s.anio, s.mes,
         case when sm.codigo is not null then -sm.total_eur
              else -l.suministros_mes end,
         case when sm.codigo is null then 'estimado'
              when sm.fiable then 'real'
              else 'real_revisar' end,
         sm.luz_eur, sm.internet_eur, sm.nota
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join suministros_mensual sm on sm.codigo = s.codigo and sm.anio = s.anio and sm.mes = s.mes
$$;

-- ── 6) f_pnl_mensual_propiedad: el P&L mensual completo, por rango ───────────────────
create or replace function f_pnl_mensual_propiedad(p_desde date, p_hasta date)
returns table(codigo text, anio integer, mes integer, dias_mes integer, bruto numeric,
              ingreso_samavi numeric, comision_aparente numeric, noches bigint,
              reservas bigint, ocup_pct numeric, adr numeric, revpar numeric, alos numeric,
              renta numeric, limpieza numeric, suministros numeric, comunidad numeric,
              otros numeric, total_gastos_directos numeric, margen_directo numeric,
              ingreso_noches numeric, ingreso_cancelaciones numeric, iva_repercutido numeric,
              renta_iva numeric, limpieza_fuente text, comision_canal numeric,
              comision_canal_samavi numeric, suministros_fuente text)
language sql stable
security definer set search_path = public
as $$
  with ev as (
    select e.propiedad_codigo as codigo, e.anio, e.mes,
           coalesce(sum(e.importe) filter (where e.categoria = 'RENTA'), 0)       as ev_renta,
           coalesce(sum(e.importe) filter (where e.categoria = 'OTROS'), 0)       as ev_otros,
           coalesce(sum(e.importe) filter (where e.categoria = 'SUMINISTROS'), 0) as ev_suministros
      from events e
     group by e.propiedad_codigo, e.anio, e.mes
  ), base as (
    select s.codigo, s.anio, s.mes,
           days_in_month(s.anio, s.mes)                       as dias_mes,
           coalesce(n.bruto, 0)                               as bruto,
           coalesce(n.ingreso_samavi, 0)                      as ingreso_noches,
           coalesce(c.ingreso_cancelaciones, 0)               as ingreso_cancelaciones,
           coalesce(n.noches, 0::bigint)                      as noches,
           coalesce(b.reservas, 0::bigint)                    as reservas,
           coalesce(n.iva_repercutido, 0) + coalesce(c.iva_cancelaciones, 0) as iva_repercutido,
           coalesce(n.comision_canal, 0)                      as comision_canal,
           coalesce(n.comision_canal_samavi, 0)               as comision_canal_samavi,
           case when l.modelo = 'subarriendo' then -l.renta_base else 0 end
             + coalesce(ev.ev_renta, 0)                       as renta_transfer,
           l.renta_factura_desde is not null
             and make_date(s.anio, s.mes, 1) >= date_trunc('month', l.renta_factura_desde::timestamptz)::date
                                                              as con_factura,
           l.renta_iva_pct, l.renta_retencion_pct,
           lp.coste                                           as limpieza,
           lp.fuente                                          as limpieza_fuente,
           sp.coste + coalesce(ev.ev_suministros, 0)          as suministros,
           sp.fuente                                          as suministros_fuente,
           -l.comunidad_ibi_mes                               as comunidad,
           -(l.minut + l.akiles + l.amenities + l.pricelabs + l.guesty_fee + l.extras)
             + coalesce(ev.ev_otros, 0)                       as otros
      from f_spine(p_desde, p_hasta) s
      join listings l on l.codigo = s.codigo
      join f_limpieza_mensual(p_desde, p_hasta) lp
        on lp.codigo = s.codigo and lp.anio = s.anio and lp.mes = s.mes
      join f_suministros_mensual(p_desde, p_hasta) sp
        on sp.codigo = s.codigo and sp.anio = s.anio and sp.mes = s.mes
      left join v_nights_monthly n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
      left join v_bookings_monthly b on b.codigo = s.codigo and b.anio = s.anio and b.mes = s.mes
      left join v_ingreso_cancelaciones c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
      left join ev on ev.codigo = s.codigo and ev.anio = s.anio and ev.mes = s.mes
  ), conv as (
    select b.*,
           case when b.con_factura
                then (1 + b.renta_iva_pct) / (1 + b.renta_iva_pct - b.renta_retencion_pct)
                else 1 end as factor,
           case when b.con_factura
                then b.renta_iva_pct / (1 + b.renta_iva_pct - b.renta_retencion_pct)
                else 0 end as factor_iva
      from base b
  ), final as (
    select c.*,
           round(c.renta_transfer * c.factor, 2)     as renta,
           round(c.renta_transfer * c.factor_iva, 2) as renta_iva
      from conv c
  )
  select f.codigo, f.anio, f.mes, f.dias_mes, f.bruto,
         f.ingreso_noches + f.ingreso_cancelaciones            as ingreso_samavi,
         f.bruto - f.ingreso_noches                            as comision_aparente,
         f.noches, f.reservas,
         round(f.noches::numeric / f.dias_mes::numeric, 4)     as ocup_pct,
         case when f.noches > 0 then round(f.bruto / f.noches::numeric, 2) else 0 end as adr,
         round(f.bruto / f.dias_mes::numeric, 2)               as revpar,
         case when f.reservas > 0 then round(f.noches::numeric / f.reservas::numeric, 2) else 0 end as alos,
         f.renta, f.limpieza, f.suministros, f.comunidad, f.otros,
         f.renta + f.limpieza + f.suministros + f.comunidad + f.otros as total_gastos_directos,
         f.ingreso_noches + f.ingreso_cancelaciones
           + f.renta + f.limpieza + f.suministros + f.comunidad + f.otros as margen_directo,
         f.ingreso_noches, f.ingreso_cancelaciones, f.iva_repercutido, f.renta_iva,
         f.limpieza_fuente,
         round(f.comision_canal, 2)                            as comision_canal,
         round(f.comision_canal_samavi, 2)                     as comision_canal_samavi,
         f.suministros_fuente
    from final f
$$;

-- ── 7) f_ranking: la vista reina, por rango (overhead prorrateado por días del RANGO) ─
create or replace function f_ranking(p_desde date, p_hasta date)
returns table(codigo text, ingreso_samavi numeric, bruto numeric, noches numeric,
              reservas numeric, noches_disponibles bigint, gastos_directos numeric,
              margen_directo numeric, cuota_samavi_gen numeric, margen_neto numeric,
              margen_neto_pct numeric, eur_noche_neto numeric, ocup_pct numeric,
              adr numeric, revpar numeric, ingreso_cancelaciones numeric,
              iva_repercutido numeric, contribucion numeric, contribucion_pct numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.ingreso_samavi)         as ingreso_samavi,
           sum(p.bruto)                  as bruto,
           sum(p.noches)                 as noches,
           sum(p.reservas)               as reservas,
           sum(p.dias_mes)               as noches_disponibles,
           sum(p.total_gastos_directos)  as gastos_directos,
           sum(p.margen_directo)         as margen_directo,
           sum(p.ingreso_cancelaciones)  as ingreso_cancelaciones,
           sum(p.iva_repercutido)        as iva_repercutido
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  ), dias as (
    select d.codigo, sum(d.dias) as dias
      from f_dias_gestion(p_desde, p_hasta) d
     group by d.codigo
  ), oh as (
    select coalesce(sum(g.overhead), 0) as total
      from f_samavi_gen_mensual(p_desde, p_hasta) g
  ), td as (
    select coalesce(sum(dias.dias), 0::numeric) as t from dias
  )
  select y.codigo, y.ingreso_samavi, y.bruto, y.noches, y.reservas, y.noches_disponibles,
         y.gastos_directos, y.margen_directo,
         round(-(select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2)
           as cuota_samavi_gen,
         round(y.margen_directo
               - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2)
           as margen_neto,
         case when y.ingreso_samavi > 0
              then round((y.margen_directo
                          - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)))
                         / y.ingreso_samavi, 4)
              else 0 end as margen_neto_pct,
         case when y.noches > 0
              then round((y.margen_directo
                          - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)))
                         / y.noches, 2)
              else 0 end as eur_noche_neto,
         case when y.noches_disponibles > 0
              then round(y.noches / y.noches_disponibles::numeric, 4) else 0 end as ocup_pct,
         case when y.noches > 0 then round(y.bruto / y.noches, 2) else 0 end as adr,
         case when y.noches_disponibles > 0
              then round(y.bruto / y.noches_disponibles::numeric, 2) else 0 end as revpar,
         y.ingreso_cancelaciones,
         round(y.iva_repercutido, 2) as iva_repercutido,
         round(y.margen_directo, 2)  as contribucion,
         case when y.ingreso_samavi > 0
              then round(y.margen_directo / y.ingreso_samavi, 4) else 0 end as contribucion_pct
    from ytd y
    join dias d on d.codigo = y.codigo
   order by round(y.margen_directo
                  - (select oh.total from oh) * (d.dias::numeric / nullif((select td.t from td), 0)), 2) desc
$$;

-- ── 8) f_costes ──────────────────────────────────────────────────────────────────────
create or replace function f_costes(p_desde date, p_hasta date)
returns table(codigo text, renta numeric, limpieza numeric, suministros numeric,
              comunidad numeric, otros numeric, total_directos numeric, overhead numeric,
              total_costes numeric, pct_sobre_ingreso numeric, renta_iva numeric,
              comision_canal numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.renta)                 as renta,
           sum(p.limpieza)              as limpieza,
           sum(p.suministros)           as suministros,
           sum(p.comunidad)             as comunidad,
           sum(p.otros)                 as otros,
           sum(p.total_gastos_directos) as total_directos,
           sum(p.ingreso_samavi)        as ingreso,
           sum(p.renta_iva)             as renta_iva,
           sum(p.comision_canal_samavi) as comision_canal_samavi
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  )
  select y.codigo,
         round(-y.renta, 2), round(-y.limpieza, 2), round(-y.suministros, 2),
         round(-y.comunidad, 2), round(-y.otros, 2), round(-y.total_directos, 2),
         round(-r.cuota_samavi_gen, 2),
         round(-(y.total_directos + r.cuota_samavi_gen), 2),
         case when y.ingreso > 0
              then round((-(y.total_directos + r.cuota_samavi_gen)) / y.ingreso, 4)
              else 0 end,
         round(-y.renta_iva, 2),
         round(y.comision_canal_samavi, 2)
    from ytd y
    join f_ranking(p_desde, p_hasta) r on r.codigo = y.codigo
$$;

-- ── 9) f_breakeven ───────────────────────────────────────────────────────────────────
create or replace function f_breakeven(p_desde date, p_hasta date)
returns table(codigo text, costes_fijos numeric, contribucion_noche numeric,
              noches_necesarias integer, ocup_breakeven numeric, ocup_actual numeric,
              colchon numeric)
language sql stable
security definer set search_path = public
as $$
  with ytd as (
    select p.codigo,
           sum(p.ingreso_samavi) as ingreso,
           sum(p.noches)         as noches,
           sum(p.dias_mes)       as disponibles,
           sum(p.renta)          as renta,
           sum(p.limpieza)       as limpieza,
           sum(p.suministros)    as suministros,
           sum(p.comunidad)      as comunidad,
           sum(p.otros)          as otros
      from f_pnl_mensual_propiedad(p_desde, p_hasta) p
     group by p.codigo
  ), calc as (
    select y.codigo, y.noches, y.disponibles,
           (-(y.renta + y.suministros + y.comunidad + y.otros)) - r.cuota_samavi_gen as costes_fijos,
           case when y.noches > 0 then (y.ingreso + y.limpieza) / y.noches else 0 end as contrib_noche,
           case when y.disponibles > 0 then y.noches / y.disponibles::numeric else 0 end as ocup_actual
      from ytd y
      join f_ranking(p_desde, p_hasta) r on r.codigo = y.codigo
  )
  select c.codigo,
         round(c.costes_fijos, 2),
         round(c.contrib_noche, 2),
         case when c.contrib_noche > 0 then ceil(c.costes_fijos / c.contrib_noche)::integer
              else null end,
         case when c.contrib_noche > 0 and c.disponibles > 0
              then round(c.costes_fijos / c.contrib_noche / c.disponibles::numeric, 4)
              else null end,
         round(c.ocup_actual, 4),
         case when c.contrib_noche > 0 and c.disponibles > 0
              then round(c.ocup_actual - c.costes_fijos / c.contrib_noche / c.disponibles::numeric, 4)
              else null end
    from calc c
$$;

-- ── 10) f_canal (granularidad mes, como siempre tuvo v_canal_ytd) ────────────────────
create or replace function f_canal(p_desde date, p_hasta date)
returns table(codigo text, canal text, reservas bigint, ingreso numeric)
language sql stable
security definer set search_path = public
as $$
  select rn.codigo,
         coalesce(rn.source, 'directo/otro'),
         count(distinct rn.id),
         round(sum(rn.ingreso_samavi_night), 2)
    from v_reservation_nights rn
   where make_date(rn.anio, rn.mes, 1) >= date_trunc('month', p_desde::timestamptz)::date
     and make_date(rn.anio, rn.mes, 1) <= date_trunc('month', p_hasta::timestamptz)::date
   group by rn.codigo, coalesce(rn.source, 'directo/otro')
$$;

-- ── 11) Las vistas pasan a ser wrappers: el caso "año en curso" de cada función ──────
create or replace view v_month_spine as
  select * from f_spine(date_trunc('year', now())::date, now()::date);
create or replace view v_dias_gestion as
  select * from f_dias_gestion(date_trunc('year', now())::date, now()::date);
create or replace view v_samavi_gen_mensual as
  select * from f_samavi_gen_mensual(date_trunc('year', now())::date, now()::date);
-- Los casts de horas/luz_eur/internet_eur reponen la precisión original de la tabla
-- (numeric(8,2)/(10,2)): Postgres DESCARTA los typmod declarados en el returns table de
-- una función, y "create or replace view" exige calce exacto de tipo con la vista vieja.
create or replace view v_limpieza_mensual as
  select codigo, anio, mes, coste, fuente, servicios,
         horas::numeric(8,2) as horas, factura
    from f_limpieza_mensual(date_trunc('year', now())::date, now()::date);
create or replace view v_suministros_mensual as
  select codigo, anio, mes, coste, fuente,
         luz_eur::numeric(10,2) as luz_eur, internet_eur::numeric(10,2) as internet_eur, nota
    from f_suministros_mensual(date_trunc('year', now())::date, now()::date);
create or replace view v_pnl_mensual_propiedad as
  select * from f_pnl_mensual_propiedad(date_trunc('year', now())::date, now()::date);
create or replace view v_ranking_ytd as
  select * from f_ranking(date_trunc('year', now())::date, now()::date);
create or replace view v_costes_ytd as
  select * from f_costes(date_trunc('year', now())::date, now()::date);
create or replace view v_breakeven_ytd as
  select * from f_breakeven(date_trunc('year', now())::date, now()::date);
create or replace view v_canal_ytd as
  select * from f_canal(date_trunc('year', now())::date, now()::date);

-- ── 12) Permisos (regla 059: authenticated SOLO, nunca anon) ─────────────────────────
revoke execute on function
  f_spine(date, date), f_dias_gestion(date, date), f_samavi_gen_mensual(date, date),
  f_limpieza_mensual(date, date), f_suministros_mensual(date, date),
  f_pnl_mensual_propiedad(date, date), f_ranking(date, date), f_costes(date, date),
  f_breakeven(date, date), f_canal(date, date)
from public, anon, authenticated;

-- TODAS a authenticated, no solo las 4 de la spec — lección que costó una ventana sin
-- datos en el dashboard (30/07/2026; ~3 min entre migración y fix según schema_migrations,
-- ~10 de punta a punta con detección): Postgres comprueba el EXECUTE de una función llamada
-- dentro de una vista contra el USUARIO QUE CONSULTA, no contra el dueño de la vista
-- (al revés que las referencias a tablas/vistas). Con las internas sin GRANT, v_kpis →
-- v_samavi_gen_mensual (wrapper) → f_samavi_gen_mensual devolvía 42501 a authenticated
-- y readView caía al fallback. No expone nada nuevo (devuelven lo que las vistas ya
-- muestran); anon sigue sin poder ejecutar ninguna. REGLA: toda f_ nueva que toque una
-- vista necesita su GRANT a authenticated aunque sea "interna".
grant execute on function
  f_spine(date, date), f_dias_gestion(date, date), f_samavi_gen_mensual(date, date),
  f_limpieza_mensual(date, date), f_suministros_mensual(date, date),
  f_pnl_mensual_propiedad(date, date), f_ranking(date, date), f_costes(date, date),
  f_breakeven(date, date), f_canal(date, date)
to authenticated;
