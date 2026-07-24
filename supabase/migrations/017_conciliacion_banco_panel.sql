-- 017 — v_cuadre_banco: conciliación bancaria para el panel de /cuadre (Fase 3).
-- Por cuenta (7165 Revolut = Nica+Jaco · 8920 BBVA = Alex+Mare) y mes:
--   airbnb_pago  = lo que Airbnb pagó (desde Guesty, v_conciliacion_airbnb; = el PDF).
--   banco_recibio = depósitos de Airbnb que entraron (bank_deposits).
--   diferencia_acum = acumulado banco − airbnb → el "en tránsito" neto; debe quedarse chico.
-- Restringida al PERÍODO con extractos cargados (para que el acumulado no se contamine con
-- meses sin banco). Vista de panel (agregada, sin PII ni IBAN completo) → GRANT anon.

create or replace view v_cuadre_banco as
with rango as (
  select date_trunc('month', min(fecha))::date as desde,
         date_trunc('month', max(fecha))::date as hasta
  from bank_deposits where es_airbnb
),
airbnb as (
  select case when codigo in ('1A_NICA','1A_JACO') then '7165' else '8920' end as iban,
         anio, mes, sum(payout_total_airbnb) as airbnb_pago
  from v_conciliacion_airbnb
  where make_date(anio, mes, 1) between (select desde from rango) and (select hasta from rango)
  group by 1, anio, mes
),
banco as (
  select iban,
         extract(year  from fecha)::int as anio,
         extract(month from fecha)::int as mes,
         sum(importe) as banco_recibio, count(*) as depositos
  from bank_deposits
  where es_airbnb
  group by iban, extract(year from fecha)::int, extract(month from fecha)::int
),
j as (
  select coalesce(a.iban, b.iban) as iban,
         coalesce(a.anio, b.anio) as anio,
         coalesce(a.mes,  b.mes)  as mes,
         round(coalesce(a.airbnb_pago, 0), 2)   as airbnb_pago,
         round(coalesce(b.banco_recibio, 0), 2) as banco_recibio,
         coalesce(b.depositos, 0) as depositos
  from airbnb a
  full outer join banco b on a.iban = b.iban and a.anio = b.anio and a.mes = b.mes
)
select
  iban,
  case iban when '7165' then 'Revolut · Nicasio + Jacobine'
            when '8920' then 'BBVA · Alexander + Marechal'
            else iban end as cuenta,
  anio, mes, airbnb_pago, banco_recibio, depositos,
  round(banco_recibio - airbnb_pago, 2) as diferencia_mes,
  round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2) as diferencia_acum
from j
order by iban, anio, mes;

grant select on v_cuadre_banco to anon, authenticated;
