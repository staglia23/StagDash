-- 065_recobros.sql — registro de recobros: plata adelantada que se repercute (04/08/2026).
--
-- Gastos que Samavi (o Stag de su bolsillo) adelanta y luego repercute a un tercero —
-- hoy, la dueña de JACO. Mientras sean recobrables son NEUTROS para Samavi y NUNCA
-- entran a `events` ni al P&L (precedente: mini UPS 77,00 y aspiradora 130,00, sacados
-- del P&L por la migración 049; acá entran como LIQUIDADOS, ya descontados a la dueña).
--
-- Nace del agujero que la 049 dejó documentado: "lo que se paga por fuera no llega al
-- motor salvo que alguien lo escriba". Los bizums a Agustín salen de la cuenta PERSONAL
-- de Stag: los extractos de Samavi no los traen y la conciliación mensual no los ve.
--
-- Ciclo de vida: PENDIENTE → LIQUIDADO (se le descontó a la dueña; si salió de la cuenta
-- personal, la plata vuelve a Stag o queda en cuenta con el socio — eso lo lleva
-- Confisic, fuera de este repo) o INCOBRABLE (no se acepta el descuento: deja de ser
-- neutro, se carga el gasto en `events` a mano en el cierre y acá queda la marca con
-- resuelto_nota OBLIGATORIA apuntando a ese event — nunca en los dos lados a la vez).
--
-- Revisión adversarial 04/08/2026: security definer en f_recobros (sin él, la vista da
-- 42501 a authenticated — el SQL Editor no lo delata porque consulta como postgres),
-- tope del wrapper sin borde de medianoche UTC, checks de estado simétricos, FK a listings.

-- ── 1) Tabla (cruda: RLS sin policies, el cliente solo lee vista/función) ──────────
create table if not exists recobros (
  id               bigint generated always as identity primary key,
  propiedad_codigo text not null references listings(codigo),
  fecha            date not null,                       -- fecha del pago
  concepto         text not null,                       -- texto que ve el dashboard
  importe          numeric(12,2) not null check (importe > 0),  -- a recuperar; siempre positivo
  pagado_por       text not null default 'STAG_PERSONAL'
                   check (pagado_por in ('STAG_PERSONAL', 'SAMAVI')),
  pagado_a         text,                                -- proveedor (Agustín, comercio…)
  medio            text,                                -- 'bizum' | 'efectivo' | 'tarjeta' | …
  estado           text not null default 'PENDIENTE'
                   check (estado in ('PENDIENTE', 'LIQUIDADO', 'INCOBRABLE')),
  resuelto_fecha   date,                                -- cuándo se liquidó / se dio por incobrable
  resuelto_nota    text,                                -- "descontado en la liquidación de ago-2026" / event cruzado
  notas            text,                                -- interno: NO se expone al cliente
  creado_en        timestamptz not null default now(),
  -- PENDIENTE ⇔ sin fecha de resolución; LIQUIDADO e INCOBRABLE la exigen.
  constraint recobros_estado_fecha
    check ((estado = 'PENDIENTE') = (resuelto_fecha is null)),
  -- INCOBRABLE exige la nota cruzada al event que carga el gasto (si no, se duplica el P&L).
  constraint recobros_incobrable_nota
    check (estado <> 'INCOBRABLE' or resuelto_nota is not null)
);

create index if not exists idx_recobros_lookup on recobros (propiedad_codigo, estado, fecha);

alter table recobros enable row level security;  -- sin policies: inaccesible desde el cliente

-- ── 2) Motor (patrón 060: función f_* parametrizada + vistas wrapper) ──────────────
-- Detalle por rango de FECHA DE PAGO. `notas` queda fuera a propósito (interno).
-- security definer: lee una tabla cruda que authenticated no ve (doctrina 060/064);
-- sin él, el cuerpo corre con los privilegios del que consulta y la vista da 42501.
create or replace function f_recobros(p_desde date, p_hasta date)
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
  resuelto_fecha   date,
  resuelto_nota    text,
  dias_pendiente   int
)
language sql stable
security definer set search_path = public, pg_temp
as $$
  select r.id, r.propiedad_codigo, r.fecha, r.concepto, r.importe,
         r.pagado_por, r.pagado_a, r.medio, r.estado,
         r.resuelto_fecha, r.resuelto_nota,
         case when r.estado = 'PENDIENTE'
              then (current_date - r.fecha)::int end as dias_pendiente
    from recobros r
   where r.fecha between p_desde and p_hasta
   order by r.fecha desc, r.id desc;
$$;

