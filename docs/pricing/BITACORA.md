# Bitácora de pricing — qué se probó y qué pasó

Registro cronológico, **append-only**: nunca se reescribe una entrada pasada, se añade la
corrección abajo. Cada experimento se cierra con su resultado medido; un experimento sin
resultado medido es una anécdota, no un aprendizaje.

Las reglas que salen de acá suben al [PLAYBOOK](PLAYBOOK.md). El estado vigente vive en
[ESTADO.md](ESTADO.md).

**Formato de entrada**

```
## AAAA-MM-DD · Título
**Hipótesis** · qué creíamos y por qué
**Aplicado** · qué se tocó exactamente (piso, fechas, valores)
**Resultado** · medido, con fecha de medición. "Sin medir" también es un estado válido.
**Aprendizaje** · qué regla nace o se corrige (→ PLAYBOOK §x)
```

---

## 2026-08-02/03 · Primer análisis de mínimos y rebaja de agosto

**Hipótesis** · Agosto tiene demasiadas noches libres; rebajar las noches concretas que quedan
vacías compite contra 0 €, no contra el ADR.
**Aplicado** · Suelos por fecha en las 26 noches libres (MARE 95, ALEX 115, NICA 130, JACO 135)
conservando los overrides porcentuales −15/−20 % que ya tenía puestos Stag; min-stay 3→2 donde
correspondía. Publicado y verificado el 03/08 09:12 UTC.
**Resultado** · El pickup no se midió de forma aislada: dos días después se descubrió que la
configuración estaba mal montada (ver 05/08), así que el experimento quedó **contaminado**.
**Aprendizaje** · (1) Recalcular no es publicar → PLAYBOOK §2.4. Stag detectó que Airbnb seguía
con precios viejos porque veía precio_viejo × promo. (2) Un experimento cuya configuración no se
verificó al último eslabón no se puede leer.

---

## 2026-08-05 · Corrección: el doble descuento y los suelos rebajados

**Hipótesis** · (Descubrimiento, no hipótesis.) Los overrides porcentuales de PriceLabs se suman
al descuento nativo de Airbnb, y además los suelos por fecha del 03/08 estaban **por debajo** del
`min` propio de cada anuncio.
**Aplicado** · Borrados todos los overrides de precio; conservados solo los de `min_stay`.
Precios restaurados: NICA 150–155, JACO 155, ALEX 129, MARE 99.
**Resultado** · Quedó un experimento abierto: "si en 4–5 días el pickup no responde, bajar los
suelos". Se superseded el 07/08 antes de completarse.
**Aprendizaje** · Regla madre del proyecto: **el descuento va en Airbnb, el suelo en PriceLabs**
→ PLAYBOOK §2.1. Y: vender al mínimo el 67–100 % de las noches mientras se le gana al mercado por
20–40 puntos es síntoma de suelo mal calibrado, no de precio alto → §2.5.

---

## 2026-08-06 · Marco de decisión por noche y calibrado quirúrgico

**Hipótesis** · No todas las noches vacías están vacías por lo mismo. Solo hay que bajar donde el
mercado va por detrás de su propio ritmo del año pasado.
**Aplicado** · ALEX 11/08 →119, 12/08 →115, 13/08 →123; MARE 17 y 18/08 →105. El resto sin tocar.
**Resultado** · **El dato que mató la tesis de "bajar para llenar"**: Marechal en percentil 22–30
de precio hace 77 % de ocupación; Nicasio en p70–76 hace 77 % también. Mismo edificio, mismo comp
set, cuartil opuesto → elasticidad ~0 en ese rango. Además las 12 noches libres caían **todas** de
domingo a jueves, ninguna en viernes/sábado: si fuera precio, los findes también estarían vacíos.
**Aprendizaje** · El percentil se calcula sobre el precio que ve el huésped → PLAYBOOK §4.2.
La elasticidad en p22–p76 es ~0 → §4.3.

---

## 2026-08-07 · Test de bajada agresiva (48 h), pedido por Stag

**Hipótesis** · (De Stag) bajar el precio final que ve el huésped hace caer reservas ya.
Objeción registrada: el mercado va por delante del año pasado y la elasticidad medida es ~0.
Se probó igual — es un test legítimo y el coste máximo estimado era ~190 €.
**Aplicado** · Precio final objetivo: MARE 79 € · ALEX 90 € · NICA 119 €, vía precios fijos
93 / 106 / 140 (× 0,85 del descuento nativo). Push de Stag a la 01:49–01:56.
**Resultado (medido 07–09/08)** ·
- NICA vendió 11→14/08 a las 8 h del push, ADR alojamiento 144 €/noche. **⚠️ Esta reserva se
  canceló el 12/08** (ver entrada del 13/08): el resultado que se comunicó como éxito no se
  sostuvo.
