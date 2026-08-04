-- 071_cuenta_duena_2025.sql — la cuenta de la dueña arranca en 2025 (05/08/2026).
--
-- Stag llevaba esta cuenta a mano en la pestaña 2025_JACOBINE_MADRE_INGRESOS del Sheets
-- "STAG PROPERTIES MGMT — INGRESOS Y FINANZAS" (Drive 1qq89woZ9fMEXLUYGGUHiXPa_H8NbKeob).
-- Su planilla cerraba 2025 con 9.834,67 € a favor de la dueña. Verificado contra Guesty
-- reserva por reserva: las NOCHES coinciden los 7 meses (6/24/25/28/29/28/17) y 4 de 7
-- meses cuadran al céntimo en importe.
--
-- Las tres diferencias, identificadas una por una:
--   · 415,60 € — reserva HMJFKCR9FX (30/07→02/08/2025). La planilla la puso en agosto
--     (criterio del reporte de Airbnb); Guesty la tiene con check-in en julio. NO es un
--     error: es criterio, y se disuelve al imputar por noche.
--   · 1.183,33 € — reserva HM28X3ZTRT (30/12/2025→08/01/2026, 9 noches, bruto 2.948,50).
--     La planilla la contó entera en diciembre 2025; por noche son 2 noches de 2025 y 7
--     de 2026.
--   · 248,97 € de bruto (200,00 en agosto + 48,97 en septiembre) SIN respaldo en Guesty:
--     no hay reservas directas ni canceladas que los expliquen (comprobado: las canceladas
--     de 2025 tienen todas bruto y cobrado 0). Son ajustes manuales de la planilla.
--     Efecto sobre la dueña: 173,66 € acreditados de más.
--
-- Reconciliación exacta:
--   9.834,67 (planilla) − 173,66 (ajustes sin respaldo) − 1.183,33 (noches de 2026)
--   = 8.477,68 € — que es justo lo que arroja este motor. Cierra al céntimo.
--
-- Decisiones de Stag (05/08/2026): imputar POR NOCHE DORMIDA (mismo criterio que todo el
-- dashboard) y acreditarle su parte de las cancelaciones retenidas también en 2025 — en
-- 2025 no hubo ninguna cobrada, así que esa regla no mueve ese año.
--
-- 2025 NO se puede modelar con la refactura fija de 700 €/mes: ese importe se fijó en
-- noviembre de 2025; antes la limpieza se le pasaba a coste real y variaba mes a mes.

-- ── 1) Limpieza mensual real (sobreescribe la cuota fija de listings) ──────────────
create table if not exists duena_limpieza (
  propiedad_codigo text not null references listings(codigo),
  anio             int  not null,
  mes              int  not null check (mes between 1 and 12),
  importe          numeric(12,2) not null check (importe >= 0),
  nota             text,
  primary key (propiedad_codigo, anio, mes)
);
alter table duena_limpieza enable row level security;  -- sin policies: solo vía función

insert into duena_limpieza (propiedad_codigo, anio, mes, importe, nota) values
  ('1A_JACO', 2025,  6, 299.48, 'Coste real de limpieza (planilla 2025). Aun sin cuota fija.'),
  ('1A_JACO', 2025,  7, 592.90, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025,  8, 508.20, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025,  9, 707.85, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025, 10, 592.90, 'Coste real de limpieza (planilla 2025).'),
  ('1A_JACO', 2025, 11, 700.00, 'Desde noviembre 2025 se fija la cuota mensual de 700 (nomina de Jose Modesto).'),
  ('1A_JACO', 2025, 12, 700.00, 'Cuota fija de 700.')
on conflict (propiedad_codigo, anio, mes) do nothing;

-- ── 2) Gastos 2025 repercutidos, como recobros ya liquidados ──────────────────────
-- Van a `recobros`, no a events: son plata que Samavi adelantó y le descontó a la dueña,
-- o sea neutros para el P&L — el mismo criterio que el mini UPS y la aspiradora de 2026.
insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, 'SAMAVI', v.pagado_a, v.medio,
       'LIQUIDADO', v.resuelto, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2025-05-31', 'Puesta a punto del piso (gastos de arranque)', 272.25,
   null::text, null::text, date '2025-06-30',
   'Descontado en la cuenta de la dueña: columna LIMPIEZA de abril-mayo 2025, nota "Gastos de arranque".',
   'La planilla lo anota en abril-mayo, antes de la primera reserva (JACO arranca el 01/06/2025), asi que en la cuenta cae en junio, el primer mes con actividad.'),
  ('1A_JACO', date '2025-07-31', 'Cortinas', 2044.00,
   'SOOFA', 'transferencia', date '2025-07-31',
   'Descontado en la cuenta de la dueña: columna GASTOS de julio 2025, nota "Cortinas".',
   'Gasto de equipamiento repercutido integro a la dueña.'),
  ('1A_JACO', date '2025-11-30', 'Reparación lavadora y puerta corredera del baño', 83.00,
   null, null, date '2025-11-30',
   'Descontado en la cuenta de la dueña: columna GASTOS de noviembre 2025.',
   'Nota de la planilla: "Lavadora perdida de agua, Reparacion puerta corrediza bano secundario".'),
  ('1A_JACO', date '2025-12-31', 'Equipamiento varios (wifi, calefactores, toalleros, CEE, nota simple)', 409.14,
   null, null, date '2025-12-31',
   'Descontado en la cuenta de la dueña: columna GASTOS de diciembre 2025.',
   'Nota de la planilla: "Wifi, ZH Vela, Calefactores, Wifi repetidor, Toalleros, Soporte papel higenico, CEE, Nota Simple Registro de la propiedad".')
) as v(cod, fecha, concepto, importe, pagado_a, medio, resuelto, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);

-- ── 3) El motor usa la limpieza real cuando existe; si no, la cuota fija ───────────
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
         -- la limpieza real del mes manda; si no hay fila, la cuota fija de listings
         -coalesce(dl.importe, l.refactura_limpieza_mes)             as limpieza,
         -round(coalesce(q.descuentos, 0)::numeric, 2)               as descuentos,
         round((coalesce(n.pasivo, 0) + coalesce(c.pasivo, 0)
                - coalesce(dl.importe, l.refactura_limpieza_mes)
                - coalesce(q.descuentos, 0))::numeric, 2)            as neto
    from f_spine(p_desde, p_hasta) s
    join listings l on l.codigo = s.codigo
    left join duena_limpieza dl
           on dl.propiedad_codigo = s.codigo and dl.anio = s.anio and dl.mes = s.mes
    left join noches n on n.codigo = s.codigo and n.anio = s.anio and n.mes = s.mes
    left join canc   c on c.codigo = s.codigo and c.anio = s.anio and c.mes = s.mes
    left join liq    q on q.codigo = s.codigo and q.anio = s.anio and q.mes = s.mes
   where l.modelo = 'comision'
   order by s.codigo, s.anio, s.mes
$$;

-- ── 4) La vista deja de ser "año en curso": la cuenta es acumulativa desde el inicio ──
-- f_spine ya recorta por listings.fecha_inicio, así que arrancar en 2024 no inventa meses.
create or replace view v_cuenta_duena as
  select * from f_cuenta_duena(date '2024-01-01', (now() at time zone 'Europe/Madrid')::date);

revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
grant  select on v_cuenta_duena to authenticated;

-- Resultado verificado en producción: 2025 = 8.477,68 € · 2026 (ene-jul) = 18.878,59 €
-- Total adeudado a la dueña, sin descontar pagos (no se le transfirió nada): 27.356,27 €