-- Wrapper de detalle: histórico completo, con tope holgado a propósito — un tope
-- current_date (UTC) escondería la fila fechada "hoy Madrid" entre las 00:00 y las
-- 02:00 CEST y desalinearía tarjeta y detalle. El rango fino queda para RPC.
create or replace view v_recobros as
  select * from f_recobros(date '2024-01-01', date '2099-12-31');

-- Pendientes agregados por propiedad — SIN filtro de fecha a propósito: una deuda vieja
-- no puede caerse de la tarjeta por antigüedad, que es exactamente como se pierde.
create or replace view v_recobros_pendientes as
select r.propiedad_codigo,
       count(*)::int                        as pagos,
       sum(r.importe)::numeric(12,2)        as total,
       min(r.fecha)                         as mas_viejo_fecha,
       (current_date - min(r.fecha))::int   as mas_viejo_dias,
       coalesce(sum(r.importe) filter (where r.pagado_por = 'STAG_PERSONAL'), 0)::numeric(12,2)
                                            as de_cuenta_personal
  from recobros r
 where r.estado = 'PENDIENTE'
 group by r.propiedad_codigo;

-- ── 3) Candado (lecciones 056/059/061: nada nace con permisos) ─────────────────────
-- GRANT a authenticated SOLO — jamás `to anon` (reabriría lectura sin login).
-- El revoke de public/anon es OBLIGATORIO: el default cableado de Postgres da EXECUTE a
-- PUBLIC en cada función nueva y el candado 061 se SUMA a él, no lo anula (patrón 063/064).
revoke execute on function f_recobros(date, date) from public, anon, authenticated;
grant  execute on function f_recobros(date, date) to authenticated;
grant select on v_recobros            to authenticated;
grant select on v_recobros_pendientes to authenticated;

-- ── 4) Seed (idempotente): el estado 2026 de la columna GASTOS de la cuenta ────────
-- Pendientes: los dos bizums a Agustín (muebles de los 2 baños descolgándose — faltan
-- las patas, generará otro recobro — y rieles inferiores de las 2 duchas repegados).
-- Liquidados: los dos descuentos históricos de la cuenta corriente de la dueña
-- (hoja 2026_JACOBINE_MADRE_INGRESOS), que la 049 sacó del P&L por neutros.
insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, resuelto_fecha, resuelto_nota, notas)
select v.cod, v.fecha, v.concepto, v.importe, v.pagado_por, v.pagado_a,
       v.medio, v.estado, v.resuelto_fecha, v.resuelto_nota, v.notas
from (values
  ('1A_JACO', date '2026-07-23',
   'Arreglo muebles de baño y rieles de ducha — mano de obra (1er pago)',
   40.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Muebles de los 2 baños descolgandose de la pared y rieles inferiores de las 2 duchas repegados. Reportado por Stag el 04/08/2026.'),
  ('1A_JACO', date '2026-08-04',
   'Arreglo muebles de baño y rieles de ducha — mano de obra (2º pago)',
   60.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
   'PENDIENTE', null::date, null,
   'Bizum desde la cuenta personal de Stag, sin factura. Queda pendiente comprar las patas de los muebles (recobro aparte cuando se compren).'),
  ('1A_JACO', date '2026-02-12',
   'Mini UPS + instalación (reposición)',
   77.00, 'SAMAVI', 'Amazon + Agustín (instalación)', 'tarjeta',
   'LIQUIDADO', date '2026-02-28',
   'Descontado en la cuenta corriente de la dueña: GASTOS feb-2026 "compra mini UPS + instalación" (hoja 2026_JACOBINE_MADRE_INGRESOS).',
   'Amazon 56,99 (Revolut tarjeta Virtual, 12/02) + 20,00 a Agustin en efectivo (bolsillo de Stag, 02/03) = 76,99; a la duena se le descontaron 77,00 (1 centimo de redondeo de Stag). Estaba cargado por error como coste de Nicasio hasta la migracion 049.'),
  ('1A_JACO', date '2026-02-28',
   'Aspiradora (reposición)',
   130.00, 'SAMAVI', 'Amazon', 'tarjeta',
   'LIQUIDADO', date '2026-03-31',
   'Descontado en la cuenta corriente de la dueña: GASTOS mar-2026 "aspiradora reposición" (hoja 2026_JACOBINE_MADRE_INGRESOS).',
   'Cargo Revolut "Www.amazon* Te5ke0el5" 129,98 del 28/02 (liquidado el 01/03); a la duena se le descontaron 130,00. Estaba cargado por error como coste de Nicasio hasta la migracion 049.')
) as v(cod, fecha, concepto, importe, pagado_por, pagado_a, medio, estado, resuelto_fecha, resuelto_nota, notas)
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = v.cod and r.fecha = v.fecha and r.importe = v.importe
);
