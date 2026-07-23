-- 013_jacobine_base_comision.sql — base de comisión al bruto POST-descuento.
-- Contexto (24/07/2026, verificado contra los PDF de Airbnb de Jacobine): el `bruto` guardado
-- (fareAccommodation + fareCleaning) es PRE-descuento. Cuando una reserva tiene descuento
-- (estadía larga/oferta), Guesty reduce el cobro real pero nuestro `bruto` queda inflado.
-- Como el ingreso de los pisos en comisión (solo JACO) = comision_pct × bruto, eso
-- sobreestimaba el Ingreso Samavi de Jacobine (2026: 947,48 € de descuentos → 286,61 € de más).
-- El bruto REAL cobrado = host_payout + host_service_fee (idéntico al `bruto` en reservas sin
-- descuento; menor cuando hay descuento). Es la misma base que usa Guesty (host_payout +
-- host_channel_fee). Fix quirúrgico: SOLO cambia la base de comisión. Titular/subarriendo
-- (NICA/ALEX/MARE) corren sobre host_payout y NO se tocan. `bruto` (ADR/RevPAR) se deja igual.
-- NOTA: sin grant — 008 revocó anon sobre esta vista (exponía host_payout por reserva);
-- create or replace preserva los privilegios, así que no se reabre la fuga.

create or replace view v_reservation_income as
select
  r.id, r.codigo, r.checkin_local, r.checkout_local, r.source, r.status,
  coalesce(r.bruto, 0)       as bruto,
  coalesce(r.host_payout, 0) as host_payout,
  l.modelo,
  case when l.modelo = 'comision'
       then (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else coalesce(r.host_payout,0) end                                    as ingreso_samavi,
  case when l.modelo = 'comision'
       then coalesce(r.host_payout,0) - (coalesce(r.host_payout,0) + coalesce(r.host_service_fee,0)) * l.comision_pct
       else 0 end                                                            as pasivo_madre
from reservations r
join listings l on l.codigo = r.codigo
where r.status in ('confirmed','checked_in','checked_out')
  and r.checkin_local is not null and r.checkout_local is not null
  and r.checkout_local > r.checkin_local;
