# 02 — Prompt definitivo: Dashboard CEO v2 (Stag Properties / Samavi)

**Qué es este documento.** El prompt autocontenido para diseñar y construir la v2 del dashboard financiero de Samavi Global Vision SL: la herramienta de dirección del CEO. Contiene todo lo que necesitás — contexto, datos verificados, restricciones técnicas, principios de diseño y criterios de aceptación — sin depender de ningún otro archivo.

**Cómo usarlo.** Leelo entero antes de diseñar una sola pantalla. Las secciones 3 (lo que ya existe) y los datos que aparecen aquí son hechos verificados en producción a julio de 2026: no se re-litigan, no se "mejoran", no se reemplazan por supuestos. Si algo no está aquí, no lo inventes — está en la sección 8 como cuestión abierta o directamente fuera de alcance.

---

## 1. Rol y misión

Actuás como **product designer y arquitecto frontend senior**, especializado en herramientas de decisión para un único usuario ejecutivo en móvil.

**Tu misión:** que el CEO, mirando el teléfono durante 10 segundos, sepa si el negocio está bien o mal, por qué, y qué decisión tiene delante. Todo lo demás es secundario.

**Criterio rector:** si un número no cambia una decisión, no va. No hay comité que impresionar ni inversor que deslumbrar. Cada pixel se justifica por la pregunta que responde.

## 2. El usuario y sus decisiones

**Santiago "Stag" Tagliaferri**, administrador único de Samavi Global Vision SL. No tiene equipo financiero: él es el analista. Consulta desde el **móvil**. Se muda a Barcelona y quiere delegar operaciones dirigiendo por números. Tenía el hábito de un "Morning Check" diario en su Excel — el dashboard hereda ese ritual. Su mandato explícito: **simplicidad**.

### Las 5 preguntas del CEO

| # | Pregunta | Dato que la responde |
|---|----------|----------------------|
| 1 | ¿Cómo va el negocio hoy? | Margen neto YTD (25.005 EUR, 25,8%) + ingreso Samavi (96.780 EUR) |
| 2 | ¿Alguna propiedad me está sangrando? | Ranking de margen neto + break-even por propiedad |
| 3 | ¿Qué tengo ya vendido hacia adelante? | On-the-books (v_on_the_books) |
| 4 | ¿Hay algo con fecha límite que deba atender? | Alertas con countdown (v_alertas + listings.aviso_fecha) |
| 5 | ¿Qué pasa si muevo una palanca (renta, precio, ocupación)? | Simulador de escenarios |

### El caso de uso rey

**Renovar o renegociar el contrato de Alexander (4B_ALEX) antes del 01/09/2026.** Si Stag no avisa antes de esa fecha, el contrato se prorroga automáticamente 12 meses. Los datos duros (ubicación canónica; el resto del documento los referencia): ALEX consume el 94,5% de lo que ingresa (renta 9.516 + overhead 10.543 = 25.675 EUR de costes YTD), deja 1.503 EUR de margen neto (5,5%), opera con un colchón de ocupación de solo 5,6 pp (necesita 85,9%, tiene 91,5%) y acumula 4 meses en negativo. 3 de las 4 alertas vivas del sistema son suyas.

**Este caso es el test transversal de todo el diseño.** Cada pantalla, cada flujo y cada visualización se evalúa con una pregunta: ¿ayuda a Stag a decidir sobre Alexander antes del 01/09? El camino canónico es: portada → tap en la alerta ALEX → ficha ALEX con CTA "Simular renegociación →" above the fold → simulador con baseline precargado. Dos taps desde la portada. Ese flujo se diseña y se implementa primero.

## 3. Lo que YA existe y NO se reinventa

### Arquitectura (cerrada)

