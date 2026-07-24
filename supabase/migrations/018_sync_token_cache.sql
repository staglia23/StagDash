-- 018 — caché del token de Guesty en sync_state (dura 24h → no pedir en cada corrida).
-- Evita el rate-limit del endpoint de token: se pide uno nuevo solo cuando el cacheado venció.
-- Lo usa guesty-sync v6+.
alter table sync_state add column if not exists guesty_token     text;
alter table sync_state add column if not exists guesty_token_exp timestamptz;
