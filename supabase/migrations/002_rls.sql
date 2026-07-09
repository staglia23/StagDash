-- 002_rls.sql — Row Level Security (Pilar: Seguro)
-- Estrategia: RLS ON en todas las tablas base SIN políticas de lectura para anon/authenticated,
-- de modo que el cliente NO puede tocar las tablas directamente. El front solo lee las VISTAS
-- del dashboard (ver 003_views.sql), que corren con los privilegios del owner (security definer
-- por defecto) y exponen únicamente columnas no sensibles. La escritura la hace la Edge Function
-- con la service_role key (que bypassa RLS).

alter table listings         enable row level security;
alter table reservations     enable row level security;
alter table general_expenses enable row level security;
alter table events           enable row level security;
alter table sync_state       enable row level security;

-- Sin credenciales del cliente sobre las tablas base (nif/iban/host_payout nunca viajan al front).
revoke all on listings, reservations, general_expenses, events, sync_state
  from anon, authenticated;

-- Nota: service_role bypassa RLS por defecto en Supabase → la ingesta escribe sin políticas.
-- Los GRANT de SELECT para 'anon' se otorgan SOLO sobre las vistas del dashboard en 003_views.sql.
