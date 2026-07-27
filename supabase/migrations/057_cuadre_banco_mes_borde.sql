-- 057 — el mes-borde fuera del "en tránsito" (decisión Stag 27/07/2026). Idempotente
-- (create or replace preserva grants; solo AGREGA columnas al final).
--
-- El primer mes de la ventana de extractos arrastra payouts de estancias ANTERIORES al
-- período (en Revolut, +2.656,55 de estancias de dic-2025 cobradas en enero): no es dinero
-- en tránsito y no converge nunca a 0. Ese colchón artificial hacía que el semáforo verde
-- (umbral 15 %) tardara en detectar un faltante real. Se agregan:
--   · mes_borde: true en el primer mes de la ventana de cada cuenta.
--   · diferencia_acum_ajustada: el acumulado SIN la diferencia del mes-borde — el
--     "en tránsito real desde el 2º mes", que es lo que el semáforo debe mirar.
-- Las columnas viejas quedan intactas (el detalle mensual las sigue mostrando).
create or replace view v_cuadre_banco as
with rango as (
  select date_trunc('month', min(fecha))::date as desde,
         date_trunc('month', max(fecha))::date as hasta
    from bank_deposits
   where es_airbnb
), airbnb as (
  select case when c.codigo in ('1A_NICA','1A_JACO') then '7165' else '8920' end as iban,
         c.anio, c.mes,
         sum(c.payout_total_airbnb) as airbnb_pago
    from v_conciliacion_airbnb c
   where make_date(c.anio, c.mes, 1) >= (select desde from rango)
     and make_date(c.anio, c.mes, 1) <= (select hasta from rango)
   group by 1, c.anio, c.mes
), banco as (
  select iban,
         extract(year from fecha)::int as anio,
         extract(month from fecha)::int as mes,
         sum(importe) as banco_recibio,
         count(*) as depositos
    from bank_deposits
   where es_airbnb
   group by iban, 2, 3
), j as (
  select coalesce(a.iban, b.iban) as iban,
         coalesce(a.anio, b.anio) as anio,
         coalesce(a.mes, b.mes) as mes,
         round(coalesce(a.airbnb_pago, 0), 2) as airbnb_pago,
         round(coalesce(b.banco_recibio, 0), 2) as banco_recibio,
         coalesce(b.depositos, 0) as depositos
    from airbnb a
    full join banco b on a.iban = b.iban and a.anio = b.anio and a.mes = b.mes
)
select iban,
       case iban
         when '7165' then 'Revolut · Nicasio + Jacobine'
         when '8920' then 'BBVA · Alexander + Marechal'
         else iban
       end as cuenta,
       anio, mes, airbnb_pago, banco_recibio, depositos,
       round(banco_recibio - airbnb_pago, 2) as diferencia_mes,
       round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2)
         as diferencia_acum,
       row_number() over (partition by iban order by anio, mes) = 1 as mes_borde,
       round(sum(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes)
             - first_value(banco_recibio - airbnb_pago) over (partition by iban order by anio, mes), 2)
         as diferencia_acum_ajustada
  from j
 order by iban, anio, mes;
