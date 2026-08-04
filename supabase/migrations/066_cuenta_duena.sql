-- 066_cuenta_duena.sql — la cuenta corriente de la dueña de JACO, digitalizada (04/08/2026).
--
-- Pedido de Stag: ver dentro de la ficha de Jacobine cuánto dinero le pertenece a la
-- dueña en el año, y qué se le descuenta: la refactura de limpieza (700 €/mes) y los
-- gastos que Samavi adelanta y repercute (recobros de la 065: mini UPS, aspiradora,
-- bizums de Agustín cuando se liquiden).
--
-- SEMÁNTICA (etiquetada así en el UI — no confundir capas):
--   · Es la cuenta DEVENGADA del período: lo que le corresponde por las noches dormidas
--     (mismo prorrateo devengo/noche del motor) menos lo que se le descuenta. NO resta
--     las transferencias que Stag ya le hizo — los pagos viven en los bancos, no acá.
--   · pasivo_alquiler = pasivo_madre de la 033 prorrateado por noche:
--     host_payout − (host_payout + host_service_fee) × 30,25 %. La comisión se calcula
--     sobre la base con comisión de canal incluida (config Guesty verificada), o sea que
--     la comisión de canal la asume la dueña; el IVA va dentro del 30,25 (021).
--   · pasivo_cancelaciones = su parte de los cobros retenidos de canceladas (misma base
--     y mes de check-in que v_ingreso_cancelaciones, 047).
--   · limpieza = listings.refactura_limpieza_mes (columna nueva; 700 en JACO — el neto
--     Samavi vs nómina de José ya está en events "Modesto neto", capa Samavi, NO acá).
--   · descuentos = recobros LIQUIDADOS por mes de resolución (los PENDIENTES no bajan
--     la cuenta hasta que se liquidan; el UI los muestra aparte).
--   · listings.pasivo_base (20.985,83 en JACO) = saldo acumulado pre-2026 según el
--     Excel, SIN verificar contra banco: queda como referencia y NO se suma — 2025 y
--     antes vive en el proyecto de Admin & Fiscal (regla de la 049).

-- ── 1) La refactura de limpieza como parámetro del motor, no número mágico ─────────
alter table listings add column if not exists refactura_limpieza_mes numeric(12,2) not null default 0;
update listings set refactura_limpieza_mes = 700.00 where codigo = '1A_JACO';

-- ── 2) f_cuenta_duena(desde, hasta) — mensual, solo propiedades en modelo comisión ──
create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (
  codigo               text,
  anio                 int,
  mes                  int,
  pasivo_alquiler      numeric,   -- + le pertenece por las noches del mes
  pasivo_cancelaciones numeric,   -- + su parte de cobros retenidos de canceladas
  limpieza             numeric,   -- − refactura de limpieza del mes
  descuentos           numeric,   -- − recobros liquidados en el mes
  neto                 numeric    -- = a su favor en el mes (devengado)
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
    -- misma población y mes (check-in) que v_ingreso_cancelaciones (047)
    select r.codigo,
           extract(year  from r.checkin_local)::int as anio,
           extract(month from r.checkin_local)::int as mes,
           sum(coalesce(r.host_payout, 0)
               - (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0)) * l.comision_pct) as pasivo
      from reservations r
      join listings l on l.codigo = r.codigo
     where l.modelo = 'comision'
       and r.status = 'canceled'
       and coalesce(r.host_payout, 0) <> 0
       and r.checkin_local is not null
       and r.checkin_local between p_desde and p_hasta
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

-- Wrapper "año en curso", mismo rango que los demás wrappers de la 060.
create or replace view v_cuenta_duena as
  select * from f_cuenta_duena(date_trunc('year', now())::date, now()::date);

-- ── 3) Candado (056/059/061): authenticated SOLO, jamás anon ───────────────────────
-- El revoke de public/anon es OBLIGATORIO (ver 065/063/064): el default de Postgres da
-- EXECUTE a PUBLIC en cada función nueva y el candado 061 se suma a él, no lo anula.
revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
grant select on v_cuenta_duena to authenticated;
