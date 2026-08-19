-- 089_recobros_dos_carriles.sql — separar lo que se le descuenta a la dueña de lo que Stag
-- arregla con su madre mano a mano (19/08/2026).
--
-- Decisión de Stag: "todo lo que venga de mi cuenta personal me lo arreglo con mi madre en
-- efectivo o lo compensamos entre nosotros, somos familia; no hacemos tóxica la salud de la
-- empresa". Tiene razón y además cierra una fuga real: hasta hoy, un recobro pagado desde
-- SU bolsillo y marcado LIQUIDADO bajaba la deuda que SAMAVI tiene con la dueña — o sea que
-- la sociedad se quedaba el dinero que había puesto él, y quedaba debiéndoselo. Pasó con los
-- 83,00 de la 077 y Stag terminó dándolos por saldados: 83 € que perdió de verdad.
--
-- Desde acá, cada recobro declara POR DÓNDE se cobra:
--   · CUENTA_DUENA   → se le descuenta en su cuenta corriente con Samavi (v_cuenta_duena).
--                      El dinero salió de Samavi y vuelve a Samavi. Circuito cerrado.
--   · DIRECTO_FAMILIA→ lo arreglan Stag y su madre entre ellos (efectivo o compensación).
--                      NO toca la cuenta con Samavi ni el P&L: para la sociedad no existe.
--
-- El backfill NO se hace por `pagado_por`, sino por lo que REALMENTE pasó: los bizums de
-- oct-2025 (53 + 30) salieron del bolsillo de Stag pero se descontaron de verdad en la
-- cuenta de la dueña (el descuento de 83,00 de nov-2025, migración 077). Marcarlos DIRECTO
-- reescribiría la historia y subiría su cuenta 83 € sin motivo. Se quedan en CUENTA_DUENA.
-- Al carril nuevo pasan solo los tres PENDIENTES pagados desde la cuenta personal.

-- ── 1) La columna ─────────────────────────────────────────────────────────────────
alter table recobros
  add column if not exists liquidacion text not null default 'CUENTA_DUENA';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'recobros_liquidacion_valida') then
    alter table recobros add constraint recobros_liquidacion_valida
      check (liquidacion in ('CUENTA_DUENA', 'DIRECTO_FAMILIA'));
  end if;
end $$;

comment on column recobros.liquidacion is
  'Por dónde se cobra: CUENTA_DUENA (se le descuenta en su cuenta con Samavi) o DIRECTO_FAMILIA (lo arreglan Stag y su madre; Samavi ni entra ni sale).';

-- Los tres pendientes del bolsillo de Stag pasan al carril familiar.
update recobros
   set liquidacion = 'DIRECTO_FAMILIA'
 where pagado_por = 'STAG_PERSONAL'
   and estado = 'PENDIENTE';

-- ── 2) La cuenta de la dueña solo resta lo de SU carril ───────────────────────────
-- Único cambio frente a la 066/067/071: el filtro `liquidacion = 'CUENTA_DUENA'` en `liq`.
-- Verificado antes y después: los totales no se mueven un céntimo (los 8 LIQUIDADOS
-- históricos son todos de ese carril), así que esto no reescribe nada del pasado.
create or replace function f_cuenta_duena(p_desde date, p_hasta date)
returns table (codigo text, anio int, mes int, pasivo_alquiler numeric,
               pasivo_cancelaciones numeric, limpieza numeric, descuentos numeric, neto numeric)
language sql stable
security definer set search_path = public, pg_temp
as $function$
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
       and rc.liquidacion = 'CUENTA_DUENA'   -- 089: el carril familiar no toca esta cuenta
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
$function$;

-- ── 3) El detalle expone el carril ────────────────────────────────────────────────
-- Cambia la firma del returns table → hay que tirar vista y función y recrearlas.
drop view     if exists v_recobros;
drop function if exists f_recobros(date, date);

create function f_recobros(p_desde date, p_hasta date)
returns table (
  id               bigint,
  propiedad_codigo text,
  fecha            date,
  concepto         text,
  importe          numeric,
  pagado_por       text,
  pagado_a         text,
  medio            text,
  estado           text,
  liquidacion      text,
  resuelto_fecha   date,
  resuelto_nota    text,
  dias_pendiente   int
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select r.id, r.propiedad_codigo, r.fecha, r.concepto, r.importe,
         r.pagado_por, r.pagado_a, r.medio, r.estado, r.liquidacion,
         r.resuelto_fecha, r.resuelto_nota,
         case when r.estado = 'PENDIENTE'
              then (current_date - r.fecha)::int end as dias_pendiente
    from recobros r
   where r.fecha between p_desde and p_hasta
   order by r.fecha desc, r.id desc;
$$;

create view v_recobros as
  select * from f_recobros(date '2024-01-01', date '2099-12-31');

-- ── 4) El agregado, partido por carril ────────────────────────────────────────────
-- Columnas nuevas AL FINAL: así `create or replace view` las admite sin tirar la vista.
-- `total` sigue siendo el total de los dos carriles (lo que le debe a alguien), y
-- `total_cuenta` es el único que la ficha puede anunciar como "por descontarle".
create or replace view v_recobros_pendientes as
select r.propiedad_codigo,
       count(*)::int                        as pagos,
       sum(r.importe)::numeric(12,2)        as total,
       min(r.fecha)                         as mas_viejo_fecha,
       (current_date - min(r.fecha))::int   as mas_viejo_dias,
       coalesce(sum(r.importe) filter (where r.pagado_por = 'STAG_PERSONAL'), 0)::numeric(12,2)
                                            as de_cuenta_personal,
       count(*) filter (where r.liquidacion = 'CUENTA_DUENA')::int
                                            as pagos_cuenta,
       coalesce(sum(r.importe) filter (where r.liquidacion = 'CUENTA_DUENA'), 0)::numeric(12,2)
                                            as total_cuenta,
       count(*) filter (where r.liquidacion = 'DIRECTO_FAMILIA')::int
                                            as pagos_directo,
       coalesce(sum(r.importe) filter (where r.liquidacion = 'DIRECTO_FAMILIA'), 0)::numeric(12,2)
                                            as total_directo
  from recobros r
 where r.estado = 'PENDIENTE'
 group by r.propiedad_codigo;

-- ── 5) Candado (068: revoke antes del grant; anon nunca) ──────────────────────────
revoke execute on function f_recobros(date, date)    from public, anon, authenticated;
grant  execute on function f_recobros(date, date)    to authenticated;
revoke execute on function f_cuenta_duena(date, date) from public, anon, authenticated;
grant  execute on function f_cuenta_duena(date, date) to authenticated;
grant  select on v_recobros            to authenticated;
grant  select on v_recobros_pendientes to authenticated;