- ALEX vendió 09→11/08 a 90,10 €/noche = el precio exacto del test. **Válido.**
- MARE: **cero** reservas de agosto en 48 h estando en percentil ~10 del barrio, mientras vendía
  septiembre (228,60 €/noche) y octubre (184 €/noche) sin ningún descuento.
**Aprendizaje** · (1) La cadencia la marca la perecibilidad, no el ritual → PLAYBOOK §5.2.
(2) Se infirió un −20 % de descuento nativo en Marechal a partir de UNA observación y se publicó
99 € en vez de 93 €; Stag lo corrigió el mismo día → §3.1 y §5.1.
(3) La tesis "el problema de Marechal no es precio" queda **reforzada**, no probada: falta
descartar disponibilidad y visibilidad.

---

## 2026-08-09 · Plan de 5 movimientos (aprobado: "activa todo")

**Hipótesis** · Subir donde no es perecedero, mantener donde sí, y atacar Marechal por
visibilidad en vez de por precio.
**Aplicado** · NICA 14–15 →150 fijo y noche 28 liberada con min-stay 1; MARE 22 →115 y 23–25 →105
(con escalón T−7 a 93); ALEX 11–13 quedan a 106; JACO 11–13 suelo 155→135 (borrando un −20 %
porcentual heredado que el merge había conservado). Monitor diario reconfigurado como guardián
del plan, con los escalones y la regla de plan B.
**Resultado (medido 13/08)** ·
- **JACO 11–13: VENDIÓ** a 109,23 €/noche. Aflojar el suelo funcionó: el año pasado esas noches
  se habían vendido a 107–119 €.
- **NICA finde 14–15: VENDIÓ**, pero a 109,15 €/noche de alojamiento, no a los 150 publicados
  (~127 esperados con el −15 %). **Sin explicar** — hay que revisar si el push llegó, si actuó la
  curva de último minuto de PriceLabs, o si el precio se pisó el 12/08.
- **NICA 28** (la noche huérfana liberada con min-stay 1): **sigue libre** a 13/08.
- **MARE 22–25 y 16–18: cero reservas.**
**Aprendizaje** · Pendiente de cerrar. El plan dejó de estar vigente el 12/08 sin que el sistema
lo detectara (ver entrada siguiente).

---

## 2026-08-12 · Edición manual no registrada (hallazgo, no experimento)

**Hipótesis** · Ninguna: se descubrió el 13/08 al leer el estado real antes de analizar.
**Aplicado** · Alguien (edición manual desde la UI: campo `reason` vacío, `updated_at`
2026-08-12 08:15 UTC) reemplazó el plan del 09/08 en Marechal: 16–18 pasaron de 93 a **84 €**, y
22–25 perdieron el precio fijo quedando con `min_price` 119 + `min_stay` 2 → publican **119 €**.
**Resultado** · Durante 24 h el análisis y el monitor estuvieron razonando sobre un estado que ya
no existía. Ninguna de las dos configuraciones vendió.
**Aprendizaje** · El `reason` es la firma forense → PLAYBOOK §2.6. Y: **nunca afirmar qué está
publicado sin haberlo leído en la misma sesión** → §1.1. El monitor diario debe comparar estado
vivo contra estado intencionado y gritar cuando difieren.

---

## 2026-08-13 · Corrección del resultado del test + diagnóstico de Marechal

**Corrección importante** · La reserva de Nicasio 11–14/08 a 144 €/noche, comunicada el 09/08 como
la prueba de que el test funcionaba, **se canceló el 12/08**. Las noches 11–12 se revendieron a
93,50 €/noche. El balance real del test cambia: de las dos ventas que lo sostenían, solo la de
Alexander (90,10 €/noche) sigue en pie.
→ PLAYBOOK §5.4: una reserva no es dinero hasta pasar su ventana de cancelación.

**Estado de agosto al 13/08** · Libres: NICA 13 y 28 · ALEX 13 · MARE 13, 16, 17, 18, 22, 23, 24,
25, 30 · JACO 13, 18–20 (bloqueo de viaje) y 28.

**Novedad estructural** · Marechal **ya tiene Booking.com conectado** (listing 17046956); no lo
tenía el 09/08. Su ocupación a 30 días subió de 67 % a 80 % (mercado 53 %) y el pickup de los
últimos 15 días es de 4 reservas — pero ninguna de agosto.

