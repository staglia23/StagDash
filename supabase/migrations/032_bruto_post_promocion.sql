-- 032_bruto_post_promocion.sql — el ADR deja de contar plata que nunca se cobró (Stag, 25/07/2026).
--
-- ── EL PROBLEMA ─────────────────────────────────────────────────────────────────
-- El sync guardaba `bruto = fareAccommodation + fareCleaning`, o sea ANTES de las promociones
-- del canal (Early bird, Last minute, descuento por estadía larga). Guesty trae los dos campos
-- y el cobro real cierra con el ajustado. Ejemplo, Alexander 24/06/2026:
--
--     fareAccommodation          1.171,00     ← el que usaba el motor
--     fareAccommodationAdjusted  1.077,32     ← el que se cobró
--     promoción "Early bird"       −93,68
--     1.077,32 + 50,00 (limpieza) − 211,42 (fee) = 915,90 = hostPayout   ✓ exacto
--
-- La migración 013 ya había arreglado lo importante — la base de comisión de Jacobine usa
-- `host_payout + host_service_fee`, que sí es post-descuento — pero dejó `bruto` sin tocar
-- a propósito ("fix quirúrgico"). Consecuencia: ADR y RevPAR inflados. En 2026, +1,56 % en la
-- cartera y +2,63 % en Alexander. No afecta al margen (el ingreso siempre salió del payout),
-- pero sí a las decisiones de precio: el ADR del dashboard es el que se usa para calibrar
-- PriceLabs.
--
-- ── EL ARREGLO ──────────────────────────────────────────────────────────────────
-- `money_raw` ya guarda `fareAccommodationAdjusted` en las 527 reservas (0 sin el campo), así
-- que el histórico se corrige acá mismo, sin volver a llamar a Guesty. El sync se actualiza en
-- paralelo (supabase/functions/guesty-sync/index.ts, v7) para que las nuevas entren bien.
--
-- 74 reservas tienen promoción, 7.906,93 € en total desde 2024.
--
-- ── LO QUE ESTA MIGRACIÓN NO TOCA, Y POR QUÉ ────────────────────────────────────
-- Quedan 19 reservas donde `fare_ajustado + limpieza − fee ≠ payout`. Son tres cosas distintas
-- y ninguna se arregla acá:
--
--  1. BOOKING.COM (3 reservas, todas de Nicasio): el payout NO trae descontada la comisión del
--     canal — Booking la factura aparte. El motor cuenta 535,93 € de ingreso que después se le
--     pagan a Booking. Es una decisión de negocio (¿ingreso neto o coste separado?) y hay que
--     acordarla antes de tocarla: cambia la comparabilidad entre canales y el cuadre bancario.
--  2. FEES EXTRA (mascota, huésped adicional): entran al payout pero no a fareAccommodation ni
--     a fareCleaning. El ingreso está bien; el ADR queda algo corto. Se deja así a propósito:
--     el ADR estándar mide alojamiento, no extras.
--  3. REEMBOLSOS Y AJUSTES MANUALES: el más grande es el termo de Alexander (02/04, 356,00 €).
--     Son hechos puntuales, no una regla del motor.

update reservations r
   set bruto = round(
         coalesce((r.money_raw::jsonb->>'fareAccommodationAdjusted')::numeric,
                  (r.money_raw::jsonb->>'fareAccommodation')::numeric, 0)
       + coalesce((r.money_raw::jsonb->>'fareCleaning')::numeric, 0), 2)
 where r.money_raw is not null
   and (r.money_raw::jsonb->>'fareAccommodationAdjusted') is not null
   and abs(r.bruto - (
         coalesce((r.money_raw::jsonb->>'fareAccommodationAdjusted')::numeric, 0)
       + coalesce((r.money_raw::jsonb->>'fareCleaning')::numeric, 0))) > 0.005;
