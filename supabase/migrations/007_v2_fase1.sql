-- 007_v2_fase1.sql — SQL de la Fase 1 del Dashboard CEO v2 (flujo portada → alerta → ficha ALEX → simulador).
--   1) v_propiedades: parámetros NO sensibles por propiedad. El simulador necesita modelo /
--      renta_base / comision_pct y hoy ninguna vista los expone; propietario, NIF e IBAN quedan fuera.
--   2) v_alertas v2: columnas estructuradas al final (clase, fecha_limite, dias_restantes) para
--      countdown y cascada del titular. Las 4 primeras columnas no cambian: el front v1 sigue vivo
--      entre la migración y el deploy.
--   3) v_freshness: honestidad del dato — last_sync + hasta qué mes hay costes manuales cargados
--      (los events están precargados hacia adelante; max(mes) dice hasta dónde llega la proyección).

-- 1) Parámetros por propiedad (sin datos personales) ───────────────────────────
create or replace view v_propiedades as
select codigo, modelo, fecha_inicio, renta_base, comision_pct, aviso_fecha, aviso_nota
from listings;

-- 2) v_alertas v2 — alerta = tiene fecha límite; señal = condición persistente sin fecha ──
create or replace view v_alertas as
select
  'breakeven'::text as tipo,
  codigo,
  case when colchon < 0 then 'critical' else 'warning' end as severidad,
  case when colchon < 0
       then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
       else 'Colchón ajustado: solo ' || translate(to_char(colchon*100, 'FM990.0'), '.', ',')
            || ' pp por encima del equilibrio ('
            || translate(to_char(ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
  end as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_breakeven_ytd
where colchon is not null and colchon < 0.10

union all

select
  'mes_negativo'::text as tipo,
  codigo,
  'warning' as severidad,
  count(*) || ' mes(es) con margen neto negativo este año' as mensaje,
  'senal'::text as clase,
  null::date    as fecha_limite,
  null::int     as dias_restantes
from v_pnl_neto_propiedad
where anio = extract(year from now())::int and margen_neto < 0
group by codigo

union all

select
  'contrato'::text as tipo,
  codigo,
  case when (aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end as severidad,
  coalesce(aviso_nota, 'Aviso de contrato') || ' — fecha límite '
    || to_char(aviso_fecha, 'DD/MM/YYYY')
    || ' (faltan ' || (aviso_fecha - current_date) || ' días)' as mensaje,
  'alerta'::text as clase,
  aviso_fecha    as fecha_limite,
  (aviso_fecha - current_date) as dias_restantes
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

-- 3) Frescura del dato ─────────────────────────────────────────────────────────
create or replace view v_freshness as
select
  (select last_run from sync_state where id = 1)          as last_sync,
  (select max(make_date(anio, mes, 1)) from events)       as costes_cargados_hasta;

grant select on v_propiedades, v_freshness to anon, authenticated;
grant select on v_alertas to anon, authenticated;
