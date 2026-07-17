-- 008_lockdown_vistas.sql — cerrar la fuga de las vistas internas del motor (hallazgo crítico
-- de la revisión adversarial, 16/07/2026).
--
-- Problema: los default privileges de Supabase auto-otorgan SELECT a anon/authenticated sobre
-- CADA vista nueva de public, anulando el modelo whitelist declarado en 002_rls.sql. Resultado
-- verificado en producción: v_reservation_income respondía a la anon key con host_payout y
-- pasivo_madre por reserva (515 filas) — exactamente lo que 002 promete que nunca viaja al front.
--
-- Fix: revocar las vistas internas y dejar GRANT explícito solo en las vistas del dashboard.
-- v_reservation_nights queda expuesta A PROPÓSITO (§3 de la spec: grano noche para heatmap,
-- MTD del titular y lista de reservas; sin PII) — hasta ahora funcionaba solo por el default.
-- ⚠ Regla operativa a futuro: toda vista nueva nace pública por el default privilege → si no
-- va al dashboard, revocarla en la misma migración que la crea.

revoke select on
  v_reservation_income,
  v_nights_monthly,
  v_bookings_monthly,
  v_month_spine,
  v_samavi_gen_mensual
from anon, authenticated;

grant select on v_reservation_nights to anon, authenticated;

-- Fix menor (hallazgo de la misma revisión): singular del countdown embebido en el mensaje.
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
    || case when (aviso_fecha - current_date) = 0 then ' (vence hoy)'
            when (aviso_fecha - current_date) = 1 then ' (falta 1 día)'
            else ' (faltan ' || (aviso_fecha - current_date) || ' días)' end as mensaje,
  'alerta'::text as clase,
  aviso_fecha    as fecha_limite,
  (aviso_fecha - current_date) as dias_restantes
from listings
where aviso_fecha is not null
  and aviso_fecha >= current_date
  and (aviso_fecha - current_date) <= 90;

grant select on v_alertas to anon, authenticated;