Guesty Open API → Edge Function `guesty-sync` (cron cada 3 h) → Supabase Postgres (proyecto `enlslwuokresrwbqpyeo`) → motor de cálculo = vistas SQL → Next.js 14 / React 18 / Recharts en Vercel (https://stag-dash.vercel.app). Repo privado `staglia23/StagDash`. El frontend usa la anon key y **solo lee vistas**: RLS bloquea las tablas crudas (datos de huéspedes, IBAN y NIF son inaccesibles desde el cliente). Esa frontera de seguridad no se toca.

### Reglas del motor (cerradas, validadas 1:1 contra el Excel histórico)

- **Ingreso por modelo:** titular (1A_NICA) y subarriendo (4B_ALEX, 3G_MARE) → `host_payout`; comisión (1A_JACO) → 30,25% del bruto, el resto es "Pasivo Madre".
- **Bruto** = fareAccommodation + fareCleaning. **Comisión de canal** = hostServiceFee (~18,8%). Ojo: las vistas no exponen hostServiceFee; lo que exponen es `comision_aparente` (bruto − ingreso Samavi) en `v_pnl_mensual_propiedad`.
- **Imputación por devengo/noche.** Canceladas **excluidas**.
- **Overhead SAMAVI_GEN** (~4.818,51 EUR/mes: sueldo de Stag, gestoría, software) prorrateado por peso en el Ingreso Samavi.

### Vistas disponibles

| Vista | Qué da |
|-------|--------|
| `v_kpis` | KPIs de portfolio + `last_sync` |
| `v_ranking_ytd` | Margen, ocupación, ADR, RevPAR por propiedad |
| `v_pnl_mensual_propiedad` | P&L mensual con costes directos, margen directo, `ocup_pct`, `adr`, `comision_aparente` |
| `v_pnl_neto_propiedad` | Lo anterior + cuota de overhead y margen neto |
| `v_trend_mensual` | Serie mensual de `ingreso_samavi`, `margen_directo` y `margen_neto` |
| `v_costes_ytd` | Desglose de costes por propiedad |
| `v_breakeven_ytd` | Ocupación necesaria vs real, colchón en pp |
| `v_canal_ytd` | Mix de canales |
| `v_on_the_books` | Ingreso futuro ya reservado |
| `v_alertas` | Alertas vivas (con `listings.aviso_fecha`/`aviso_nota`) |
| `v_reservation_nights` | Grano = una fila por noche, con id y source |

Tablas de apoyo: `listings`, `reservations` (RAW Guesty), `general_expenses`, `events`, `sync_state` — todas crudas, inaccesibles desde el cliente. **Restricción crítica:** las vistas están fijadas al año en curso vía `v_month_spine`, y además cuatro vistas (`v_ranking_ytd`, `v_costes_ytd`, `v_breakeven_ytd`, `v_canal_ytd`) llevan filtros `now()` propios — parametrizar el spine solo no basta (plan en §5.2; decisión pendiente en §8).

### Datos reales (15/07/2026)

691 reservas (2024-06-16 a 2027-03-02): confirmed 514, inquiry 87, canceled 80, declined 7, reserved 3 (3.206 EUR, todas futuras, hoy ignoradas por el motor), closed 3. Confirmadas por año: 2024=63, 2025=245, 2026=378, 2027=8. Canales: airbnb2, bookingCom, manual.

KPIs YTD: margen neto 25.005 EUR (25,8%), ingreso Samavi 96.780 EUR, ocupación 89% (755 noches), ADR 196 EUR, RevPAR 175 EUR.

Ranking margen neto YTD: NICA 11.883 (36,1%) · JACO 7.867 (57,9%) · MARE 3.751 (16,2%) · ALEX 1.503 (5,5%).

Break-even (necesaria vs real): ALEX 85,9% vs 91,5% · MARE 74,9% vs 91,5% · NICA 55,8% vs 92,5% · JACO 33,9% vs 80,7%.

## 4. Principios de diseño

### Los 3 pilares

1. **Seguro:** el frontend nunca toca tablas crudas; solo vistas/RPCs con GRANT. Nada de datos personales en el cliente.
2. **Escalable:** el motor vive en SQL, en un solo lugar. El cliente no reconstruye lógica de negocio (con la única excepción del simulador, que es hipotético por definición).
3. **Responsive móvil-primero:** se diseña para la pantalla del teléfono de Stag; el desktop es la adaptación, no al revés.

### Doctrina CEO

- **Respuesta primero.** La pantalla abre con la conclusión, no con los datos que la sustentan.
- **Todo número lleva su "¿y qué?".** 25,8% de margen sin contexto es ruido; con su comparación o consecuencia es información.
- **Progresión vistazo → diagnóstico → detalle.** 10 segundos para el estado, 1 minuto para la causa, 5 minutos para la reserva individual. Cada nivel es opcional y accesible por tap.
- **Cero vanity metrics.** La ocupación ya roza el techo en la mayor parte del portfolio (89% agregado; NICA, ALEX y MARE entre 91,5% y 92,5% — solo JACO, 80,7%, tiene recorrido): perseguirla degrada ADR. No se muestran métricas para sentirse bien.
- **Honestidad del dato.** `last_sync` visible siempre. Todo importe está etiquetado como **real** (devengado), **ya reservado** (on-the-books, futuro confirmado) o **simulado** (salida del simulador). Nunca se mezclan sin etiqueta.

### Reglas de visualización

- **Color = entidad, fijo:** cada propiedad tiene su color y lo conserva en todas las pantallas.
- **Nunca doble eje Y.** Si dos magnitudes no comparten escala, son dos gráficos.
- **Nunca color solo:** todo estado lleva icono + etiqueta textual ("▲ +5%", no solo verde). Signos explícitos (+/−). Contraste AA.
- **Dark y light** diseñados a propósito, no derivados por inversión.
- **Formato es-ES:** punto de miles, coma decimal, EUR.

## 5. Qué construir

### 5.1 Portada: Morning Check

La pantalla de apertura replica el ritual diario del Excel, mejorado:

- **Titular generado** (`buildHeadline`, función pura server-side, testeable): una frase de máximo 90 caracteres, formato `[dato] — [causa o consecuencia]`, verbo activo, cero adjetivos; en los casos 1 y 2 de la cascada nombra la propiedad causante. Cascada de prioridad: (1) alerta con fecha límite a **≤60 días** → el titular ES la alerta ("Quedan 48 días para avisar a ALEX — hoy consume el 94,5% de lo que ingresa"); (2) desviación de **ingreso MTD** vs mes anterior a igual día de **±10% o más** (umbral inicial, ajustable) → el titular es la causa. El margen no es computable a grano diario — los costes son mensuales y manuales — por eso el caso 2 compara ingreso, usando `v_reservation_nights`; (3) sin nada crítico → estado + dato fuerte, sin propiedad causante obligatoria. Compara siempre dentro del mismo año y contra break-even; **nunca** YoY de portfolio.
- **Tira de KPIs:** margen neto, ingreso, ocupación, ADR — cada uno con sparkline mensual. Margen e ingreso salen de `v_trend_mensual`; ocupación y ADR **no** están en esa vista: se agregan desde `v_pnl_mensual_propiedad` (`ocup_pct`, `adr`) o se amplía `v_trend_mensual` (añadido al plan SQL, §9.4).
- **Stack de alertas y señales** (máximo 3 visibles, overflow "+N más"): **alerta** = tiene fecha límite, se muestra con countdown, consecuencia en una línea y acción enlazada; **señal de riesgo** = condición persistente sin fecha (colchón de 5,6 pp, meses en negativo), visualmente diferenciada, sin countdown. Orden: alertas por fecha límite ascendente, señales después.
- **Resumen on-the-books** y **acceso directo al simulador** (1 tap).

### 5.2 Interactividad

- **Selector de periodo.** ⚠️ Requiere trabajo de backend primero: las vistas están fijadas al año en curso (spine + 4 filtros propios). El plan recomendado es crear funciones SQL parametrizadas (`f_ranking`, `f_costes`, `f_breakeven`, `f_canal` sobre un `f_spine(desde, hasta)`) expuestas por RPC, y redefinir las vistas actuales como wrappers para no romper el front. No filtrar en cliente: el prorrateo del overhead en `v_ranking_ytd` se hace a nivel YTD y no se reconstruye sumando meses sin duplicar el motor en JS. Hasta que existan las f_*, el selector ofrece solo meses de 2026 + "YTD", con la etiqueta "2026" explícita en el UI; con un mes seleccionado, los componentes servidos por vistas YTD-only (ranking, bullet de break-even, mix de canal, desglose de costes) caen a YTD con etiqueta "YTD 2026" visible — solo el P&L mensual, el heatmap y las tendencias respetan el mes.
- **Selector de propiedad** (las 4 + "Todas"). Estado en `searchParams` (`?p=ALEX&m=2026-07`) como única fuente de verdad: URLs compartibles, back del móvil siempre funcional, sin modales.
- **Drill-down por URL:** portfolio (`/`) → propiedad (`/p/[id]`) → mes (`/p/[id]/[mes]`) → lista de reservas del mes (agregando `v_reservation_nights` por id: fechas, noches, ingreso, canal), con fila expandible por reserva vía `?r=[id]`. No existe pantalla de reserva individual: no hay PII que mostrar por diseño. Breadcrumb sticky.
- **Toggle margen directo / margen neto** en toda vista de rentabilidad. Es más que cosmética: el margen directo (sin overhead prorrateado) es el margen de contribución, y cambia la lectura de ALEX — el overhead no desaparece si soltás la propiedad, se redistribuye entre las otras 3. El toggle convierte "ALEX gana solo 5,5%" en una pregunta mejor: ¿cuánto aporta realmente a cubrir el overhead común?

### 5.3 Visualizaciones

- **Waterfall de margen** (Recharts, barra base transparente): bruto → −comisión aparente (bruto − ingreso Samavi, que es lo que las vistas exponen) → ingreso Samavi → −costes directos por línea → margen directo → −cuota overhead → margen neto. Para 1A_JACO el primer escalón no es la comisión de canal: su ingreso Samavi es el 30,25% del bruto y la diferencia incluye el Pasivo Madre — se etiqueta como caso aparte. Todos los escalones existen en `v_ranking_ytd` + `v_costes_ytd`; etiquetas siempre visibles, sin depender del tooltip en móvil.
- **Bullet chart de break-even:** por propiedad, barra gris = ocupación necesaria, barra de color = real, colchón en pp como texto. Ordenadas por colchón ascendente: ALEX siempre arriba.
- **Heatmap de ocupación:** grid CSS de calendario, celda por día desde `v_reservation_nights`, escala de 3 pasos + letra del canal dentro de la celda. Tap en celda → expande la fila de esa reserva en la lista del mes (`?r=[id]`).
- **Sparklines:** SVG inline con hasta 12 puntos — los meses transcurridos del año en curso (7 a jul-2026; los futuros se omiten, no se muestran vacíos). Margen e ingreso desde `v_trend_mensual`; ocupación y ADR desde `v_pnl_mensual_propiedad` (§5.1). Recharts es overkill aquí.
- **Mix de canal** (`v_canal_ytd`): debe hacer visible la anomalía JACO (ver §6).

### 5.4 Simulador de escenarios — la funcionalidad diferencial

Client component con baseline pasado como props desde el server (`v_costes_ytd`, `v_breakeven_ytd`, `v_ranking_ytd`, `v_pnl_mensual_propiedad`). **Cálculo 100% en cliente**: cero queries, cero escrituras, respuesta instantánea.

- **Palancas (sliders con valor numérico editable), según modelo de ingreso:** subarriendo (ALEX, MARE) → renta mensual, ADR, ocupación, comisión de canal; titular (NICA) → ADR, ocupación, comisión de canal (no paga renta); comisión (JACO) → ADR y ocupación (su ingreso es el 30,25% del bruto; la renta no aplica). Botón "Volver a hoy" resetea al baseline real.
- **Convención de anualización fijada:** año calendario 2026, extrapolando el run-rate YTD. Todo importe anual lo declara ("proyección 2026 a ritmo actual").
- **Prorrateo de overhead:** al mover el ingreso simulado de una propiedad, los pesos del prorrateo (por peso en Ingreso Samavi) se **recalculan** para las 4, y el efecto colateral sobre las otras 3 se muestra, no se oculta.
- **La respuesta es UNA frase**, con la misma gramática del titular, más un bullet chart que se mueve en vivo: *"Con renta X y ADR Y, ALEX deja Z EUR/año de margen neto (colchón N pp)"* — X, Y, Z y N salen del cálculo sobre el baseline real, nunca de valores precargados inventados. La frase reporta **margen neto**; con el toggle en directo, reporta margen directo y lo dice.
- Si la simulación cruza a 2027, muestra la advertencia estática del gotcha ene-2027 (§8.4); nunca lo "corrige" en cliente — los eventos de renta viven en `events`, tabla cruda inaccesible.
- Todo output del simulador va etiquetado **"simulado"**, visualmente distinto del dato real.
- La ficha de ALEX (a la que lleva su alerta) tiene la CTA "Simular renegociación →" above the fold, que abre el simulador con su baseline precargado: 2 taps desde la portada. Ese es el cierre del flujo del caso rey (§2).

### 5.5 Comparativa YoY — solo like-for-like (diferida a v2.1)

**Diferida a v2.1:** requiere datos 2025, hoy inaccesibles porque todas las vistas — incluida `v_trend_mensual` — están fijadas al año en curso. Se desbloquea con la parametrización SQL del §5.2. Las reglas quedan fijadas desde ya:

Un YoY de portfolio sería engañoso: el negocio pasó de 1 a 4 propiedades. El diseño lo prohíbe activamente.

| Propiedad | Opera desde | ¿Comparable YoY? |
|-----------|-------------|------------------|
| 1A_NICA | 2024-06 | Sí |
| 1A_JACO | 2025-06-21 | Parcial (solo meses activos en ambos años) |
| 4B_ALEX | 2025-10-02 | No |
| 3G_MARE | 2025-12-06 | No |

Además: los costes solo están cargados para 2026 → **YoY de margen NO fiable en ningún caso**; YoY de ingreso, ocupación, ADR y RevPAR sí. Toda vista YoY muestra esta tabla o su advertencia equivalente, y las propiedades no comparables aparecen con flag explícito, nunca silenciadas ni promediadas.

### 5.6 Ficha por propiedad, profundizada

P&L waterfall del periodo, 12 mini-barras mensuales tappables, break-even bullet, heatmap del mes, mix de canal, alertas y señales propias, y la CTA al simulador con el baseline de esa propiedad. La ficha de ALEX es la referencia de diseño: si funciona para decidir su renovación, funciona para todas.

## 6. Verdades del negocio que el diseño debe hacer imposibles de ignorar

1. **ALEX está al filo** (datos canónicos en §2: 94,5% de costes sobre ingreso, colchón 5,6 pp, 4 meses en negativo, fecha límite dura 01/09/2026). El diseño no puede permitir que Stag abra la app y no lo vea.
2. **Dependencia de Airbnb: ~97% del ingreso.** Y la anomalía dentro de la anomalía: JACO es 100% Airbnb y cero Booking.com siendo la **única** propiedad con licencia turística, en Sevilla, donde Booking pesa mucho. NICA está al 94,4% Airbnb (Booking 882 EUR, directo 950 EUR). Es una **señal de riesgo permanente** del mix de canal — no una alerta del stack (no tiene fecha límite): el gráfico de mix la hace visible siempre.
3. **El overhead es el mayor coste del negocio.** ~4.818,51 EUR/mes. Es el mayor coste individual de NICA (12.769 EUR > 8.264 de directos) y casi el único de JACO (5.267 EUR). Por eso el toggle directo/neto del §5.2 es obligatorio: sin él, el prorrateo distorsiona qué propiedad "gana" y cuál "pierde".
4. **Los costes son manuales.** Guesty solo trae reservas; `general_expenses` y `events` se cargan a mano. Un mes sin cargar costes muestra márgenes falsos. El diseño expone la frescura del dato: `last_sync` y un indicador "costes cargados hasta [mes]" — que hoy ninguna vista expone (`general_expenses` es cruda): se añade a `v_kpis` o a una `v_freshness` en el plan SQL (§9.4).

## 7. Alcance

**IN (v2):**
- Portada Morning Check con titular generado.
- Selectores de periodo (previa parametrización SQL) y propiedad; drill-down hasta la fila de reserva.
- Toggle margen directo/neto.
- Waterfall, bullet break-even, heatmap, sparklines, mix canal.
- Simulador de escenarios client-side.
- Fichas por propiedad profundizadas.
- Sistema de diseño dark/light, accesible, es-ES.

**Diferido a v2.1 (por simplicidad y por datos):**
- Curva de pace (on-the-books vs misma foto del año previo): requiere una vista nueva `v_pace` — `reservations` es cruda e inaccesible, el campo es `created_at`, y reconstruir la foto pasada debe especificar cómo trata las 80 canceladas. No alimenta el caso rey ni las 5 preguntas.
- Comparativa YoY like-for-like (§5.5): requiere parametrización SQL y datos 2025.

**OUT (explícitamente):**
- Login (Supabase Auth): pendiente conocido, **prerequisito antes de compartir la URL**, pero no parte de este diseño.
- Pantalla de edición de costes/eventos: acordada como proyecto aparte.
- Cualquier escritura en base de datos desde el dashboard.
- Multi-usuario, roles, exportaciones, informes PDF.
- Targets/objetivos: no existen definidos; no se inventan (ver §8).
- Integraciones nuevas (pricing dinámico, channel manager, etc.).

## 8. Cuestiones abiertas

1. **Status `reserved`:** 3 reservas futuras por 3.206 EUR que el motor hoy ignora. Decidir si entran al on-the-books (recomendación de los análisis previos: tratarlas como "ya reservado" con descuento por riesgo de cancelación, calibrado con las 80 canceladas históricas). Hasta decidirlo, mostrarlas separadas y etiquetadas, nunca sumadas en silencio — lo que exige SQL nuevo (columna de status en `v_on_the_books` o vista aparte, §9.4): `v_on_the_books` hoy las ignora y `reservations` es inaccesible.
2. **Parametrización del periodo:** el pin al año en curso vive en `v_month_spine` **y** en filtros propios de 4 vistas. La ruta recomendada es RPC (§5.2). Sin esto, el selector queda limitado a 2026 y el YoY (§5.5) queda bloqueado.
3. **Criterio de overhead por defecto:** ¿la vista por defecto muestra margen neto (prorrateado) o directo (contribución)? Afecta directamente cómo se lee ALEX. Decisión de producto pendiente; el diseño debe soportar ambas.
4. **Gotcha ene-2027:** la renta de ALEX volvería a 1.414,22 EUR en enero porque la subida a 1.614,80 está cargada solo como evento nov–dic 2026. Los eventos viven en `events` (tabla cruda, inaccesible desde el cliente): cualquier proyección o simulación que cruce el año **advierte** con texto estático, no corrige.
5. **Targets inexistentes:** no hay objetivos definidos. El break-even es el único umbral objetivo disponible para semaforizar; no se fabrican metas.

## 9. Entregables esperados

1. **Mapa de pantallas y wireframes móviles** (portada, portfolio, ficha propiedad, mes/reservas con fila expandible por reserva, simulador), con el flujo ALEX marcado como camino crítico. YoY: diferido a v2.1.
2. **Especificación del titular:** cascada de prioridad completa, umbrales (fecha límite ≤60 días; desviación de ingreso MTD ±10%, ajustable), gramática, y casos de test (incluido el caso ALEX a 48 días del 01/09).
3. **Especificación del simulador:** fórmula exacta en cliente, mapeo de cada input a su vista de origen, sliders por modelo de ingreso, convención de anualización (año calendario 2026 a run-rate YTD), prorrateo de overhead recalculado con pesos simulados mostrando el efecto en las otras 3, margen de salida (neto por defecto, coherente con el toggle) y estados etiquetados como simulados.
4. **Plan SQL** con estrategia de migración sin ruptura del front: funciones RPC parametrizadas + vistas wrapper (§5.2); "costes cargados hasta" en `v_kpis` ampliada o `v_freshness`; status `reserved` expuesto en `v_on_the_books` o vista aparte; ocupación y ADR mensuales para sparklines (ampliar `v_trend_mensual` o agregar `v_pnl_mensual_propiedad`); y, para v2.1, `v_pace` sin PII con su aproximación especificada.
5. **Sistema de diseño:** tokens de color por entidad, tipografía, dark/light, componentes (KpiStrip, AlertCard, Bullet, Heatmap, Sparkline, Waterfall).
6. **Plan de implementación por fases**, con la fase 1 = flujo portada → alerta → ficha ALEX → simulador, entregable antes de agosto de 2026.

## 10. Criterios de aceptación

- [ ] La portada responde las preguntas 1–4 del §2 sin scroll (viewport de referencia: 390×844) y da acceso al simulador (pregunta 5) en 1 tap.
- [ ] El titular se genera solo, tiene ≤90 caracteres, nombra la propiedad causante en los casos 1–2 de la cascada y es texto real (copiable, legible por screen reader).
- [ ] **Test del caso rey:** desde la portada, Stag llega al simulador con el baseline de ALEX precargado en ≤2 taps, y obtiene la respuesta a "¿qué pasa si renegocio la renta?" en una frase.
- [ ] Toda alerta muestra fecha con countdown, consecuencia en una línea y una acción enlazada; las señales de riesgo sin fecha se muestran diferenciadas de las alertas, nunca con countdown ni mezcladas sin distinción.
- [ ] Ningún número aparece sin comparación o consecuencia adjunta.
- [ ] `last_sync` y "costes cargados hasta" visibles; todo importe etiquetado real / ya reservado / simulado.
- [ ] No existe ningún YoY de portfolio ni YoY de margen; cuando el YoY se implemente (v2.1), toda comparativa mostrará el flag de comparabilidad por propiedad.
- [ ] El simulador funciona sin ninguna llamada de red tras la carga inicial.
- [ ] Ningún gráfico usa doble eje Y; ningún estado se comunica solo por color; contraste AA en dark y light; targets táctiles ≥44 px.
- [ ] Todos los números en formato es-ES.
- [ ] El frontend solo consume vistas/RPCs con GRANT; cero acceso a tablas crudas.
- [ ] Todo dato mostrado es trazable a una vista del §3 o a una vista/RPC definida en el plan SQL (§9.4); ningún número del diseño final está inventado.
- [ ] El toggle directo/neto está presente en toda vista de rentabilidad y cambia todos los gráficos afectados de forma consistente.
- [ ] Una persona que no conoce el negocio entiende el estado general en 10 segundos mirando la portada. Ese era el encargo.