**Diagnóstico de Marechal (7 agentes: 4 lentes + 3 verificadores adversariales)** · La anomalía
`demanda='Unavailable'` NO era ruido de datos. Resultados:

1. **Las noches 22–25 están BLOQUEADAS**, no libres. `pricelabs_prices.booking_status='Blocked'`
   en las cuatro (verificado directamente), y la salud del anuncio reporta "5 blocked dates".
   Marechal es el **único** piso de Madrid con bloqueos (NICA y ALEX: cero).
   ⚠️ **Contradicción sin resolver**: el calendario de PriceLabs marca 4 noches bloqueadas, pero
   el feed de reservas del PMS solo declara una entidad de bloqueo (`6a7c472c1c2e60e15e24b19a`,
   22→23/08, creada el 12/08). Hay una segunda entidad (`6a6a6b1d77ed28e32b2fc91b`, 22→24, creada
   el 29/07) que llega con `booking_status='available'` y **con huésped asociado**. Hasta abrir
   Guesty con los ojos, lo recuperable son entre 1 y 4 noches — **no dar los 369 € por buenos**.
2. **El error que explica el cero del 10 al 12/08**: tres overrides cargados como **porcentaje**
   (99, 149, 129) publicaron esas noches a **190–281 €**, 1,6–1,8× el p90 del barrio, justo en los
   únicos días en que el bloque estuvo abierto. → PLAYBOOK §2.7 (nueva) + `max_price` como
   cortafuegos.
3. **Las noches 16–18 están sanas y el precio ya está agotado como palanca**: a 84 € publicados el
   huésped ve 71,40 € = percentil 16–19 del barrio, por debajo del p25 (79,8) y muy por debajo de
   la mediana **reservada** (94,6–104,1). Cero *inquiries* para esas fechas → no hay demanda
   latente perdiéndose al final del embudo.
4. **La tesis "es visibilidad" queda sin sustento**: 87 reservas confirmadas desde dic-2025
   descartan penalización por anuncio nuevo, y PriceLabs marca a Marechal como
   *outperforming the market* (ocupación agosto 73,7 % vs 63 % del mercado). El déficit real está
   concentrado en **ventana corta entre semana** (MPI 0,78 a 7 días; 1,41–1,50 a 15–30 días).
5. **Booking.com: el "rateplans vacío" no probaba nada** — Nicasio devuelve lo mismo y vendió
   **10 noches de agosto** por ese canal, incluidas las 16–22/08, exactamente las que Marechal
   tiene vacías. La demanda existía en el mismo edificio y entró por el canal que Marechal no usa.
6. **Correcciones de los verificadores que cambian decisiones**: bajar la limpieza a 41 € habría
   costado ~2.365 €/año (→ PLAYBOOK §3.3); el valor esperado realista de las 7 noches es ~110 €,
   no 493–584; y **noviembre está 55,88 puntos bajo el equilibrio** con 24 noches libres — 3× el
   agujero de agosto, decidiéndose ahora porque Marechal vende con 80 días de mediana.

**Deuda técnica detectada** · (a) `guesty-sync` no ingesta bloqueos → PLAYBOOK §2.8; (b)
`f_pricelabs_oportunidades` (migración 072, línea 66) filtra por `not no_vendible` pero no excluye
`booking_status='Blocked'`: hoy no se cuela ninguna fila por casualidad (esas noches tienen
`precio_usuario` null), pero una noche bloqueada con override de precio aparecería en /precios como
euros sobre la mesa que no existen; (c) el motor no captura la comisión de Booking.com (las 3
reservas de Nicasio entran con comisión efectiva 0 %) → cada euro de ese canal infla el margen
15–18 % y el ADR de Booking parece mejor que el de Airbnb cuando corregido queda por debajo.

---

## 2026-08-14 · Stag resuelve el enigma: el bloqueo era suyo. Y rechaza el techo de precio

**Dos aclaraciones del CEO que cierran el diagnóstico de ayer:**

1. **Las noches 22–25 de Marechal están rotuladas "Control" en Guesty: son su viaje de
   inspección.** Lo mismo Jacobine 18–20/08. El bloqueo es deliberado y no se toca.
   → **Los 369 € "recuperables" no existían.** Agosto de Marechal queda con **3 noches vendibles
   reales** (16, 17 y 18), no 7. La recomendación nº 1 del plan del 13/08 (abrir Guesty y
   desbloquear) queda **anulada**, y con ella se cae la mitad del valor esperado que se le
   atribuía al mes.
   → Regla permanente en PLAYBOOK §2.8. Nace de un diagnóstico de 7 agentes que se podría haber
   evitado leyendo un rótulo. **La causa raíz no fue el análisis: fue que nadie había escrito
   nunca qué significan los rótulos del calendario.** Eso es exactamente lo que estos documentos
   existen para arreglar.

