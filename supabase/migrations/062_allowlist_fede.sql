-- 062 — alta de Fede en la allowlist del login (30/07/2026). Idempotente.
--
-- Fede (Federico Del Percio) colabora en las automatizaciones del negocio y pidió acceso
-- al dashboard en la reunión del 22/07. Sin este insert el trigger de la 058 rechaza el
-- alta ("Alta no permitida para este email"): la allowlist gobierna, no el panel.
-- El acceso es de solo lectura por construcción — no hay roles: todo usuario con sesión
-- lee las mismas vistas (rol authenticated) y ninguno escribe (056).

insert into public.auth_email_allowlist (email, nota) values
  ('fndelpercio@gmail.com', 'Fede — colaborador (automatizaciones)')
on conflict (email) do nothing;
