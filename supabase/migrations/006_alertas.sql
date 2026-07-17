-- 006_alertas.sql — alertas del dashboard (backfill: ya aplicada en producción el 15/07/2026,
-- se reconstruye aquí para que el repo refleje el estado real de la base).
--   · listings.aviso_fecha / aviso_nota: fecha límite dura por propiedad (contratos).
--   · v_alertas: colchón de break-even < 10 pp, meses en negativo, avisos de contrato ≤ 90 días.

alter table listings add column if not exists aviso_fecha date;
alter table listings add column if not exists aviso_nota  text;

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
  end as mensaje
from v_breakeven_ytd
where colchon is not null and colchon < 0.10

union all

select
  'mes_negativo'::text as tipo,
  codigo,
  'warning' as severidad,
  count(*) || ' mes(es) con margen neto negativo este año' as mensaje
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
    || ' (faltan ' || (aviso_fecha - current_date) || ' días)' as mensaje
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

grant select on v_alertas to anon, authenticated;
