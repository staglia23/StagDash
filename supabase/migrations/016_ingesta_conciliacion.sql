-- 016 — tablas de ingesta para la conciliación a tres puntas (Fase 2).
-- Internas (ops): REVOKE anon/authenticated. No guardan nombres de huéspedes (PII):
-- el cruce se hace por confirmation_code, no por nombre.

-- Lado CAJA: depósitos bancarios (Airbnb y otros).
create table if not exists bank_deposits (
  id         bigint generated always as identity primary key,
  banco      text not null,               -- 'revolut' | 'bbva'
  iban       text,                         -- '7165' | '8920'
  fecha      date not null,
  importe    numeric(12,2) not null,       -- + entrada / − salida
  concepto   text,
  es_airbnb  boolean default false,
  archivo    text,                          -- para recargar por archivo sin duplicar
  cargado_at timestamptz default now()
);
create index if not exists idx_bank_dep_fecha on bank_deposits (banco, fecha);

-- Lado FISCAL/pago: reporte de transacciones de Airbnb (IBAN destino + fecha de llegada).
create table if not exists airbnb_tx (
  id                bigint generated always as identity primary key,
  tipo              text not null,          -- 'Payout' | 'Reserva' | 'Resolucion'
  fecha             date not null,
  fecha_llegada     date,                   -- llegada estimada al banco (Payout)
  confirmation_code text,                   -- HMxxxx (Reserva) → cruza con reservations
  iban              text,                   -- '7165' | '8920' (Payout)
  alojamiento       text,
  inicio            date,
  fin               date,
  noches            int,
  cobrado           numeric(12,2),          -- monto del payout
  importe           numeric(12,2),          -- ganancia del anfitrión (Reserva)
  comision_servicio numeric(12,2),
  limpieza          numeric(12,2),
  bruto             numeric(12,2),
  anio_fiscal       int,
  archivo           text,
  cargado_at        timestamptz default now()
);
create index if not exists idx_airbnb_tx_conf   on airbnb_tx (confirmation_code);
create index if not exists idx_airbnb_tx_payout on airbnb_tx (fecha_llegada, cobrado);

revoke all on bank_deposits from anon, authenticated;
revoke all on airbnb_tx     from anon, authenticated;
