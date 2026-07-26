-- 045_avisos_fechados.sql — alertas para costes que cambian en una fecha conocida (Stag, 26/07/2026).
--
-- ── POR QUÉ HACE FALTA ──────────────────────────────────────────────────────────
-- En tres auditorías seguidas apareció el mismo agujero: un coste que cambia en una fecha que
-- ya conocemos, modelado como si fuera constante para siempre.
--
--   · Cuotas de dispositivos de Orange  → terminan oct-2027 y dic-2026  (resuelto en 036 con
--     la vigencia `hasta` de general_expenses)
--   · Klarna-Sklum de Alexander         → cancelado anticipadamente en jun-2026 (resuelto)
--   · Derrama obras IEE de Nicasio      → 149,83 €/mes, fecha de fin PENDIENTE
--   · Promoción de Movistar             → vence 27-10-2026 y el internet SUBE
--
-- `general_expenses` ya tiene vigencia desde/hasta, pero eso sirve para que el motor deje de
-- contar un coste — no para AVISAR. Un cambio que sube el coste no se puede modelar con una
-- fecha de fin: hay que verlo venir con tiempo para poder renegociar.
--
-- `listings.aviso_fecha` existe pero es UNA sola fecha por propiedad, y ya está ocupada por el
-- preaviso de contrato de Alexander (01/09/2026). Hacía falta algo que admita varios.
--
-- ── EL CASO QUE LA ESTRENA ──────────────────────────────────────────────────────
-- Factura Movistar FMPVAFJ001 (10 may – 09 jun 2026), leída línea a línea:
--
--   9142***84  Fibra 600 Mb   33,0578 − 8,2644 (promo) = 24,7934 → 30,00 € c/IVA  → Marechal
--   9145***89  Fibra 600 Mb   29,7520 − 9,0908 (promo) = 20,6612 → 25,00 € c/IVA  → Alexander
--                                                        ────────────────────────
--                                                        45,4546 → 55,00 €
--
-- Confirma de paso que el reparto 30/25 de la 035 es el importe REAL de cada línea, no un
-- prorrateo: partir los 55,00 por la mitad sería menos preciso, no más.
--
-- La promoción de la línea 84 vence el 27-10-2026 y el descuento es de 8,2644 € de base
-- (10,00 € con IVA): el internet de Marechal pasa de 30,00 a 40,00 €/mes.
-- La de la línea 89 dice "12 meses" pero la factura NO trae la fecha. Cuando Stag la mire en Mi
-- Movistar entra acá: el salto sería de 25,00 a 36,00 €/mes (+11,00). Entre las dos, +252 €/año.
--
-- ── VENTANA DE 120 DÍAS, NO 90 ──────────────────────────────────────────────────
-- El aviso de contrato usa 90 días porque es una decisión con fecha límite. Un cambio de precio
-- es distinto: querés verlo con tiempo para llamar y renegociar antes de que se aplique, no
-- para enterarte cuando ya está encima. 120 días da un trimestre largo de margen.

create table if not exists avisos (
  id           bigserial primary key,
  codigo       text not null references listings(codigo),
  fecha        date not null,
  tipo         text not null default 'aviso',
  mensaje      text not null,              -- la consecuencia, SIN la fecha: la vista la añade
  impacto_mes  numeric(12,2),              -- € al mes que cambian (negativo = el coste sube)
  nota         text,
  unique (codigo, fecha, mensaje)
);

comment on table avisos is
  'Cambios de coste con fecha conocida. Alimenta v_alertas; no lo consume el motor de P&L.';

revoke all on avisos from anon, authenticated;

insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '3G_MARE', date '2026-10-27', 'promocion',
       'Vence la promoción de Movistar: el internet pasa de 30,00 a 40,00 €/mes', -10.00,
       'Linea 9142***84 (Fibra 600 Mb). Descuento actual 8,2644 EUR de base = 10,00 con IVA. Factura FMPVAFJ001. La linea ...89 de Alexander tiene otra promocion de 12 meses sin fecha visible en la factura: mirar en Mi Movistar (salto de 25,00 a 36,00).'
where not exists (select 1 from avisos a where a.codigo='3G_MARE' and a.fecha=date '2026-10-27');

-- La vista suma un cuarto tipo. Los tres existentes quedan idénticos.
create or replace view v_alertas as
select 'breakeven'::text as tipo, b.codigo,
       case when b.colchon < 0 then 'critical' else 'warning' end as severidad,
       case when b.colchon < 0
            then 'Por debajo del punto de equilibrio: pierde plata al ritmo actual'
            else 'Colchón ajustado: solo ' || translate(to_char(b.colchon*100, 'FM990.0'), '.', ',')
                 || ' pp por encima del equilibrio ('
                 || translate(to_char(b.ocup_breakeven*100, 'FM990.0'), '.', ',') || ' % necesario)'
       end as mensaje,
       'senal'::text as clase, null::date as fecha_limite, null::integer as dias_restantes
from v_breakeven_ytd b
where b.colchon is not null and b.colchon < 0.10

union all

select 'mes_negativo'::text, p.codigo, 'warning',
       count(*) || ' mes(es) con margen neto negativo este año',
       'senal'::text, null::date, null::integer
from v_pnl_neto_propiedad p
where p.anio = extract(year from now())::int and p.margen_neto < 0
group by p.codigo

union all

select 'contrato'::text, l.codigo,
       case when (l.aviso_fecha - current_date) <= 30 then 'critical' else 'warning' end,
       coalesce(l.aviso_nota, 'Aviso de contrato') || ' — fecha límite '
         || to_char(l.aviso_fecha, 'DD/MM/YYYY')
         || case when (l.aviso_fecha - current_date) = 0 then ' (vence hoy)'
                 when (l.aviso_fecha - current_date) = 1 then ' (falta 1 día)'
                 else ' (faltan ' || (l.aviso_fecha - current_date) || ' días)' end,
       'alerta'::text, l.aviso_fecha, l.aviso_fecha - current_date
from listings l
where l.aviso_fecha is not null and l.aviso_fecha >= current_date
  and (l.aviso_fecha - current_date) <= 90

union all

select a.tipo, a.codigo,
       case when (a.fecha - current_date) <= 30 then 'critical' else 'warning' end,
       a.mensaje || ' — fecha límite ' || to_char(a.fecha, 'DD/MM/YYYY')
         || case when (a.fecha - current_date) = 0 then ' (vence hoy)'
                 when (a.fecha - current_date) = 1 then ' (falta 1 día)'
                 else ' (faltan ' || (a.fecha - current_date) || ' días)' end,
       'alerta'::text, a.fecha, a.fecha - current_date
from avisos a
where a.fecha >= current_date and (a.fecha - current_date) <= 120;

grant select on v_alertas to anon, authenticated;
