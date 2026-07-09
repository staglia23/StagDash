# Stag Dashboard — Rendimiento neto por propiedad (Samavi)

Dashboard financiero que porta el modelo del Excel de Samavi a una web viva:
**Guesty Open API → Supabase (Postgres) → Next.js/Vercel**. Muestra el margen neto por
propiedad (directo y neto tras overhead), ranking y tendencia mensual.

El motor de cálculo vive en **vistas SQL** y está validado 1:1 contra la hoja `Vista B` del
Excel (`scripts/validate_model.py` → TOTAL 10.586,82 €).

## Estructura

```
supabase/
  migrations/001_schema.sql   tablas + índices + helper days_in_month
  migrations/002_rls.sql      RLS (anon no toca tablas; solo lee vistas)
  migrations/003_views.sql    motor de cálculo (waterfall, overhead, neto, KPIs)
  functions/guesty-sync/      Edge Function de ingesta (OAuth, upsert idempotente)
  seed/seed.sql               listings/general_expenses/events (generado del Excel)
scripts/
  excel_to_seed.py            regenera seed.sql desde el Excel
  validate_model.py           valida el motor contra Vista B (no requiere DB)
web/                          Next.js (App Router): home + detalle por propiedad
```

## Puesta en marcha

### 1. Supabase
```bash
supabase link --project-ref <ref>
supabase db push                     # aplica migrations 001-003
psql "$DATABASE_URL" -f supabase/seed/seed.sql   # o vía SQL editor
```

### 2. Ingesta Guesty (Edge Function)
Generá credenciales en Guesty (Integrations → API & Webhooks, requiere admin) y cargá los secrets:
```bash
# SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los inyecta Supabase solo (no se setean).
supabase secrets set GUESTY_CLIENT_ID=... GUESTY_CLIENT_SECRET=...
supabase functions deploy guesty-sync
supabase functions invoke guesty-sync            # backfill inicial + reconciliación
```

Agenda cada ~3h: ejecutá `supabase/cron_setup.sql` en el SQL Editor (reemplazando
`<PROJECT_REF>` y `<SERVICE_ROLE_KEY>`), o usá Dashboard → Integrations → Cron.

### 3. Web
```bash
cd web
cp ../.env.example .env.local        # completar NEXT_PUBLIC_SUPABASE_URL y ANON_KEY
npm install && npm run dev
```
Deploy en Vercel: importar el repo, root `web/`, setear las dos `NEXT_PUBLIC_*`.

## Pendientes de validar en Fase 2 (con datos reales)
- **Mapeo de `money`** (qué campo = "Bruto"): reconciliar `reservations` contra `_RAW_INGRESOS_2026`.
- **Reservas canceladas**: el modelo hoy las incluye (como el Excel). Ver nota en `003_views.sql`.

## Reglas de negocio clave (ver `01_Prompt_Planificacion_Dashboard.md`)
- Ingreso Samavi: titular/subarriendo = host_payout · comisión (JACO) = 30,25 % del bruto.
- Imputación por **devengo/noche**. Overhead SAMAVI_GEN prorrateado por Ingreso Samavi.
- Costos y parámetros en tablas editables (portados del Bloque A/B/C del Excel).