2. **Rechaza poner `max_price`** en PriceLabs: no quiere topes que aten al algoritmo. A cambio,
   la vigilancia de precios irrisorios o disparatados pasa a ser **obligación diaria mía**, con
   bandas de alarma explícitas → PLAYBOOK §5.7. El monitor diario incorpora la guardia.

**Lo que queda vivo del plan del 13/08** · Suelo duro (16–18 a 92 €, sin bajar más), la guardia
de precios en lugar del techo, activar Booking.com en Marechal arreglando antes la captura de
comisión del motor, y el giro a noviembre (24 noches libres, 55,88 pp bajo equilibrio).

**Resultado pendiente de medir** · Las tres noches de 16–18 y, sobre todo, el plan de noviembre.

---

## 2026-08-14 · Jacobine 2027: suelos cargados para Semana Santa y Feria (APLICADO)

**Hipótesis** · La ventana de reserva de 180 días obliga a Jacobine a vender sus dos semanas más
caras en pánico. En 2026, vender con 43–58 días dio 604–635 €/noche y vender con 0–4 días dio
234–369 €; la Madrugá se vendió a 234,40 € con CERO días y la noche del alumbrao quedó vacía.
Poniendo suelos ANTES de abrir el calendario, se captura el segmento anticipado sin riesgo de
malvender.

**Aplicado** · 23 overrides de `min_price` (tipo `fixed`, EUR) en el listing de Jacobine, más una
corrección de `min_stay`. Ninguno lleva `price` fijo: son **suelos**, dejan que PriceLabs suba.

| Bloque | Fechas | Suelos publicados |
|---|---|---|
| Semana Santa | 21–28/03/2027 | 500 · 500 · 500 · 545 · **620** · 600 · 520 · 445 |
| Feria (probable) | 12–18/04/2027 | **665** · 665 · 665 · 620 · 620 · 575 · 445 |
| Feria (cobertura) | 19–25/04/2027 | 500 ×6 · 445 |
| Corrección min-stay | 11/04/2027 | 5 → **3** (domingo previo sin evento) |

**LA CALIBRACIÓN — el paso que casi se me escapa** · Los suelos publicados NO son el precio
objetivo: son **objetivo ÷ 0,90**, porque el descuento de **reserva anticipada de Airbnb (−10 %,
≥3 meses)** está activo y muerde toda reserva hecha desde ahora hasta ~21/12/2026. Sin calibrar,
un suelo de 450 € habría dejado al huésped pagando 405 €.
Verificado antes de aplicar: **ninguna de las 11 reservas de las fiestas de 2026 llevó descuento**
(`fareAccommodation` = `fareAccommodationAdjusted`, `fareAccommodationDiscount` = 0 en las once),
así que las cifras de 2026 son limpias y comparables con el *objetivo*, no con el suelo publicado.
→ PLAYBOOK §3.1 y §3.2.

**Chequeos previos** (checklist del PLAYBOOK §1, los cuatro pasaron):
1. Overrides preexistentes en el rango: **cero** → sin riesgo de merge silencioso (§2.3).
2. Descuentos nativos: calibrado ÷0,90 (arriba).
3. Herramienta correcta: `min_price`, no `price` fijo — se quiere suelo, no techo (§2.2).
4. `max` del anuncio = null → nada limita hacia arriba.
5. Verificación posterior: releído el rango 01/01→31/12/2027 completo, 23 overrides correctos.

**Resultado — VERIFICADO el mismo día (14/08, 14:50)** · Stag abrió la ventana en Guesty a 365
días minutos después de cargarse los suelos. Verificación en vivo con test de control:
- Las noches "Control" de agosto (18–20/08) **siguen `Blocked`** con dato de las 12:47 UTC →
  el dato es fresco y los bloqueos deliberados no se tocaron. ✓
- **Semana Santa 2027 entera con `booking_status` vacío (= disponible)** y demanda leída en vivo:
  "High Demand" del 20 al 28/03 — antes decía "Unavailable". ✓
- Suelos mordiendo: Madrugá 620 (suelo exacto), y el algoritmo POR ENCIMA del suelo donde ve
  demanda: 21/03 a 633 (suelo 500), 26/03 a 665 (suelo 600), alumbrao a 698 (suelo 665). ✓
- `last_date_pushed` **12:29 UTC** = 5 minutos después de cargarse los suelos → hubo push al
  canal con los suelos ya puestos. Mi refresh posterior (12:47) recalculó fino; el sync diario
  de mañana (~06:50) empuja la última pasada. ✓
