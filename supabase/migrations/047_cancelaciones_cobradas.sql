-- 047_cancelaciones_cobradas.sql — una cancelada sin cobro no es un cobro retenido (auditoría
-- de Jacobine, 26/07/2026).
--
-- La regla del motor es "canceladas excluidas, SALVO cobros retenidos". `v_ingreso_cancelaciones`
-- la implementaba como `host_payout <> 0`, que no es lo mismo: en una reserva MANUAL de Guesty
-- el `host_payout` se copia del precio, exista o no un cobro. Tres casos en la base:
--
--   1A_JACO  dic-2025  GY-maaMEbuB  manual   bruto 342,00  payout 342,00  cobrado 0,00   ← fantasma
--   1A_NICA  dic-2025  GY-nc72xAQr  manual   bruto 200,00  payout 200,00  cobrado 0,00   ← fantasma
--   3G_MARE  ago-2026  HMA2CS9HZB   airbnb2  bruto 383,00  payout 311,17  cobrado 0,00   ← legítimo
--
-- Los dos primeros son reservas que alguien cargó a mano y después canceló: nunca hubo plata.
-- Sumaban 285,50 € de ingreso inventado (85,50 en Jacobine, 200,00 en Nicasio).
--
-- El tercero es distinto y por eso NO se puede filtrar sólo por `total_paid`: Airbnb adjudica la
-- retención al cancelar pero la paga el día del check-in original (20/08), que todavía no llegó.
-- Ahí el payout sí es un derecho de cobro real. La regla queda: se cuenta si YA se cobró, o si
-- lo retuvo un canal (que es quien adjudica la retención y después la paga).
--
-- Efecto en el año en curso: NINGUNO. Los dos fantasmas son de diciembre de 2025 y las vistas
-- están fijadas al año en curso. Es un arreglo preventivo: la próxima manual cancelada habría
-- entrado igual, y en un mes flojo 300 € de ingreso falso mueven el semáforo.
--
-- ── Y DE PASO, LA BASE DE COMISIÓN ──────────────────────────────────────────────
-- La migración 013 movió la base de comisión de Jacobine de `bruto` a `host_payout +
-- host_service_fee` (bruto POST-descuento) en `v_reservation_income`, pero dejó
-- `v_ingreso_cancelaciones` con `bruto`. Dos vistas del mismo motor calculando la misma
-- comisión de dos maneras distintas.
--
-- Hoy da igual — en las tres canceladas de Jacobine `bruto = payout + fee` al céntimo, porque
-- Airbnb rehace los importes al cancelar. Pero una cancelada con promoción o con ajuste del
-- Resolution Center abriría la divergencia sin avisar. Se alinean las dos.

-- `create or replace` y no `drop ... cascade`: de esta vista cuelgan v_pnl_mensual_propiedad y
-- v_margen_asegurado, y de ellas media cartelera. Las columnas y sus tipos no cambian.
create or replace view v_ingreso_cancelaciones as
select
  r.codigo,
  extract(year  from r.checkin_local)::int  as anio,
  extract(month from r.checkin_local)::int  as mes,
  -- Misma base que v_reservation_income desde la 013: bruto POST-descuento.
  sum(case when l.modelo = 'comision'
           then (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0))
                * l.comision_pct / (1 + l.iva_pct)
           else coalesce(r.host_payout, 0) end)                                as ingreso_cancelaciones,
  count(*)                                                                      as reservas_canceladas,
  sum(case when l.modelo = 'comision'
           then (coalesce(r.host_payout, 0) + coalesce(r.host_service_fee, 0))
                * l.comision_pct * (1 - 1 / (1 + l.iva_pct))
           else 0 end)                                                          as iva_cancelaciones
from reservations r
join listings l on l.codigo = r.codigo
where r.status = 'canceled'
  and r.checkin_local is not null
  and (
        coalesce(r.total_paid, 0) <> 0                                   -- ya cobrado
     or (r.source <> 'manual' and coalesce(r.host_payout, 0) <> 0)       -- retenido por el canal
      )
group by r.codigo,
         extract(year  from r.checkin_local),
         extract(month from r.checkin_local);

grant select on v_ingreso_cancelaciones to anon;
