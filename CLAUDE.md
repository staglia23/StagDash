# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Dashboard financiero de Samavi Global Vision SL (4 pisos turísticos). El usuario (Stag, CEO,
no técnico) lo consulta desde el móvil; el idioma del producto y de la colaboración es
**español (voseo)**. La spec canónica de producto es `prompts/02_Prompt_Dashboard_CEO.md` — leerla
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
  GitHub y `gh` no está instalado. **El commit lo hace Claude** (con mensaje; regla del
  30/07: a Stag el editor de mensajes le estorba) y **el push lo hace el usuario** desde
  VS Code (Source Control → Sync). Las `NEXT_PUBLIC_*` se hornean en el build → si
  cambian, Redeploy.
- **SQL**: migraciones numeradas en `supabase/migrations/`. Se aplican con el MCP de
  Supabase (`apply_migration`, proyecto `enlslwuokresrwbqpyeo`) o, si el conector está
  caído, dándole al usuario un bloque para pegar en el SQL Editor — en ese caso el bloque
  DEBE ser idempotente (`where not exists` / `on conflict`): ya ejecutó uno dos veces.
  `apply_all.sql` y `seed/seed.sql` se mantienen sincronizados con producción (secciones
  "SYNC"): tras cambiar datos/esquema en producción, actualizarlos.
  **Los smoke tests contra producción limpian SOLO las filas que crearon, por id.** Un
  `delete from <tabla>` pelado parece inofensivo en una tabla "vacía de pruebas" y no lo es:
  el 19/08/2026 borró la primera nota real que Stag había dictado en `notas_inbox` mientras
  se probaba la 088 (se detectó porque la secuencia iba una por delante de las filas que yo
  había creado). Producción no tiene tablas de juguete.
- **Local**: `web/.env.local` (gitignored) con `NEXT_PUBLIC_SUPABASE_URL` y
  `NEXT_PUBLIC_SUPABASE_ANON_KEY` (la anon key es pública por diseño). Tras la 059 la
  anon key sola no lee ninguna vista: ver datos en local o verificar por CDP exige
  sesión iniciada (usuario de la allowlist, cookie de Supabase Auth).
- **Verificación visual móvil**: `chrome --headless --window-size` NO emula viewport móvil
  (da capturas engañosas); usar CDP con `Emulation.setDeviceMetricsOverride` a 390×844.
  Hay un helper websocket en scratchpad cuando hace falta (sin dependencias).

## Arquitectura

```
Guesty Open API → Edge Function guesty-sync (cron 3h) ─┐
PriceLabs API   → Edge Function pricelabs-sync (cron   ├→ Postgres RAW (listings,
                  diario 07:10 UTC, migración 063)  ───┘   reservations, general_expenses,
                                                           events, sync_state, pricelabs_prices)
    → MOTOR = funciones f_*(desde, hasta) + vistas wrapper "año en curso" (migración 060)
      → Next.js 14 App Router (login Supabase Auth → server components, JWT authenticated,
        SOLO vistas — única excepción de escritura: la bandeja `/anotar` de la 087/088)
```

**El motor de negocio vive en SQL, en un solo lugar.** El cliente nunca reconstruye
lógica de negocio (única excepción: el simulador, `web/lib/simulador.ts`, hipotético por
definición). Reglas del motor, validadas contra el Excel histórico y contra bancos:

- Ingreso por modelo: titular (NICA) y subarriendo (ALEX, MARE) → `host_payout`;
  comisión (JACO) → 25 % de (host_payout + host_service_fee): se factura 30,25 % IVA
  incluido y los 5,25 puntos son IVA repercutido, no ingreso (migración 021).
  Bruto = fareAccommodationAdjusted + fareCleaning (post-promoción, migración 032).
- Imputación por **devengo/noche**. Guesty Analytics está en "Recognized Revenue =
  Calendar Dates" (mismo prorrateo por noche que el motor) con base `host_payout`, así que
  coincide con nosotros en NICA/ALEX/MARE; la única diferencia real es JACO (mostramos
  el 25 % neto, Guesty Analytics muestra el host_payout bruto). El commission tool de
  Guesty NO alimenta el dashboard (leemos el dato crudo, no sus reportes).
- Canceladas excluidas, SALVO cobros retenidos (`v_ingreso_cancelaciones`, línea de
  ingreso separada que nunca toca noches/ADR/ocupación).
- Overhead (gastos generales no corporativos) prorrateado por **días bajo gestión**
  (`v_dias_gestion`; con los 4 pisos activos todo el mes, 25 % cada uno). El simulador
  usa la MISMA regla desde el 27/07/2026 (cuota fija = la parte YTD del pool de cada
  piso; las palancas no la mueven). Los gastos generales tienen vigencia `desde`/`hasta`
  (null = sin límite); los corporativos (`es_corporativo`) van fuera del margen por piso.
