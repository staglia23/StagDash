-- 067_cancelaciones_cuenta_duena.sql — la cuenta de la dueña hereda el filtro de la 047 (04/08/2026).
--
-- La revisión adversarial de la 066 lo demostró en producción: el CTE de cancelaciones
-- usaba el predicado pre-047 (`host_payout <> 0` a secas) y dejaba entrar la manual
-- cancelada fantasma de dic-2025 (GY con payout copiado 342,00 y cobrado 0,00): cualquier
-- rango por RPC que pisara dic-2025 le acreditaba a la dueña 238,55 € que nunca
-- existieron, y la PRÓXIMA manual cancelada de JACO con payout copiado contaminaría el
-- año en curso, divergiendo del P&L (que vía 047 no la reconoce).
--
-- Dos correcciones, solo en el CTE canc:
--   1) Predicado EXACTO de v_ingreso_cancelaciones (047): total_paid <> 0, o no-manual
--      con payout <> 0.
--   2) Atribución por MES de check-in (como el P&L agrupa), no por día: una retenida con
--      check-in más adelante dentro del mes en curso entraba al P&L (su mes está en el
--      spine) pero no a la cuenta — divergencia temporal entre capas.
-- Identidad verificada en las filas legítimas: parte dueña + ingreso Samavi + IVA =
-- host_payout retenido (ene: 210,68 + 103,28 + 21,69 = 335,65 ✓).

create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (
  codigo               text,
  anio                 int,
  mes                  int,
  pasivo_alquiler      numeric,
  pasivo_cancelaciones numeric,
  limpieza             numeric,
  descuentos           numeric,
  neto                 numeric
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  with noches as (
    select ri.codigo,
           extract(year  from g.d)::int as anio,
           extract(month from g.d)::int as mes,
           sum(ri.pasivo_madre / (ri.checkout_local - ri.checkin_local)) as pasivo
      from v_reservation_income ri,
           lateral generate_series(ri.checkin_local::timestamp,
                                   (ri.checkout_local - 1)::timestamp,
                                   interval '1 day') g(d)
     where ri.pasivo_madre <> 0
       and g.d::date between p_desde and p_hasta
     group by 1, 2, 3
  ),
  canc as (
    -- población y mes idénticos a v_ingreso_cancelaciones (047)
    select r.codigo,
           extract(year  from r.checkin_local)::int as anio,
           extract(month from r.checkin_local)::int as mes,
           sum(coalesce(r.host_payout, 0)
               - (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0)) * l.comision_pct) as pasivo
      from reservations r
      join listings l on l.codigo = r.codigo
     where l.modelo = 'comision'
       and r.status = 'canceled'
       and (coalesce(r.total_paid, 0) <> 0
            or (r.source <> 'manual' and coalesce(r.host_payout, 0) <> 0))
       and r.checkin_local is not null
       and date_trunc('month', r.checkin_local)
           between date_trunc('month', p_desde::timestamp) and date_trunc('month', p_hasta::timestamp)
     group by 1, 2, 3
  ),
  liq as (
    select rc.propiedad_codigo as codigo,
           extract(year  from rc.resuelto_fecha)::int as anio,
           extract(month from rc.resuelto_fecha)::int as mes,
           sum(rc.importe) as descuentos
      from recobros rc
     where rc.estado = 'LIQUIDADO'
       and rc.resuelto_fecha between p_desde and p_hasta
     group by 1, 2, 3
  )
  select s.codigo, s.anio, s.mes,
         round(coalesce(n.pasivo, 0)::numeric, 2)                    as pasivo_alquiler,
         round(coalesce(c.pasivo, 0)::numeric, 2)                    as pasivo_cancelaciones,
         -l.refactura_limpieza_mes                                   as limpieza,
         -round(coalesce(q.descuentos, 0)::numeric, 2)               as descuentos,
         round((coalesce(n.pasivo, 0) + coalesce(c.pasivo, 0)
                - l.refactura_limpieza_mes - coalesce(q.descuentos, 0))::numeric, 2) as neto
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join noches n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
    left join canc   c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
    left join liq    q on q.codigo = s.codigo and q.anio = s.anio and q.mes = s.mes
   where l.modelo = 'comision'
   order by s.codigo, s.anio, s.mes
$$;

-- create or replace conserva los grants, pero el repo no deja candados implícitos.
-- revoke de public/anon obligatorio (default cableado de Postgres, ver 068).
revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