- Falta solo el eslabón final: búsqueda en Airbnb como huésped (pendiente de Stag).

**Escalones acordados** · T−90 (dic-26): si el pickup es 0, bajar **min-stay** antes que precio.
T−45: bajar el suelo un escalón (~15 %). T−21: precio de mercado. Desde finales de enero-2027,
activar tarifa no reembolsable (solo elegible dentro de 60 días).

**A retirar cuando se confirme el calendario oficial de la Feria 2027**: los 7 suelos de cobertura
del 19–25/04. Están puestos porque la Feria no está confirmada y el coste de equivocarse es
asimétrico (un suelo de más solo retrasa una venta; un suelo de menos la malvende para siempre).

---

## 2026-08-15 · Min-stay decay para la semana sin supervisión (despedida de Río)

**Hipótesis** · Del 7 al 15/11 Stag está en Río (despedida de soltero) y quiere mínimos
movimientos que supervisar. Sus propios datos lo permiten sin regalar nada: las estadías de 6+
noches reservan con mediana 107 días de antelación (mínimo observado en 12 meses: 48 días; 14 de
15 con 67+) y las de 3–5 noches de otoño con mediana 44 → se puede exigir "semana entera" sin
coste real hasta ~48 días antes del check-in, y abrir por escalones a tiempo para la demanda
corta. (Aparte, los días de vuelo 6/11 y 15/11 llevarán cierre de llegadas vía sync de
restricciones de PriceLabs — mail a support@pricelabs.co pendiente de envío; decisión de Stag de
gestionarlo por PriceLabs y no a mano en Guesty.)
**Aplicado** · Overrides de `min_stay` (sin tocar precio) con `reason` fechado, 15/08 ~18:54 UTC:
ALEX y MARE min 7 en llegadas 07–15/11; JACO min 7 en 08–15/11; NICA min 4 en 07–10/11 (su hueco
es de 4 noches: 11–17/11 ya vendido). Escalones comprometidos al aplicar: **21/09 → min 3**
(NICA 4→3) y **25/10 → min 2**. Verificado `overrides_after_update` limpio (solo min_stay+reason,
nada mergeado) y `pricing_array` sin movimiento de precios en la ventana. Pendiente: push de Stag
("Sincronizar Ahora" ×4) y verificación del último eslabón en Airbnb.
**Resultado** · Sin medir (se mide en cada escalón y al cierre de la semana). Sorpresa en la
lectura post-aplicación: **Jacobine 13–14/11 aparecen bloqueadas sin reserva** (`num_bookings: 0`,
y get_pms_reservations vacío 08–18/11) cuando a las 07:10 UTC estaban libres a 283/307 € con Good
Demand — bloqueo de hoy en Guesty, rótulo pendiente de leer. Con ese bloqueo, el min 7 deja
8–12/11 **unbookable** (hueco de 5 noches < 7). Decisión en espera del rótulo: bloqueo deliberado
→ bajar 8–12 a min 5 (vender el hueco de una pieza); error → desbloquear y el min 7 sigue.
**Aprendizaje** · (1) El motor puede quedar por debajo de un `min_stay` de override para encajar
huecos (en JACO 15/11 el override guarda 7 y el `pricing_array` muestra 3): el min-stay
**efectivo** se lee en el `pricing_array`, no en el override. (2) Una escritura de min-stay puede
volver unbookable un hueco entero si el calendario cambió entre la lectura y la escritura —
releer disponibilidad en la misma pasada de verificación, como acá.

**Addendum 15/08 (noche)** · Rótulo resuelto por chat: el bloqueo 13–14/11 de Jacobine es de Stag
(casamiento de amigos). Nace la convención de rótulos: bloqueo personal = **"Personal — <motivo>"**
(inspección sigue siendo "Control") → PLAYBOOK §2.8 y ESTADO §4. Aplicado JACO 8–12/11 min 7→**5**
(hueco de una pieza: entrada 8 → salida 13, justo cuando entra el casamiento); verificado
`unbookable: 0` y precios solo con deriva diaria (±2 €). ⚠️ La noche del 15/11 sigue LIBRE a la
venta (189 €) — avisado Stag por si el casamiento la necesita. Push de Stag 19:09 verificado en
los 4 (`last_date_pushed`), pero el min 5 de JACO es de las 19:20 → **falta un push más de
Jacobine**. Verificación en Airbnb pendiente (WebFetch da 403; la hace Stag simulando una reserva
corta). Escalones 21/09 y 25/10 sin cambio (en JACO: 5→3→2).
