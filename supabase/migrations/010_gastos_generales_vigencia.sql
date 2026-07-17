-- 010_gastos_generales_vigencia.sql — (Stag, 16/07/2026) los gastos generales pueden tener
-- vigencia: Brand Partners es 500 €/mes desde may-2026 "hasta nuevo aviso" (el setup de
-- 1.400 € NO existió). Modelarlo como evento año a año repetiría el gotcha ene-2027 de la
-- renta de ALEX (se cargó solo nov–dic y en enero desaparece): un recurrente sin fin va en
-- general_expenses con fecha de inicio, no en events.
--   · general_expenses.desde / .hasta (null = sin límite por ese lado).
--   · v_samavi_gen_mensual solo suma las líneas vigentes en cada mes.
--   · Se eliminan los eventos Brand Partners (setup + ongoing may–dic): quedaban duplicados.

alter table general_expenses add column if not exists desde date;
alter table general_expenses add column if not exists hasta date;

delete from events where propiedad_codigo = 'SAMAVI_GEN' and concepto like 'Brand Partners%';

insert into general_expenses (concepto, importe_mes, desde)
select 'Brand Partners (marketing)', 500.00, date '2026-05-01'
where not exists (select 1 from general_expenses where concepto = 'Brand Partners (marketing)');

create or replace view v_samavi_gen_mensual as
select m.anio, m.mes,
  (select coalesce(sum(g.importe_mes), 0)
     from general_expenses g
    where (g.desde is null or make_date(m.anio, m.mes, 1) >= date_trunc('month', g.desde)::date)
      and (g.hasta is null or make_date(m.anio, m.mes, 1) <= g.hasta))
  - coalesce((select sum(importe) from events e
              where e.categoria='SAMAVI_GEN' and e.anio=m.anio and e.mes=m.mes), 0) as overhead
from (select distinct anio, mes from v_month_spine) m;
