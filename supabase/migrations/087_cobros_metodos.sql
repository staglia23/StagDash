-- 087_cobros_metodos.sql — el catálogo de formas de cobro y la vista v_cobros (19/08/2026).
--
-- POR QUÉ EXISTE: la Open API de Guesty entrega `paymentMethodId` en cada pago, pero **no
-- expone ningún endpoint que lo traduzca a un nombre** (verificado el 19/08: hay
-- /payment-providers/{id}, /payment-providers/default y /guests/{id}/payment-methods, pero
-- ningún catálogo de métodos de la cuenta; el nombre tampoco viaja dentro de la reserva).
-- Así que el mapeo se hace UNA vez a mano y se guarda acá. A partir de ahora la
-- clasificación sale de un dato duro y estable, no de adivinar sobre el texto de la nota.
--
-- CONFIRMADO POR STAG el 19/08/2026, abriendo las reservas en Guesty: los IDs 58a1931c…e87
-- y 5dee4ebd…6ed6 son "Cash" y "Bank transfer" del desplegable de Guesty (Cash / Bank
-- transfer / Other). De paso confirmó los dos cobros mal marcados que predijo el análisis
-- —GY-jtnC3pfA (329,30) y GY-xH7rHap5 (358,25) eran transferencia y estaban como Cash— y
-- YA los corrigió en Guesty; entrarán con el próximo sync que toque esas reservas.
--
-- LAS TRES DIMENSIONES (ver docs/operativa/COBROS.md):
--   1. canal   → reservations.source          (de dónde viene la reserva)
--   2. cobro   → esta tabla, por método       (cómo entró la plata)
--   3. destino → prefijo de la nota           (dónde cayó: ¿aparece en el banco español?)
-- La 3ª es la que decide el cuadre mensual y la cuenta con el socio, y es la única sin
-- campo propio en Guesty: vive en el texto que escribe Stag.

create table if not exists guesty_payment_methods (
  metodo_id  text primary key,
  nombre     text not null,          -- el que muestra Guesty
  familia    text not null,          -- PASARELA | EFECTIVO | TRANSFERENCIA | PREVISTO | OTRO
  nota       text,
  check (familia in ('PASARELA','EFECTIVO','TRANSFERENCIA','PREVISTO','OTRO'))
);

comment on table guesty_payment_methods is
  'Mapeo paymentMethodId -> nombre legible. La API de Guesty NO lo expone: se mantiene a mano.';

insert into guesty_payment_methods (metodo_id, nombre, familia, nota) values
  ('58a48a4fea2a13ea9fda5873', 'Pasarela Airbnb', 'PASARELA',
   'Inequívoco por los datos: 622 pagos, todos de airbnb2 y sin nota. Es el cobro automático del canal.'),
  ('58a1931c0000000000000e87', 'Cash', 'EFECTIVO',
   'Confirmado por Stag 19/08/2026. Es el primero del desplegable de Guesty, el que queda si no se cambia: por eso arrastraba transferencias mal marcadas.'),
  ('5dee4ebd32acdf7051cd6ed6', 'Bank transfer', 'TRANSFERENCIA',
   'Confirmado por Stag 19/08/2026.'),
  ('589894a91d756b9c47ce1e87', 'Cobro previsto (sin identificar)', 'PREVISTO',
   'PENDIENTE de nombrar. Nunca cobro nada: sus 10 pagos estan todos en PENDING o CANCELLED. No es una forma de cobro, es un cobro programado.'),
  ('58a48a4f0000000000000873', 'Cobro previsto Booking (sin identificar)', 'PREVISTO',
   'PENDIENTE de nombrar. Idem: 2 pagos, ninguno cobrado, solo de Booking.com.')
on conflict (metodo_id) do update
  set nombre = excluded.nombre, familia = excluded.familia, nota = excluded.nota;

grant select, insert, update, delete on guesty_payment_methods to service_role;

-- ── v_cobros: un renglón por pago, con las tres dimensiones resueltas ────────────────
-- OJO: solo expone datos de negocio. Nada de nombres de huéspedes (PII).
create or replace view v_cobros as
select
  r.codigo,
  r.confirmation_code,
  r.checkin_local,
  r.checkout_local,
  r.status                                   as estado_reserva,
  case r.source when 'airbnb2' then 'Airbnb'
                when 'manual'  then 'Directa'
                else r.source end            as canal,
  (p->>'amount')::numeric(12,2)              as importe,
  p->>'status'                               as estado_pago,
  left(coalesce(p->>'paidAt', p->>'createdAt'), 10)::date as fecha_pago,
  p->>'paymentMethodId'                      as metodo_id,
  coalesce(m.nombre, 'Desconocido')          as metodo,
  coalesce(m.familia, 'OTRO')                as familia,
  nullif(p->>'note', '')                     as nota,
  -- 3ª dimensión: dónde cayó la plata. Prefijo nuevo primero; si no, reglas sobre las
  -- notas viejas; si el método es la pasarela, el destino lo pone el canal.
  case
    when p->>'note' ~* '^\s*EFECTIVO\s*[-—]'    then 'EFECTIVO'
    when p->>'note' ~* '^\s*GALICIA-USD\s*[-—]' then 'GALICIA-USD'
    when p->>'note' ~* '^\s*REVOLUT\s*[-—]'     then 'REVOLUT'
    when p->>'note' ~* '^\s*BBVA\s*[-—]'        then 'BBVA'
    when coalesce(m.familia,'') = 'PASARELA'    then 'AIRBNB'
    when p->>'note' ~* 'galicia'                then 'GALICIA-USD'
    when p->>'note' ~* 'revolut'                then 'REVOLUT'
    when p->>'note' ~* 'bbva'                   then 'BBVA'
    when p->>'note' ~* '(efectivo|cash|en mano)' then 'EFECTIVO'
    else null
  end                                        as destino,
  -- La pregunta que decide el cuadre: ¿este dinero aparece en un extracto español?
  case
    when coalesce(m.familia,'') = 'PASARELA' then true
    when p->>'note' ~* '^\s*(EFECTIVO|GALICIA-USD)\s*[-—]' then false
    when p->>'note' ~* '^\s*(REVOLUT|BBVA)\s*[-—]' then true
    when p->>'note' ~* '(galicia)' then false
    when p->>'note' ~* '(efectivo|cash|en mano)' then false
    when p->>'note' ~* '(revolut|bbva)' then true
    else null
  end                                        as entra_en_banco_es
from reservations r,
     lateral jsonb_array_elements(coalesce(r.money_raw->'payments', '[]'::jsonb)) p
left join guesty_payment_methods m on m.metodo_id = p->>'paymentMethodId';

comment on view v_cobros is
  'Un renglón por pago de Guesty: canal, forma de cobro y destino. entra_en_banco_es = si el dinero debe aparecer en un extracto español (null = no se puede saber, falta la nota).';

grant select on v_cobros to authenticated;