- `events` = ajustes mensuales por propiedad: importe negativo = gasto, positivo = crédito.
- `pricelabs_prices` (063, saneada en 064) = calendario forward por piso/noche: precio
  publicado vs recomendado vs override, noche vendida + ADR + fecha de reserva (lead
  time), demanda y STLY. Dato operativo/forward — NUNCA entra al P&L devengado. Se lee
  por `f_pricelabs_forward(desde, hasta)` / `v_pricelabs_forward` (próximos 30 días),
  que separa bloqueadas (sin palanca) de huérfanas por min-stay (con palanca). La 064
  arregló dos trampas de origen: el STLY previo a `listings.fecha_inicio` ahora es NULL
  (PriceLabs manda cadena vacía y parecía "0 % de ocupación"), y la última fecha
  sincronizada llega "unbookable" por artefacto de borde (el sync pide un día extra y lo
  descarta; el motor la trata como libre). `pricelabs_fotos` (064) = foto diaria
  insert-only del calendario, cimiento del pace — no se puede reconstruir hacia atrás.
  v_freshness delata si el dato de PriceLabs está viejo. El sync necesita el secret
  `PRICELABS_API_KEY` (PriceLabs → Account Settings → API Details; 1 $/mes por listing).
  La reconciliación con PriceLabs dio 0 €: sus cifras usan alojamiento SIN limpieza,
  cuentan bloqueos como ocupados y cortan en hoy — diferencias definicionales, no errores.
- El período es parametrizable desde la 060: el motor vive en funciones `f_*(desde,
  hasta)` (`f_spine` → `f_pnl_mensual_propiedad` → `f_ranking`/`f_costes`/`f_breakeven`/
  `f_canal`, por RPC a `authenticated`) y las vistas son wrappers del año en curso,
  verificadas idénticas al céntimo. Rango a mes completo. Nada de filtrar en cliente: el
  prorrateo del overhead no se reconstruye sumando meses. OJO doble con Postgres acá:
  (1) el EXECUTE de una función usada dentro de una vista se comprueba contra el usuario
  que consulta → toda `f_` nueva necesita GRANT a authenticated aunque sea "interna";
  (2) los typmod del `returns table` se descartan → si una vista wrapper necesita
  `numeric(8,2)`, el cast va en el wrapper.

