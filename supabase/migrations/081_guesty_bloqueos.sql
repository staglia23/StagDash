-- 081 — Bloqueos de calendario de Guesty, con su rótulo (15/08/2026). Idempotente.
--
-- Por qué: los bloqueos manuales eran invisibles para el motor (guesty-sync solo ingería
-- reservas; PLAYBOOK §2.9) y la única señal era pricelabs_prices.booking_status='Blocked',
-- SIN el rótulo. Cicatrices: 13/08 (Marechal 22–25/08, viaje de control diagnosticado como
-- hueco por vender) y 15/08 (Jacobine 13–14/11, casamiento de amigos de Stag, descubierto
-- de rebote al aplicar un min-stay). Convención de rótulos (PLAYBOOK §2.8): "Control" =
-- inspección; "Personal — <motivo>" = bloqueo personal. Esta tabla hace los rótulos
-- legibles desde el dashboard y desde Claude sin que Stag tenga que avisar por chat.
--
-- guesty-sync (v8) la refresca en cada corrida (cada 3 h): ventana hoy → hoy+365, borrar y
-- reinsertar por piso (un bloqueo quitado en Guesty debe desaparecer también acá — no sirve
-- el upsert-sin-delete de reservations). Se excluyen los bloques derivados de reservas
-- (type r/b: ya viven en reservations) y se descarta el objeto reservation anidado
-- (PII de huéspedes, regla del repo).

create table if not exists guesty_bloqueos (
  codigo     text not null references listings(codigo),
  fecha      date not null,
  block_id   text not null,
  tipo       text not null,   -- Calendar Block Types de Guesty: m=manual, o=owner, bd=default,
                              -- sr=smart rule, bw=booking window, ic=iCal, an=advance notice,
                              -- pt=preparación, a=allotment, abl=annual booking limit
  nota       text,            -- el rótulo escrito a mano en Guesty ("Control", "Personal — casamiento")
  desde      timestamptz,     -- startDate del bloque completo (puede exceder la ventana sincronizada)
  hasta      timestamptz,     -- endDate del bloque completo
  created_by text,
  raw        jsonb,           -- bloque crudo SIN reservation/reservationId (auditoría; patrón money_raw)
  synced_at  timestamptz not null default now(),
  primary key (codigo, fecha, block_id)
);

-- Seguridad (doctrina 056/059/061/070): la tabla nace sin permisos; escribe SOLO la Edge
-- Function (service_role, grant explícito) y el RLS queda activo sin policies — un GRANT
-- puesto por descuido se vuelve un no-evento en vez de una fuga.
alter table guesty_bloqueos enable row level security;
grant select, insert, update, delete on guesty_bloqueos to service_role;

-- Frescura de esta pata del sync (patrón pricelabs_last_* de la 063).
alter table sync_state add column if not exists bloqueos_last_run timestamptz;
alter table sync_state add column if not exists bloqueos_last_error text;

-- Lectura del front: vista sin raw. GRANT a authenticated SOLO — nunca a anon (059).
create or replace view v_bloqueos as
  select codigo, fecha, block_id, tipo, nota, desde, hasta, synced_at
  from guesty_bloqueos;

grant select on v_bloqueos to authenticated;
