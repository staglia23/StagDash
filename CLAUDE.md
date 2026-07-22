# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Dashboard financiero de Samavi Global Vision SL (4 pisos turísticos). El usuario (Stag, CEO,
no técnico) lo consulta desde el móvil; el idioma del producto y de la colaboración es
**español (voseo)**. La spec canónica de producto es `02_Prompt_Dashboard_CEO.md` — leerla
antes de diseñar pantallas nuevas.

## Comandos

Todo el frontend vive en `web/` (ojo: la ruta del repo termina en espacio — citar siempre
las rutas en shell).

```bash
cd web
npm run dev                    # dev server
npm run build                  # build de producción (Vercel usa root=web)
npx tsc --noEmit               # typecheck
npx vitest run                 # suite completa (~37 tests)
npx vitest run tests/headline.test.ts   # un archivo
```

- **Deploy**: push a `main` → Vercel despliega solo. La terminal no tiene credenciales de
  GitHub y `gh` no está instalado: el push lo hace el usuario desde VS Code (Source
  Control → Sync). Las `NEXT_PUBLIC_*` se hornean en el build → si cambian, Redeploy.
- **SQL**: migraciones numeradas en `supabase/migrations/`. Se aplican con el MCP de
  Supabase (`apply_migration`, proyecto `enlslwuokresrwbqpyeo`) o, si el conector está
  caído, dándole al usuario un bloque para pegar en el SQL Editor — en ese caso el bloque
  DEBE ser idempotente (`where not exists` / `on conflict`): ya ejecutó uno dos veces.
  `apply_all.sql` y `seed/seed.sql` se mantienen sincronizados con producción (secciones
  "SYNC"): tras cambiar datos/esquema en producción, actualizarlos.
- **Local**: `web/.env.local` (gitignored) con `NEXT_PUBLIC_SUPABASE_URL` y
  `NEXT_PUBLIC_SUPABASE_ANON_KEY` (la anon key es pública por diseño).
- **Verificación visual móvil**: `chrome --headless --window-size` NO emula viewport móvil
  (da capturas engañosas); usar CDP con `Emulation.setDeviceMetricsOverride` a 390×844.
  Hay un helper websocket en scratchpad cuando hace falta (sin dependencias).

## Arquitectura

```
Guesty Open API → Edge Function guesty-sync (cron 3h) → Postgres RAW
  (listings, reservations, general_expenses, events, sync_state)
    → MOTOR = vistas SQL (migrations 003–011)
      → Next.js 14 App Router (server components, anon key, SOLO vistas)
```

**El motor de negocio vive en SQL, en un solo lugar.** El cliente nunca reconstruye
lógica de negocio (única excepción: el simulador, `web/lib/simulador.ts`, hipotético por
definición). Reglas del motor, validadas contra el Excel histórico y contra bancos:

- Ingreso por modelo: titular (NICA) y subarriendo (ALEX, MARE) → `host_payout`;
  comisión (JACO) → 30,25 % del bruto. Bruto = fareAccommodation + fareCleaning.
- Imputación por **devengo/noche** (Guesty Analytics usa payout por check-in — por eso
  sus números NO coinciden con los nuestros y está bien que no coincidan).
- Canceladas excluidas, SALVO cobros retenidos (`v_ingreso_cancelaciones`, línea de
  ingreso separada que nunca toca noches/ADR/ocupación).
- Overhead (gastos generales) prorrateado por peso en el Ingreso Samavi; los gastos
  generales tienen vigencia `desde`/`hasta` (null = sin límite).
- `events` = ajustes mensuales por propiedad: importe negativo = gasto, positivo = crédito.
- Las vistas están fijadas al año en curso (`v_month_spine` + filtros `now()` propios en
  4 vistas YTD): parametrizar el período requiere RPCs, no filtros en cliente (ver §5.2
  de la spec).

**Seguridad — la lección más cara del repo**: los default privileges de Supabase hacen
legible por `anon` TODA vista nueva de `public`. Cada migración que crea una vista debe
incluir su `GRANT` explícito (si va al dashboard) o su `REVOKE` (si es interna). En 008
se cerró una fuga real (`v_reservation_income` exponía `host_payout` por reserva).
PII (propietario/NIF/IBAN, nombres de huéspedes) jamás sale a vistas públicas ni al repo
(en seeds van como 'PENDIENTE').

**Frontend** (`web/`):
- Server components hacen fetch vía `readView()` (`lib/supabase.ts`) — el cliente fuerza
  `cache: "no-store"` porque la Data Cache de Next servía respuestas viejas incluso con
  `force-dynamic`. No quitarlo.
- La lógica calculable vive como funciones puras testeadas en `lib/`: `headline.ts`
  (cascada del titular, ≤90 chars), `simulador.ts` (anualización run-rate: noche ×365/disp,
  mensual ×12/meses; overhead pool ×12/meses-del-año), `salud.ts` (semáforo forward),
  `waterfall.ts`, `mtd.ts`. Los tests (`web/tests/`) usan fixtures con datos reales de
  producción — al cambiar reglas de negocio, actualizar ambos.
- Client components solo donde hay interacción o Recharts (`Simulador`, charts).
- Nombres de display: mapa `NOMBRES` en `lib/headline.ts` (Nicasio, Alexander, Marechal,
  Jacobine). Los códigos (`1A_NICA`, `4B_ALEX`, `3G_MARE`) son piso+puerta: los tres de
  Madrid están en el mismo edificio (Calle Segovia 8); Jacobine está en Sevilla.

## Doctrina de diseño (del prompt CEO — se aplica a todo lo nuevo)

- Respuesta primero; todo número lleva su comparación o consecuencia; cero vanity metrics.
- **El único umbral objetivo es el punto de equilibrio** — no se inventan targets.
- Todo importe etiquetado: **real** (devengado) / **ya reservado** / **simulado**.
- Ningún estado comunicado solo por color (icono + texto siempre); contraste AA en light
  y dark (tokens en `globals.css`; `--accent-bg` existe porque `--series-1` no daba 4,5:1
  con texto blanco); targets táctiles ≥44 px; nunca doble eje Y; formato es-ES con
  `lib/format.ts` (fuerza punto de miles en 4 cifras; `fechaLarga` usa Europe/Madrid).
- Color = entidad, fijo por propiedad (`lib/colors.ts`).

## Operativa con el usuario

- Ritual de cierre mensual: Stag sube extractos (Revolut/BBVA/tarjeta) a Google Drive
  (`Confisic → SAMAVI GLOBAL VISION SL → <año> → "MM - Mes" → BANCOS EXTRACTOS`); se
  concilian contra el modelo y las diferencias se cargan como `events`. Las reglas de
  clasificación permanentes (qué comercio va a qué propiedad) están en la memoria del
  proyecto — consultarla antes de clasificar.
- Los "xls" de BBVA son XLSX renombrados; los CSV de Drive llegan en base64
  (decodificar con `base64 -D` en macOS).
- MCP de PriceLabs conectado (precios dinámicos de los 4 listings): tiene herramientas de
  escritura — cambiar precios SOLO con confirmación explícita del usuario.
