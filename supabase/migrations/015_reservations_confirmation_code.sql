-- 015 — código de confirmación del canal (Airbnb HMxxxx, etc.) por reserva.
-- Habilita el cruce 1:1 Guesty ↔ reporte de transacciones de Airbnb (clave única,
-- sin depender de monto/fecha). Lo llena el sync (guesty-sync v4+); backfill vía re-sync.
alter table reservations add column if not exists confirmation_code text;
create index if not exists idx_reservations_conf on reservations (confirmation_code);