**Seguridad — la lección más cara del repo**: los default privileges de Supabase le
regalaban a `anon` TODOS los privilegios (lectura Y escritura) sobre cada objeto nuevo de
`public`. En 008 se cerró una fuga de lectura real (`v_reservation_income` exponía
`host_payout` por reserva) y en 056 una de escritura (`v_propiedades` era auto-actualizable
con la anon key: se podía cambiar `renta_base` o insertar pisos fantasma). Desde la 056
(tablas/vistas) y la 061 (funciones y secuencias) los default privileges de `postgres`
están revocados: toda vista, función o secuencia nueva nace SIN permisos y necesita su
GRANT explícito (la 061 existe porque cada función nueva nacía ejecutable por anon vía
/rpc/ — el candado 056 solo cubría tablas). **OJO con las funciones (lección de la 068,
04/08/2026): el candado 061 NO alcanza.** El default CABLEADO de Postgres da EXECUTE a
`PUBLIC` en cada función nueva y el `pg_default_acl` de la 061 se SUMA a ese default en
vez de anularlo — así que toda `f_` nueva nace ejecutable por `anon` vía /rpc/ salvo que
lleve su `revoke execute on function … from public, anon` explícito ANTES del grant
(patrón 063/064). Las 065/066 lo omitieron y `anon` podía leer los recobros y la cuenta
de la dueña sin login (las f_ son SECURITY DEFINER: saltan el RLS). El smoke test de
`anon` debe probar el camino **/rpc/** de cada función nueva, no solo `select` sobre las
vistas — una f_ abierta no se delata desde la vista.

**Edge Functions — `verify_jwt` NO es una puerta (lección 069, 04/08/2026)**: el gateway
solo valida que el JWT esté bien *firmado*, y la anon key es exactamente eso, publicada en
el bundle del dashboard. `verify_jwt=true` sube el listón de "cualquiera del planeta" a
"cualquiera que abrió el sitio una vez", nada más. La auditoría invocó `guesty-sync` con un
curl pelado (200, y escribió en la base) y `pricelabs-sync` con la anon key descargada del
propio sitio. Ambas corren con service_role, o sea que bypassan RLS. Desde la 069 las dos
exigen la cabecera `x-sync-secret`, que el cron saca de Vault y el handler valida con
`f_sync_secret_ok` (security definer, EXECUTE solo para `service_role`) **antes de tocar
nada**. Al tocar esto, el ORDEN importa: primero el secreto y la reprogramación del cron
(`supabase/cron_setup.sql`), después el deploy de las funciones — al revés el sync se
rechaza a sí mismo y el dato envejece sin error visible. Y las funciones no devuelven
`String(e)` al cliente: el detalle va a `sync_state` (que es de donde lo lee `v_freshness`). Limitación conocida: los default privileges
de `supabase_admin` no se pueden tocar desde migraciones (insufficient_privilege, dos
intentos); solo afecta a objetos creados por la plataforma, no por nuestras migraciones. Desde el login (058: `auth_email_allowlist`
+ trigger en `auth.users` que rechaza altas ajenas; 059: revoke de lectura a `anon`), ese
GRANT es **`to authenticated` SOLO — nunca `to anon`**: un `to anon` copiado de una
migración vieja reabre la lectura sin login y el dashboard no lo delataría (él ya lee
como authenticated).
PII (propietario/NIF/IBAN, nombres de huéspedes) jamás sale a vistas públicas ni al repo
(en seeds van como 'PENDIENTE').

**La única escritura del cliente (087 + 088, 19/08/2026)**: `/anotar` → `f_nota_add` /
`f_nota_editar` / `f_nota_borrar` → `notas_inbox`, y nada más. Se acotó a propósito para no
romper la doctrina: esas tres funciones solo tocan esa tabla, nada del motor la lee, y el
autor y el permiso los resuelve la base con el JWT — el cliente no puede firmar ni corregir
una nota ajena. Corregir y borrar valen **solo mientras la nota siga SIN_PROCESAR**; en cuanto
una migración la convierte en `event` o `recobro` se congela, porque a partir de ahí hay un
número que salió de ella y cambiarla en silencio falsearía su origen (la 088 guarda además la
versión anterior en `texto_previo`). Esa conversión la hace siempre una migración, con
revisión humana: es lo que mantiene segura la puerta. **Si algún día hace falta que el cliente
escriba en `events` o `recobros`, no se hace extendiendo estas funciones**: es otra decisión y
necesita su propia revisión de seguridad.

**Frontend** (`web/`):
- La puerta es `web/middleware.ts` (sin sesión → `/login`; también refresca el token y
  copia las cookies renovadas a los redirects — no simplificarlo: perderlas revoca la
  sesión entera).
- Server components hacen fetch vía `readView()` (`lib/supabase.ts`) — un cliente por
  request (`@supabase/ssr` + React `cache()`) que firma con la sesión de las cookies y
  fuerza `cache: "no-store"` porque la Data Cache de Next servía respuestas viejas incluso
  con `force-dynamic`. No quitarlo.
- La lógica calculable vive como funciones puras testeadas en `lib/`: `headline.ts`
  (cascada del titular, ≤90 chars), `simulador.ts` (anualización run-rate: noche ×365/disp,
  mensual ×12/meses; overhead pool ×12/meses-del-año), `salud.ts` (semáforo forward),
  `waterfall.ts`, `mtd.ts`. Los tests (`web/tests/`) usan fixtures con datos reales de
  producción — al cambiar reglas de negocio, actualizar ambos.
- Client components solo donde hay interacción o Recharts (`Simulador`, charts, `NotaForm`).
- **Nada de web app manifest** (cicatriz del 19/08/2026): con un manifiesto enlazado, iOS
  abre el acceso de la pantalla de inicio en su `start_url` en vez de en la página desde la
  que se creó — el icono de "Anotar" caía en la portada. Darle a `/anotar` un manifiesto
  propio con el `start_url` correcto TAMPOCO lo arregló. Sin manifiesto, Safari graba la URL
  actual y funciona. Los iconos y los nombres salen de `appleWebApp` y de los
  `apple-icon.tsx` por ruta, que no dependen de él; van en la lista de rutas públicas del
  middleware porque iOS los pide al instalar y no siempre manda la cookie.
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

- **Al empezar cada sesión, mirar `v_notas_inbox`** (`estado = 'SIN_PROCESAR'`). Stag dicta
  los gastos en `/anotar` desde un icono del iPhone, en el momento en que ocurren; si nadie
  las convierte en `event`/`recobro`, quedan colgadas y el circuito no sirve de nada. Al
  procesarlas, dejarlas `REGISTRADA` con `resultado` apuntando a lo que salió, o `DESCARTADA`
  con el motivo. Una nota es un BORRADOR dirigido a Claude, no un registro contable: la
  transcripción no tiene que estar perfecta y no hay que pedirle que la corrija a mano —
  lo único que hay que verificar es el importe, contra el extracto.
- Ritual de cierre mensual: Stag sube extractos (Revolut/BBVA/tarjeta) a Google Drive
  (`Confisic → SAMAVI GLOBAL VISION SL → <año> → "MM - Mes" → BANCOS EXTRACTOS`); se
  concilian contra el modelo y las diferencias se cargan como `events`. Las reglas de
  clasificación permanentes (qué comercio va a qué propiedad) están en la memoria del
  proyecto — consultarla antes de clasificar.
- Los "xls" de BBVA son XLSX renombrados; los CSV de Drive llegan en base64
  (decodificar con `base64 -D` en macOS).
- MCP de PriceLabs conectado (precios dinámicos de los 4 listings): tiene herramientas de
  escritura — cambiar precios SOLO con confirmación explícita del usuario.
