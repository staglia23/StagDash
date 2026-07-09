# Prompt de planificación — Dashboard financiero Stag / Samavi (v1)

> Este documento es el **prompt** para una sesión de planificación técnica.
> Es el resultado de una ronda de scoping previa. Las decisiones de arquitectura
> marcadas como "cerradas" **no deben re-litigarse**: el plan las asume dadas.

---

## Rol y objetivo

Actuá como **arquitecto de software**. Diseñá un **plan de implementación paso a paso**
(fases, orden, entregables y checklist de validación) para la **v1** de un dashboard
financiero web para Stag Properties / Samavi Global Visión SL. No escribas todavía el
código final; entregá el plan y el esquema de datos.

**Objetivo de negocio:** conocer el **rendimiento neto (margen) por propiedad** para
evaluar rentabilidad y entender el estado del negocio.

---

## 🏛️ Pilares del sistema (requisitos no funcionales — PRIORIDAD MÁXIMA)

Estos tres pilares son **restricciones de diseño transversales**, no extras opcionales.
El plan debe demostrar, en cada fase, **cómo** los respeta.

### 1. Seguro
- El **token de Guesty** y la `service_role key` de Supabase **nunca** llegan al cliente:
  viven solo en **Supabase secrets** y/o en el lado servidor de Next.js (Edge Function / server components).
- **RLS activado en todas las tablas** desde el día 1, aunque hoy sea single-user. El front usa la
  `anon key` con políticas de **solo lectura** sobre las vistas del dashboard.
- Datos sensibles (IBAN, NIF de propietarios) aislados y con acceso restringido.
- Nada de credenciales en el repo (variables de entorno); HTTPS por defecto en Vercel;
  validación/sanitización de los datos que entran por la ingesta.

### 2. Escalable
- Esquema preparado para **más propiedades y más años sin cambios de estructura**
  (todo parametrizado por `listing` y fecha, no hardcodeado).
- Ingesta **idempotente e incremental** (upsert por `Reserva ID`; traer solo lo nuevo/modificado).
- Cálculo en vistas; prever **vistas materializadas + índices** si crece el volumen.
- Capas **desacopladas** (ingesta / cálculo / presentación) para sumar v2 —proyección, tesorería,
  multiusuario/roles (socias, gestoría)— sin reescribir lo anterior.

### 3. Responsive
- El dashboard debe verse y operar bien en **móvil, tablet y desktop** (Stag lo consulta desde el móvil).
- Layout fluido; KPIs, ranking y gráfico de tendencia legibles y usables en pantalla chica.
- Buen rendimiento percibido: carga rápida, estados de carga/error claros, datos cacheados.

---

## Contexto de negocio (resumen)

- Operador: Samavi Global Visión SL. **4 propiedades**, mismo edificio en Madrid (3) + 1 en Sevilla.
- **3 modelos de ingreso distintos** (esto es el corazón del cálculo):
  - **Subarriendo** (Alexander 4B_ALEX, Marechal 3G_MARE): margen = Ingreso Samavi − renta al propietario − costos directos.
  - **Titular / propia** (Nicasio 1A_NICA): margen = Ingreso Samavi − costos directos (sin renta a terceros).
  - **Comisión** (Jacobine 1A_JACO): Ingreso Samavi = **30,25% del bruto** (= 25% + IVA 21%); el resto es "Pasivo Madre" (propietaria no residente). Margen = Ingreso Samavi − costos directos.
- **Ya existe un modelo financiero maduro y correcto** en `STAG SAMAVI — Dashboard 2026.xlsx`.
  **El proyecto es PORTAR ese modelo a web, no reinventarlo.** Hojas relevantes:
  - `⚙️ Parámetros` = fuente única de verdad. Bloque A (atributos/costos por propiedad),
    Bloque B (gastos generales SAMAVI_GEN + fiscales/personal), Bloque C (eventos puntuales por propiedad+mes).
  - `_RAW_INGRESOS_2026` = export de Guesty ya normalizado: `CheckIn, CheckOut, Listing, Código Samavi,
    Status, Source, Noches, Bruto, Comisión Airbnb, Host Payout, Ingreso P&L Samavi, Pasivo Madre JACO, Reserva ID`.
  - Hojas por propiedad + `🏠 Consolidado` con el waterfall: Bruto → Ingreso Samavi → gastos → Margen €/%/€-noche,
    con estados **📊 real / 🔄 vivo / 🔮 forecast**.

---

## Decisiones de arquitectura CERRADAS (asumir dadas)

| Área | Decisión |
|------|----------|
| Fuente de datos | **Guesty Open API** |
| Base de datos central | **Supabase (Postgres)**. Se guarda el **RAW de reservas** (upsert por `Reserva ID`) |
| Motor de cálculo | **Vistas SQL en Postgres** (no en el front ni en el script de ingesta) |
| Ingesta | **Edge Function (Deno) + cron de Supabase (pg_cron)**; token Guesty en Supabase secrets |
| Frontend | **Next.js + React desplegado en Vercel**, consumo vía `@supabase/supabase-js` |
| Imputación de ingresos | **Devengo por noche** (prorrateo de cada reserva entre sus noches) |
| Definición de ingreso | **Host Payout** + **Ingreso Samavi por modelo** (CASE según `listings.model`) |
| Parámetros/costos | **Tablas editables en Supabase** migradas del Bloque A/B/C del Excel |

---

## Modelo de datos propuesto (a refinar en el plan)

Tablas fuente:
- `listings` — Bloque A: código, nombre, ciudad, banco, **modelo**, fecha inicio, renta base €/mes,
  comisión % bruto, IVA %, IRPF %, limpieza €/reserva, suministros/comunidad/MINUT/Akiles/amenities/
  PriceLabs/Guesty/extras/mobiliario financiado €/mes, propietario/NIF/IBAN.
- `reservations` — RAW Guesty: checkin, checkout, listing, código, status, source, noches, bruto,
  comisión canal, host_payout, ingreso_samavi (derivado por modelo), pasivo_madre, reserva_id (PK/upsert).
- `general_expenses` — Bloque B: SAMAVI_GEN recurrentes (€/mes) + parámetros fiscales/personal.
- `events` — Bloque C: (año, mes, propiedad, categoría [RENTA|OTROS|SAMAVI_GEN], concepto, importe).

Vistas (motor de cálculo):
- `v_pnl_mensual_propiedad` — waterfall mensual por propiedad con devengo por noche:
  Bruto, Comisión canal, Ingreso Samavi, Noches, Reservas, Ocupación %, ADR, RevPAR, ALOS,
  Limpieza, Suministros, Comunidad, Otros, Total gastos, Margen €, Margen %, €/noche neto.
- `v_consolidado` — agregado de las 4 propiedades (YTD real + totales).

---

## KPIs de la pantalla (referencia visual del cliente)

Margen Neto YTD, Ocupación portfolio YTD, ADR / RevPAR portfolio, **ranking de propiedades por margen**,
**tendencia de margen neto mensual**, detalle por propiedad.
(Beneficio post-IS, Caja Libre y proyección anual quedan **fuera de v1**.)

---

## Alcance v1 — IN / OUT

**IN:**
- Ingesta Guesty → `reservations` (Edge Function + cron, upsert idempotente).
- Seed de `listings` / `general_expenses` / `events` desde el Excel.
- Vistas SQL con el waterfall para meses **reales + vivo (mes en curso)**.
- Web (Next.js/Vercel): KPIs, ranking por margen, tendencia mensual, detalle por propiedad.

**OUT (v2+):**
- Proyección / forecast jun-dic (NICA 2025 + factores).
- Tesorería / Caja Libre (saldos − pasivos).
- Beneficio post-IS.
- Auth multiusuario / roles (socias, gestoría).
- Edición de parámetros desde la web (en v1 se seedea por SQL/manual).

---

## Cuestiones abiertas que el plan DEBE resolver

1. **Confirmar Open API** habilitada en el plan de Guesty (¿add-on?) y obtener `client_id`/`client_secret`.
2. **Mapeo de campos** Guesty API → `reservations`: qué objeto/campos de `money` corresponden a
   Bruto, Comisión de canal y Host Payout; cómo derivar Ingreso Samavi y Pasivo Madre por modelo.
3. **Denominador de ocupación**: noches disponibles = días del mes vs. menos bloqueos/estancias del propietario.
4. **Filtro de status**: qué estados cuentan (confirmed / checked-in / checked-out) y exclusión de canceladas.
5. **Backfill histórico** desde ene-2026: ¿reimportar `_RAW_INGRESOS_2026` del Excel o traer por API?
6. **Seed de parámetros/eventos** desde el Excel (proceso y formato).
7. **Zona horaria y criterio de fecha** para el devengo por noche cuando la estancia cruza de mes.
8. **Frecuencia del cron** y estrategia de **upsert idempotente** (evitar duplicados/re-cálculos).
9. **Secrets y seguridad**: token en Supabase secrets; RLS aunque sea single-user hoy.

---

## Entregables esperados del plan

- **Esquema SQL** (DDL de tablas + definición de vistas del waterfall).
- **Edge Function de ingesta** (estructura/pseudocódigo: auth OAuth2, paginación, upsert).
- **Estructura del proyecto Next.js** + componentes del dashboard (KPIs, ranking, gráfico de tendencia, detalle).
- **Orden de fases** con checklist de validación por fase (empezando por confirmar la API y un primer `SELECT` real).
- Para cada fase, **cómo se respetan los 3 pilares** (Seguro / Escalable / Responsive): decisiones concretas,
  no declaraciones genéricas (p. ej. qué políticas RLS, qué índices, qué breakpoints/estrategia responsive).
