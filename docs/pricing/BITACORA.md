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

---

## 2026-08-17 · CTA/CTD por fecha: cierre de llegadas y salidas en los días sin cobertura

**Hipótesis** · Stag supervisa llegadas/salidas desde el móvil; en tres momentos del viaje queda
sin cobertura justo en la franja crítica (06/11 vuelo BCN→MAD→Río, offline 12–23 h Madrid;
15/11 vuelo Río→Buenos Aires, offline 15–20 h; 19/01 cruce del Atlántico, la mañana de salidas).
Un CTA/CTD por fecha cierra el movimiento SIN matar la noche: la estadía que pasa de largo se
sigue vendiendo. PriceLabs (Erika, ticket 941403, 15/08) confirmó que la función ya está
habilitada para la cuenta y los 4 listings de Guesty.
**Aplicado** · Ensayo previo en fecha invendible (JACO 15/07/2027, fuera de ventana de reserva):
guardó y se reflejó en el `pricing_array`; borrado después. Luego, overrides reales 17/08 ~01:13
Madrid, sin tocar precio: **CTA 06/11 y 15/11 en los 4 pisos; CTD 19/01/2027 en NICA, MARE y
JACO** (ALEX no: su checkout del 19/01 es una reserva ya confirmada, 10→19/01). En el 15/11 de
ALEX/MARE/JACO se reenvió el objeto COMPLETO (min_stay 7 + CICO) para no pisar el min-stay.
Verificado en los 4: las 3 fechas con su máscara y las otras 538 del horizonte neutras.
**Resultado** · Sin medir. Pendiente: (a) activar el default de CICO en ALEX y JACO — ver
aprendizaje 2; (b) Sync Now ×4; (c) verificar en Guesty (`cta`/`ctd` del calendario) y en Airbnb.
Coste esperado del CTA del 06/11: ~300 € (viernes de buena demanda en NICA 297 € y ALEX 261 €;
JACO y MARE ya están ocupados esa noche). El 15/11 aporta poco en ALEX/MARE (ya tenían min 7) y
NICA está vendido: donde muerde de verdad es en JACO, cuyo min-stay efectivo del 15/11 es 3.
**Aprendizaje** ·
1. **Los campos de la API son `check_in_check_out_enabled` ("0"/"1"), `check_in` y `check_out`**,
   estos dos como string binario de 7 chars **lunes→domingo, 1 = PERMITIDO, 0 = prohibido** —
   al revés de lo intuitivo. Hay que mandar SIEMPRE los tres. No existen `cta`/`ctd` en PriceLabs.
   Máscaras usadas: viernes cerrado `1111011`, domingo `1111110`, martes `1011111`.
2. **El default de Stay Restrictions a nivel listado es requisito y NO se puede tocar por API**
   (`update_listing_data` solo acepta min/base/max/tags; el endpoint de customizations no expone
   CICO). Se lee indirectamente en el `pricing_array`: `1111111` = función activa y neutra;
   `-1` = función sin activar. Hoy NICA y MARE están en `1111111` y **ALEX y JACO en `-1`** →
   esos dos necesitan el toggle por UI. Que NICA/MARE convivan con los 7 días permitidos prueba
   que "todo permitido" es un estado válido y neutro (la doc no lo dice; se dedujo del dato real).
3. **Un override parcial NO pisa el resto**: reenviando `min_stay` + `reason` junto a los campos
   CICO, el min-stay sobrevivió intacto en los 3 pisos donde ya existía (verificado en
   `overrides_after_update`). Aun así la doc no documenta el merge → seguir reenviando completo.
4. **Fallo atómico**: un override inválido tumba el lote entero (400, nada se guarda). Por eso se
   escribió piso por piso, no los 4 en una llamada.
5. **Al bajar el min-stay en los escalones del 21/09 y 25/10 hay que REENVIAR los campos CICO**
   del 15/11, o el cierre de llegadas se pierde. Está escrito en el propio `reason` del override.

**Addendum 17/08 (madrugada)** · Cadena verificada hasta Guesty y escalones automatizados.
Stag activó el default de Stay Restrictions en ALEX y JACO (pasaron de `-1` a `1111111` en el
`pricing_array`, sin tocar ninguna fecha) y sincronizó los 4. El calendario de Guesty ya devuelve
**`cta: true` el 06/11 y el 15/11 en los cuatro pisos** y **`ctd: true` el 19/01 en NICA, MARE y
JACO** (ALEX en `false`, correcto: su salida del 19/01 es una reserva confirmada). Queda un solo
eslabón sin verificar, el que manda: probar en Airbnb como huésped. Nota útil para el futuro: la
doc de Guesty avisa que las restricciones puestas vía PriceLabs "no se ven en Guesty", pero eso
vale para su UI — **la Open API sí las expone** en `days.calendar[].cta/.ctd` del endpoint
minified, que es como se auditó esto.
Los dos escalones dejaron de depender de que alguien se acuerde: se programaron como agentes en
la nube de una sola ejecución (21/09 07:00 UTC y 25/10 08:00 UTC), con el playbook y esta bitácora
en su contexto, la instrucción explícita de reenviar los campos CICO del 15/11, y aviso por mail
a info@ al terminar. El del 25/10 además cierra el experimento midiendo cuántas noches de la
semana se vendieron en cada escalón.


---

## 2026-08-20 · Jacobine 2027: guardas post-apertura de ventana (APLICADO) + regla del suelo inerte

**Contexto** · Stag preguntó si may/jun/jul 2027 estaban baratos al ver entrar reservas largas tras
abrir la ventana a 365 días (14/08). Dos análisis multi-agente con auditoría adversarial. Veredicto:
NO están baratos (mayo +15 %, junio +7 %, julio 0/+4 % vs neto 2026) y NO se sube la larga distancia.
La evidencia "el que compra antes paga menos" del primer informe se retiró (n=16 normalizadas en
Madrid; y 126 reservas de NICA tienen createdAt falso del volcado 15/06/2025 — aunque ninguna en el
tramo largo). Objeción de Stag sobre reputación: correcta como método (rampa +16/+32 % medida en
ALEX/MARE, se agota hacia 25–45 reseñas; más allá no es medible con esta cartera), pero la decisión
no depende de ella: la aritmética de comisión manda (25 % de la subida vs 25 % de TODO el bruto de
una noche perdida; punto muerto 4,6 noches de 77 incluso con headroom +6 %).

**Early bird probado en línea de factura** · ítem literal "Early bird" al 10,00 % exacto en 16/24
reservas Airbnb con lead ≥90 d; la reserva Booking a 349 d pagó el 100,0 % del calendario del día.
Regaló 1.146,60 € de bruto en estancias 2026 de JACO (286,65 € de comisión). Airbnb NO permite
excluir fechas (confirmado por Stag) → compensación solo vía suelos. Expediente Madrid (~7.000
€/año simulado, el número más grande y peor medido del dossier) abierto para el 01/10.

**Aplicado (con OK explícito de Stag, punto por punto)** ·
- BORRADOS los 5 overrides de la cobertura alternativa de Feria que mordían (19–22 y 25/04/2027):
  calendario confirmado (Feria 13–18/04, alumbrao la noche del 12). Quedan el 23 y el 24/04
  (inertes; cubren si el "Kings Cup" del feed resultara real).
- SUELOS anti-derrumbe Karol G (confirmado en estadiolacartuja.es, 3 noches, única ciudad europea
  del tour con 3 seguidas): 430 el 10/06 y 850 el 11–13/06 — inertes (publica 471/935). Min-stay
  NO se toca (2). Protegen 833,32 € de comisión que ya están en el precio publicado.
- GUARDAS pre-Feria: 400 el 09/04 y 390 el 10/04 — inertes (publica 452/439).
- Verificación completa: overrides_after_update limpio, pricing_array post-refresh sin movimiento
  en Feria ni Karol G (suelos inertes ✓), 19/04 liberó 500→377 y 25/04 445→408.

**Hallazgo al borrar — va al PLAYBOOK §2.10** · El 20–22/04 NO cayó a demanda: lo agarró el
Precio Mínimo de Seguridad (110 % del ADR del año pasado por día de semana → hereda Feria 2026)
y quedó clavado a 544/544/698. Se suelta solo a los 180 días (~22/10); verificación agendada 25/10.
Daño real ~0: las equivalentes de 2026 se vendieron con 3–29 días de lead.

**Decisiones de Stag (20/08)** ·
- NO subir el escaparate de Karol G a 1.039 (apuesta ~53 € vs ~224 €/noche perdida). No reproponer
  sin dato nuevo de elasticidad.
- NO subir larga distancia hasta el 01/10; criterio escrito en ESTADO §5.
- Min-stay de salida de Feria: APROBADO por Stag el 20/08 (tarde) tras la fundamentación
  (min-stay se evalúa sobre la LLEGADA; la Feria 2026 se vendió en trozos de 3+2+3 noches a
  624/665 €; el 5 en llegadas tardías vende "finde + noches muertas post-resaca", producto que
  no compra nadie). APLICADO: 15/04 → min 4, 16/04 → min 3, 17/04 → min 2, 18/04 → min 2, con
  reperfil de suelos del finde (16/04 620→665, 17/04 575→665, 18/04 445→510), todos INERTES
  (publica 679/723/723/569). Llegadas 12–14 conservan min 5: el comprador de semana entera
  mantiene prioridad. Verificado en pricing_array post-refresh: precios sin movimiento (deriva
  diaria de 2–3 €), perfil de min-stay 5/5/5/4/3/2/2. Reversión: para volver a 5 hay que borrar
  y recrear reenviando el min_price completo. Revisar 12/01/2027 (T−90).
- Pendientes de Stag: comp set → 2 dormitorios (clic en UI), cleaning fee 70→60 en PriceLabs
  (la API solo acepta min/base/max/tags — el aviso del CLAUDE.md era correcto), push "Sincronizar
  Ahora" (o sync diario ~06:50), y verificación como huésped en Airbnb.

**Booking.com — hallazgo para el motor (NO tocado)** · En la única reserva Booking de la historia
(30/07–03/08/2027) la base de comisión del motor (host_payout+host_service_fee = 951,05) supera al
bruto (827,00): +31,01 € facturados de más a la dueña. En Airbnb la desviación es −21,61 € en 123
reservas (ruido). No se toca hasta contrastar contra factura real; estancia en ago-2027, hay tiempo.

**Medición en curso** · Pipeline 2027 tras la apertura: 4 reservas en 6 días, todas >176 d
(3.590,90 € bruto / 897,73 € comisión, en ventana de cancelación; el tramo largo cancela al 25 %
en la cartera). NO anualizable: es vaciado de 15 meses de stock cerrado. Punto de decisión: 01/10.

---

## 2026-08-29 · Alexander 07–08/09: noches liberadas por cancelación — escalera descendente decidida por Stag (APLICADO)

**Contexto** · Nicolás Magnoli (reserva directa F&F `GY-6gVkY373`, lun 07 → mié 09/09, 2 noches,
275 € cash, sin cobrar) pide liberar las noches. Hueco de exactamente 2 noches entre el checkout
del 07 (reserva 02–07/09 a 158 €) y el check-in del 09 (09–12/09 a 260 €). Alexander tiene
septiembre al 96,7 % con ADR 207 €; la única otra noche libre del mes es el lunes 21.
**Análisis (workflow de 6 agentes: histórico de 50 cancelaciones / 174 noches, knowledge base de
PriceLabs, precedentes, 3 jueces)** ·
- PriceLabs **no tiene lógica ni aviso de cancelación** (KB, preguntas a y f). Al liberarse, la
  noche se reprecifica como libre a 9 días: huérfano −20 % (hueco ≤2) + curva de último minuto,
  freno en el `min` 129 → el huésped vería ≈110 €/noche con el −15 % de Airbnb.
- **Con min-stay 3 el hueco de 2 noches era invendible.** Nadie lo habría avisado.
- Histórico: >14 días, 86 % de las noches liberadas se revenden a ratio 1,02; **≤14 días en Madrid,
  56 % a ratio 0,73**, reventa con lead mediano 2 días. Alexander: 3 % de sus reservas entran a ≤10
  días (lead mediano 104); ninguna noche de septiembre en Madrid se vendió con lead ≤10; máximo
  pagado en Madrid con lead ≤10 en 2026: 167 €/noche (Alexander: 90,10).
- Recomendación de Claude: min-stay 2 + suelo inerte (135/160) con reversión T−3, EV ≈ 100 €; y si
  cancelar era decisión propia, no cancelar (231 € netos ciertos vs ~100 esperados).
**Decisión de Stag (29/08)** · Liberar y "cobrar igual o más que Magnoli": escalera descendente,
nunca por debajo de lo de Magnoli, min-stay 2. Aplicado tal cual, con la evidencia en contra
registrada acá.
**Traducción del suelo (→ PLAYBOOK §4.8)** · "Lo de Magnoli" = 275 € netos por la estancia. Vía
Airbnb: 275 ÷ 0,8124 = 338,50 € que paga el huésped; − 50 limpieza = 288,50 → 144,25 €/noche vistos;
÷ 0,85 (última hora ≤14 d) = **170 €/noche publicados**.
**Competencia (PriceLabs, 29/08; comp set 267 pisos de 1 dorm.)** · Lun 07: ocupación de mercado
55,8 % (el año pasado cerró en 73 %), precios p25/p50/p75/p90 = 113/147/186/260, mediana de lo ya
reservado 137. Mar 08: 55,3 % (LY 79 %), 114/152/205/269, mediana reservada 148; el 08 abre un
evento de mercado (08–13/09, precios +35 % el 09–13). Recomendado de PriceLabs: 150/178.
**Aplicado (17:55 UTC)** · overrides ALEX `2026-09-07 min_price 205` y `2026-09-08 min_price 229`
(fixed, EUR), `min_stay 2` en ambos, reason fechado con la escalera completa. `overrides_after_update`
limpio (solo los campos enviados). `pricing_array` post-refresh: 07 → **205** (uncustomized 150),
08 → **229** (uncustomized 178), min_stay 2, unbookable 0, CICO `1111111`. El huésped verá
174,25 + 194,65 + 50 = **418,90 €** por las 2 noches (neto ≈ 340 €, +65 sobre Magnoli).
**Escalera (routines en la nube a las 05:15 UTC, para que el sync diario ~06:50 publique)** ·
- 02/09 (D−5) → **185/205**: huésped 157,25 + 174,25 + 50 = 381,50 € (neto ≈ 310).
- 05/09 (D−2) → **170/170 = suelo Magnoli**: 144,50 × 2 + 50 = 339 € (neto ≈ 275,40).
- Sin más escalones: el suelo no se baja. Los overrides caducan con el check-in. Cada routine relee
  overrides y calendario y NO escribe si el hueco ya se vendió o si alguien editó a mano.
**Pendiente de Stag** · cancelar la reserva en Guesty, "Sincronizar Ahora" en Alexander y verificar
en Airbnb como huésped (07→09/09: 418,90 €). Hasta entonces: configurado, no publicado.
**Hipótesis en juego** · Stag: hay comprador a ≥170 publicado para un lunes–martes a ≤9 días.
Claude: la evidencia dice lo contrario (ver arriba). Coste de equivocarse: si no se vende, 0 €
(contra ~100 € esperados de la alternativa); si se vende, entre +0 y +65 € sobre Magnoli.
**Sin medir · medición 09/09**: vendida o no, a qué precio, en qué escalón y con qué lead. Un caso
no cierra la discusión (n=1): entra como primer dato prospectivo del detector de noches liberadas.
**Hallazgo colateral (corrige el precedente Nicasio 11–14/08)** · según `get_user_logs`, los 93,50 €
no los puso el algoritmo: el 10/08 se escribió un `price` FIJO 130 (00:09 UTC) y 110 (09:55 UTC)
desde el móvil con el reason viejo del test, y 99 el 12/08; 110 × 0,85 = 93,50. → PLAYBOOK §5.4.
**Propuesta estructural (sin construir, espera OK)** · vista `v_noches_liberadas` sobre
`pricelabs_fotos` (Booked ayer → libre hoy) + línea en la guardia diaria y en `/precios`.

**Cambio de objetivo (30/08/2026, Stag)** · "No importa el precio mínimo: analizá la competencia y
armá la estrategia para que queden reservadas; confío en tu criterio y después aprendemos". Se
retira el suelo Magnoli. Estado a las 08:35 UTC: la cancelación ya llegó a PriceLabs (07–08 libres,
demanda "Low"/"Normal"), el sync diario publicó 205/229 + min-stay 2 (`last_date_pushed` 08:35).
**Competencia hoy (267 pisos 1 dorm.)** · Lun 07: ocupación 56,8 % (+1,0 pp/día; LY cerró 73 %),
p25/p50/p75 = 110/146/185, **mediana de lo reservado 138**. Mar 08: 56,3 % (LY 79 %), 110/150/205,
**mediana reservada 149**; PriceLabs detecta evento "Madring F1" desde el 08 (GP 11–13/09, mercado
+35 % del 09 al 13; nuestra reserva 09–12 a 260 lo confirma). Regla de mercado (pulse de PriceLabs):
**en septiembre las reservas entran 1–9 días antes** → la ventana de compra de estas noches es AHORA.
Estar a p65–p70 (205/229) en plena ventana era la estrategia equivocada para llenar.
**Estrategia aplicada (Claude)** · precio de cierre = mediana de lo que pagaron los que reservaron
esas fechas (138/149 vistos) y escalera hacia lo perecedero, con la bookability primero:
- **30/08 (D−8, aplicado 09:40 UTC)** → `min_price` **162 / 175** (huésped ve 137,70 + 148,75 + 50 =
  **336,45 €**; neto ≈ 273). Verificado: overrides_after_update limpio, pricing_array 162/175,
  min_stay 2, unbookable 0. Publica el sync de mañana ~06:50 o Stag con "Sincronizar Ahora".
- **02/09 (D−5)** → 147 / 153 (huésped 125 + 130 + 50 = 305 €) — routine `trig_01XhA7Bnb22zsjcnJ5ZNCd7A`.
- **04/09 (D−3)** → se QUITA el suelo (delete + recreate solo con min_stay 2): manda el mínimo del
  anuncio 129 → huésped 109,65/noche (≈ p25) — routine `trig_01XgJ56kELgbaSp1HZSt78oV`.
- **06/09 (D−1)** → min-stay **1** (última red; los huecos de 1 noche venden el 1,4 %) — routine
  `trig_01Ugf4RGSXB5BGpG8cJ5w5KJ`.
Palancas fuera de PriceLabs pedidas a Stag: confirmar Instant Book en Alexander; comprobar que
Booking.com (listing 15469385, cero reservas históricas) tiene el 07–09 abierto y con precio;
ofrecer las noches en directo a su red (130 €/noche directo ≈ 160 por Airbnb); opcional: promoción
personalizada de Airbnb en esas fechas (precio tachado, visibilidad §3.4) — si la activa, el visible
baja ×0,90 más y NO se compensa (es el escalón D−5 adelantado).
**Hipótesis** · con min-stay 2 y precio en la mediana reservada, P(venta) 35–50 % (Madrid ≤14 d:
56 % de noches revendidas; conversión de Alexander a ≤9 d: 17 %). **Medición 09/09**: vendida o no,
escalón, precio, lead, canal. Lo que aprendemos: (a) si vende en el escalón 1–2, la mediana
reservada es el ancla correcta; (b) si vende recién sin suelo, el mercado de 2 noches lun–mar a ≤3
días es de p25; (c) si no vende, el hueco era de forma, no de precio (§4.1).


**Segundo cambio de objetivo (31/08/2026, Stag)** · "Bajame el precio: no priorizo recuperar,
sino que él pague menos porque es un conocido" — Magnoli va a reservar por el canal y el precio
público es la vía elegida (objeción registrada: el precio público es para TODOS; si otro lo agarra
primero, el conocido se queda sin noches. Lo limpio habría sido reserva directa u oferta especial
de Airbnb. Stag eligió PriceLabs igual).
**Aplicado (31/08 ~10:30 UTC)** · delete de los min_price 162/175 y recreación con **`price` FIJO
110** (fixed, EUR) + min-stay 2 en 07 y 08/09. Es el uso legítimo del precio fijo (§2.2: fijo es
para BAJAR; §2.10 no aplica — es un descuento deliberado, no un suelo). El huésped ve **93,50
€/noche** (110 × 0,85) → estancia de 2 noches: 187 + 50 limpieza = **237 €** (−14 % vs los 275 que
iba a pagar; neto Samavi ≈ 192,5). Referencias: 93,50 visible = por debajo del p25 del mercado
(110) = el precio exacto al que se revendieron las noches liberadas de Nicasio en agosto → si
Magnoli no la toma, la probabilidad de que la tome otro es alta.
**Escaleras canceladas** · routines del 02/09 y 04/09 deshabilitadas (renombradas "CANCELADA
31/08"). La del 06/09 (D−1) queda como red final reescrita: solo min-stay 2→1, reenviando el
objeto completo con el fijo 110 (§2.3).
**Pendiente de Stag** · "Sincronizar Ahora" (si no, publica el sync de mañana ~06:50) y avisarle a
Magnoli que reserve cuanto antes — el precio es público y esas fechas están por debajo de todo el
barrio. **Medición 09/09**: quién la reservó (si el ADR ≈ 93,50 vía canal, fue el conocido u otro),
cuándo, y si el fijo bloqueó una venta mejor (demanda del martes era "Normal" con el F1 cerca).
**Coherencia con lo de anoche (otra sesión, commits af64d70/0640d95)** · (1) §4.10 pide `min_price`
para bajar "siempre que el recomendado ya esté por debajo" — acá NO lo está (dinámico 146/176 > 110),
así que el fijo es la herramienta correcta (§2.2); el modo de fallo barato que §4.10 evita acá es
deliberado: si todo se cae, la noche queda barata, que es lo que Stag pidió. (2) §4.9 (un precio por
sync): cumplido de rebote — queda UN solo cambio más (min-stay 1 en D−1). (3) El fijo de 110 entra
en la serie STLY: si se vende a 93,50, el Precio Mínimo de Seguridad de ese lun–mar de sept-2027
arrancará bajo (coste chico que no caduca, §4.9). (4) Limpieza ya está en 60 € (verificado en
PriceLabs): el total que ve el huésped es **247 €**, no 237. (5) DIRECTAS.md: NO mandarle además
una oferta directa u oferta especial — sería el doble descuento; y si reserva por canal, la plata
entra al reservar, que es exactamente lo que la cicatriz Magnoli pide.

**CORRECCIÓN — el objetivo era otro (31/08, mediodía)** · Stag: *"No, Magnoli ya canceló. Quiero
que se llene para que no pague el 50 % del valor de la reserva acordado sino menos, para que
lleguemos al mismo precio. Compará la competencia de la zona para ajustar el mínimo."* Lo del 31/08
por la mañana se hizo sobre una lectura equivocada de "que él pague menos" (se entendió *que reserve
él más barato*; era *que le quede menos penalidad*). El precio de cortesía de 110 jugaba **en contra
del objetivo**: cuanto más barato se vende, MÁS penalidad paga Magnoli.

**La aritmética del caso (la regla que hay que recordar)** · Reserva 275 €, penalidad pactada 50 % =
**137,50 €**; lo que se recupere revendiendo se le descuenta → Magnoli paga `min(137,50; 275 − neto)`.
De ahí dos consecuencias que apuntan a cosas distintas:
- **Que se venda** vale 137,50 € **para Samavi** (de 137,50 sin venta a 275 con venta).
- **A qué precio** se venda, por encima de ~96 €/noche publicados, **no cambia nada para Samavi**
  (siempre 275) y es **puro alivio para Magnoli**. A 196 €/noche su penalidad sería 0.
Neto = `(2 × P × 0,85 + 60) × 0,8124 − 43,80` (0,85 = última hora Airbnb; 0,8124 = payout; 43,80 =
coste real de limpieza). Tabla: 110/110 → paga 118,14 · 129/129 → 91,90 · 145/155 → 62,89 ·
161/173 → **39,42** · 185/205 → ~0.

**Competencia leída hoy (31/08, comp set 267 pisos 1BR)** · Lun 07: ocupación 58,5 % (+1,7 pp en un
día, +7,3 pp en la semana; LY cerró 73 %), p25 110 · p50 146 · p75 185 · p90 258, **mediana PAGADA
137** (n=145). Mar 08: 56,7 % (+6,1 pp semana; LY 79 %), p25 110 · p50 150 · p75 205 · p90 262,
**mediana PAGADA 147** (n=140). El ancla NO es el publicado del barrio (que incluye a los que no
venden) sino **lo que pagaron los que sí reservaron**.

**Aplicado (31/08 10:40 UTC)** · delete del `price` fijo 110 y recreación con **`min_price` 161
(07/09) y 173 (08/09)** + min-stay 2. Verificado en `pricing_array`: publica **161 / 173** (el
huérfano −20 % empuja a 117/141 y el suelo lo frena), min_stay 2, unbookable 0. El huésped ve
136,85 + 147,05 + 60 = **343,90 €** → neto 235,58 → **Magnoli pagaría 39,42 € en vez de 137,50**.
Se vuelve a `min_price` (no `price` fijo) por §4.10: si una routine falla, la noche queda CARA, que
acá es exactamente lo que conviene.

**Escalera (routines 05:15 UTC, antes del sync que publica ~06:50; §4.9 un precio por sync)** ·
- **03/09 (D−4)** → 145/155 · huésped 315 € · Magnoli 62,89 — `trig_01XhA7Bnb22zsjcnJ5ZNCd7A`
- **05/09 (D−2)** → sin suelo, manda el mínimo del anuncio 129 · huésped 279,30 € · Magnoli 91,90 —
  `trig_01XgJ56kELgbaSp1HZSt78oV`
- **06/09 (D−1)** → min-stay 1, precio sin tocar (última red) — `trig_01Ugf4RGSXB5BGpG8cJ5w5KJ`
  (reescrita: la versión anterior mandaba reenviar el fijo 110 — habría revivido el error).
**Suelo definitivo 129** (= p25 del barrio a ojos del huésped): por debajo, el alivio para Magnoli
cae por debajo de 46 € y solo se estaría regalando margen.
**Supuesto que hay que confirmar con Stag** · que la penalidad es 50 % de 275 = 137,50 y que él paga
la diferencia hasta 275. Si el pacto fuese otro (p. ej. 50 % del bruto 298, o 50 % fijo sin
descontar), cambian los números pero NO la estrategia: vender lo más caro posible sin dejar de vender.


---

## 2026-08-30 · No-show Booking en Nicasio 29/08→03/09: comisión, cobro del 50 % y noches liberadas a suelo 150 + escalera de min-stay (APLICADO)

**Contexto** · Reserva Booking.com `BC-jg7mnkyGW` (nº Booking 5425115874), sáb 29/08 → jue 03/09, 5 noches,
2 huéspedes, reservada el 10/03 (lead 172 d): 1.155,52 € de alojamiento (1.256 − 8 % de markup del canal)
+ 60 limpieza = 1.215,52 €; comisión 17 % = 206,64 €. Pago en el piso, `total_paid` 0. Los huéspedes no
llegaron ni respondieron mensajes ni llamadas el 29–30/08.
**Dinero (Stag, 30/08)** · La tarifa llevaba política **50 % no reembolsable**. El usuario de la extranet no
tiene permiso para ver la tarjeta, así que no se pudo cobrar. Stag marcó el no-show en la extranet eligiendo
«No, cobrar el cargo»; Booking le dijo que intentará cobrarle el 50 % (**607,76 €**) a la huésped sin
garantía, y que si no se cobra no hay comisión. Stag le escribió a la huésped pidiendo la transferencia.
**Desenlace del mismo día (30/08, tres llamadas)** · El primer agente de Booking le aseguró a Stag que
«No, cobrar el cargo» no generaba comisión: **es falso**, y una segunda agente lo desmintió. En la tercera
llamada le dieron el camino de corrección real: **marcar la tarjeta del huésped como NO VÁLIDA** (botón
propio, con motivo) y, a las **24–48 h**, apretar el botón de reclamación que aparece en la reserva para
que **no se cobre la comisión**. Stag marcó la tarjeta como no válida el 30/08 — coherente con que su
usuario ni siquiera tiene el permiso «Ver datos de la tarjeta». Consecuencia: la comisión de 206,64 €
queda en camino de anularse (reclamar el **01/09**, en ESTADO §5), y el cobro del 50 % se da por perdido
salvo transferencia voluntaria de la huésped. **Regla nueva** (→ CASUISTICAS §5.4 punto 2-bis): lo que
diga un agente por teléfono no vale hasta que esté por escrito en el Inbox de la extranet. Mecánica
completa y fuentes en [CASUISTICAS §5.4](../operativa/CASUISTICAS.md).
**Análisis (workflow de 5 agentes: no-show de Booking por fuentes oficiales, histórico de última hora en
Supabase, plan con valor esperado y dos revisores adversariales — uno "pro-subida", otro de playbook)** ·
- Competencia (comp set 267 pisos de 1 dorm., leído el 30/08): ocupación de mercado dom 30/08 **77 %**
  (STLY 85; evento The Weeknd) · lun 31/08 **57 %** (71) · mar 01/09 **53 %** (73) · mié 02/09 **53 %** (74)
  · jue 03/09 **61 %** (74). Medianas publicadas 125/116/124/130/145; medianas de lo **ya reservado**
  132/119/116/119/131; pickup de los últimos 7 días 4–6 pp contra 13–16 STLY → un tercio de la demanda del
  año pasado y ~120 pisos libres lun–mié.
- Histórico Nicasio: **5 ventas a ≤4 días en 14 meses**, todas Airbnb, todas de 2 noches, 93,50–125,20 €/noche
  (ratio 0,60–0,78 del ADR del mes con lead 15+) — 3 de ellas a precios fijos que pusimos nosotros bajos el
  10–12/08, así que es techo de oferta, no de demanda. La huérfana del 28/08 (167 €) se vendió el 23/08 recién
  cuando PriceLabs la bajó de 181 a 167 tras 10 días quieta. Booking.com nunca trajo una reserva con lead <152 d.
- PriceLabs recomendaba (uncustomized) 82–131 para 30/08–03/09: el mínimo del anuncio (150) ya frena hacia arriba.
- Igualar lo que pagaba el que no vino (231,10/noche a 172 d) exigiría ≈278 € publicados (fórmula §4.8.2), por
  encima del p90 de todas las noches: ese precio existe a 172 días, no a 1–4.
- EV neto del hueco según estrategia (probabilidades 15–50 % por noche según lectura, cuota de mercado vs ancla
  histórica): **suelo 150 + escalera de min-stay 100–200 €** · subir a 175: 45–116 · subir a 200: 20–57 ·
  bajar bajo el suelo: empata con 150 pero contra §2.5/§4.3. La diferencia entre la mejor y la peor decisión
  de precio (~140 €) es menor que la comisión en juego (206,64).
- El revisor pro-subida defendió **170** en 31/08–03/09 (traducción §4.8.2; dentro de la banda §5.7 — 175 la
  dispararía el 31/08) con escalón a 150 al volverse same-day: ±30 € de EV, dentro del ruido; su valor sería
  medir la elasticidad de última hora de Nicasio. Condición previa: verificar como huésped si el −15 % de
  Airbnb se aplica en Nicasio (el 28/08 vendió 166,95 sobre 167 publicados: sospecha de que no).
**Decisión** · Stag (30/08, 13:50 Madrid): "hacé lo que consideres mejor". Aplicado lo recomendado: **no subir**;
suelo inerte 150 (= mínimo del anuncio, no es subida ni bajada) + escalera de min-stay.
**Aplicado (11:57 UTC)** · 5 overrides NICA `min_price 150 fixed EUR` con reason fechado: 30/08 `min_stay 1` ·
31/08, 01/09 y 02/09 `min_stay 2` · 03/09 `min_stay 1`. `overrides_after_update` limpio (solo los campos
enviados). Refresh: pricing_array **150 × 5**, min_stay 1/2/2/2/1, unbookable 0 en las cinco (el 03/09 estaba
unbookable antes de liberar), CICO `1111111`; uncustomized 82/92/102/110/131. El huésped ve en Airbnb
127,50 €/noche + 60; en Booking ≈163. Alexander y Marechal llenos 30/08–07/09: sin canibalización.
**Push verificado** · Stag pulsó «Sincronizar Ahora» y `last_date_pushed` quedó en **12:05:26 UTC**, posterior
a la escritura de las 11:57: el min-stay 1 del 30/08 y del 03/09 llegó al canal. Queda solo la comprobación
visual como huésped en Airbnb (03/09→04/09 reservable por 1 noche; 31/08→02/09 a ≈127,50/noche).
**Escalera (routines en la nube a las 05:15 UTC; cada una relee overrides y calendario, NO escribe si la noche
ya se vendió o si el override no es el esperado, y avisa por mail a info@)** · 31/08 → min-stay 1 en 31/08
(`trig_012yeB7VnD57aXf3duepmSZ8`) · 01/09 → min-stay 1 en 01/09 (`trig_019FpJ6i8uzBRNw7LBcvN7oj`) · 02/09 →
min-stay 1 en 02/09, último (`trig_017sc2Z9Azyo3ysWbNYtRqK3`). **Sin escalón por debajo de 150.**
**Hipótesis en juego** · Claude: si el hueco se vende, se vende a 150 publicados, con lead 1–3 días, estancia
de 2 noches, por Airbnb; subir no compra nada en un mercado al 53–57 %. Contrahipótesis registrada: 170 con
escalón habría vendido igual (elasticidad ~0, §4.3) y habría dejado +13,80 €/noche.
**Sin medir · medición 04/09**: noches vendidas, precio, lead, canal, escalón; comparar con la reventa del caso
Magnoli (medición 09/09). Segundo caso prospectivo del detector de noches liberadas.
**Motor** · Mientras `reservations.status` siga `confirmed`, el P&L cuenta 693,31 € en agosto + 462,21 en
septiembre + limpieza que no existen. **Resuelto el mismo día**: Guesty la canceló a las 11:32 UTC y guesty-sync la trajo
`canceled` en la corrida de las 12:00 UTC — el P&L de agosto ya no la cuenta. Si entra el 50 %
(607,76 €), es un **cobro retenido** (línea aparte, no toca noches ni ADR) y la comisión de Booking sobre él
va como event al llegar la factura.

---

## 2026-08-31 (00:15 Madrid) · Nicasio, noches del no-show: BAJADA TÁCTICA con escalera D−1 (APLICADO)

**Pedido de Stag** (30/08, de noche): *"no deberíamos bajar los precios de las noches que quedaron libres…
bajemos un poco más el precio y veamos a ver cómo funciona"*. Decisión suya; la tarea fue diseñar la mejor
bajada posible, no discutirla. Respaldo del playbook: **§4.4** (a ≤7 días una noche vacía compite contra 0 €).

**El hallazgo que hay que leer antes que los precios: a 150 NO estábamos caros.** El huésped veía 127,50
(con el −15 %) y eso nos dejaba en **p38–p56** del comp set en las cuatro noches, a +7/+10 % de la mediana
de lo que el barrio YA cobró (y −2,7 % el jueves). Y contra el `precio_base` de cada noche (122/128/136/159),
los nuevos 124/120/136/150 están entre el 94 % y el 106 %: **esto no es bajar el precio, es dejar de subirlo**
— el que estaba fuera de sitio era el 150 plano, que es el mínimo del anuncio calibrado para el año, no para
un martes de septiembre a 24 horas. Las 11 h sin vender del domingo no eran evidencia de nada.

**Competencia (comp set 267 pisos, leído a las 23:35 del 30/08; segunda lectura del día)** · mediana de lo
YA reservado: lun **119** · mar **116** · mié **119** · jue **131**, idéntica a la de la mañana. Ocupación de
mercado subió en el día (56,8→60,1 · 52,8→55,6 · 53,4→55,0 · 60,6→61,4) y el pickup de 7 días también
(4,4→7,3 · 5,6→8,8 · 5,2→6,8 · 6,3→7,5): **el mercado absorbió inventario sin bajar precios**, y la brecha
contra el año pasado se estrechó 0,8–3,3 pp. `uncustomized` de PriceLabs para esas noches: 76/97/111/134
(el suelo le tapaba la curva de último minuto).

**El principio de la escalera (lo nuevo que se aprendió acá)** · **cada noche llega a su precio más bajo el
D−1 — el día ANTES — y el día mismo NO se toca.** Dos razones: (a) Nicasio tiene **cero ventas same-day en
14 meses**, así que el peldaño del día D no compra nada (±1 € de valor esperado); (b) es el único coste que
NO caduca: un print bajo entra en la serie STLY y el Precio Mínimo de Seguridad (110 % del ADR del año
pasado, por día de semana) gobierna esa noche de 2027 hasta ~marzo, justo la ventana donde entra el 71 % de
las reservas. **Corolario operativo descubierto en la revisión: una noche no puede tener más precios que
syncs le queden.** PriceLabs publica una vez al día (~06:50 UTC) y las routines corren 95 min antes: una
escalera de 3 escalones para una noche que tiene 2 syncs por delante se ejecuta como 2, y el peldaño
intermedio no lo ve nunca un comprador.

**Aplicado (30/08 22:05 UTC = 31/08 00:15 Madrid)** · 4 overrides `min_price fixed EUR` + `min_stay 1` en
las cuatro noches (el min-stay 1 es la palanca gratis: el hueco es de 4 noches y ninguna combinación queda
excluida). Verificado en `pricing_array` tras el refresh — publica exactamente el suelo, porque el
`uncustomized` está por debajo:

| Noche | Hoy | 01/09 | 02/09 | Suelo duro | Huésped ve (Airbnb) | Neto/noche |
|---|---:|---:|---:|---:|---:|---:|
| lun 31/08 (D0) | **124** | — | — | 124 | 105,40 | 85,62 |
| mar 01/09 (D−1) | **120** | — | — | **120** | 102,00 | 82,86 |
| mié 02/09 | 136 | **120** | — | **120** | 115,60 → 102,00 | 93,91 → 82,86 |
| jue 03/09 | 150 | 140 | **131** | **131** | 127,50 → 119 → 111,35 | 103,58 → 96,67 → 90,45 |

**Por qué esos suelos** · **120** deja al huésped en 102 = **p25–p32** del barrio (el cuartil barato) y por
debajo de la mediana reservada (116–119), sin entrar en la zona donde §4.3 midió elasticidad ~0 (cicatriz
Marechal 07–09/08: percentil ~10 varios días, cero ventas). **131** en el jueves = exactamente la mediana de
lo que el comp set ya cobró esa noche; es la noche con mejor mercado del hueco (p50 145) y la peor del piso
(jueves al 58,8 % en 2026 contra 82,4 % el año pasado), así que se la trata aparte y arranca de control.
El umbral que manda acá **no es el ADR de equilibrio** (esas noches ya tienen los costes fijos hundidos) sino
el **coste marginal**: ~11–14 €/noche + la limpieza de la estancia (60 cobrados → 48,74 netos vs 53,72 de
coste = −4,98). Cualquier venta por encima de ~40 € publicados suma; los suelos están muy por encima.

**Mecánica: `min_price`, nunca `price` fijo.** Con el `uncustomized` por debajo, bajar el suelo SÍ baja el
publicado (confirmado en el `pricing_array`: 124/120/136/150 = los suelos escritos), y la cicatriz de §2.2
(Alexander con `min` de anuncio 129 y suelo 119 → publicó 123) prueba que el override pisa el mínimo del
anuncio. Se elige `min_price` por su **modo de fallo**: si una routine no corre, la noche queda al precio
más CARO, no al más barato — la antítesis exacta de §5.4 (el precio fijo olvidado que regaló los 93,50).

**Routines** · Se **desactivaron** las tres de la escalera de min-stay del 30/08 (`trig_012yeB…`,
`trig_019FpJ…`, `trig_017sc2…`): habrían reescrito `min_price 150` y pisado la bajada — la del 31/08 corría
en 4 horas. Nuevas, con guardas reforzadas: **01/09 05:15 UTC** (`trig_01DwgBps3cRpnwbQTdE48wZT`) → 02/09 a
120 y 03/09 a 140; **02/09 05:15 UTC** (`trig_01DKf85LxxLhspUR1vGXsKTM`, último) → 03/09 a 131.
Guardas nuevas respecto de las de ayer: (1) **no usar `booking_status`** para saber si una noche se vendió —
quedó *fantasma* diciendo `"Booked"` con `occupancy 0` y `ADR -1` después de la cancelación; se usa
`occupancy` del `pricing_array` **y** una consulta a `reservations`; (2) comprobar que **sigue existiendo el
check-in del 04/09** (si se cae, el hueco cambia de forma y hay que rehacer la escalera); (3) comprobar
`last_date_pushed` posterior al escalón anterior — si el peldaño de ayer nunca llegó al canal, no se baja
otro contra cero exposición; (4) si el override no es el esperado, **no dar el paso doble**.

**Pendiente de Stag** · «Sincronizar Ahora» en Nicasio para que salga ya; si no, entra solo en el sync de
las ~06:50 UTC del 31/08. Y verificar como huésped en Airbnb **si el −15 % de última hora se aplica de
verdad en Nicasio**: el 28/08 vendió 166,95 sobre 167 publicados, lo que sugiere que no. Si no se aplica,
toda la banda de esta escalera está un 15 % más arriba de lo calculado (el huésped vería 120–150, no
102–127,50) — es el input que más mueve la aguja y no está verificado (§5.1).

**Hipótesis en juego** · Stag: a 150 no se vendía y a 120 sí. Claude: el mercado no nos estaba mirando
todavía; a 120 estamos en el cuartil barato de un barrio que absorbió inventario sin rematar, y si se vende
no vamos a poder separar qué lo compró — si el precio o el min-stay 1, que se aplicó el mismo día.
**Coste de la bajada si se venden las 4 noches: −82,88 € contra los 150.** Se paga con 1 noche extra por
cada 4 que se hubieran vendido igual, y la base de "se hubieran vendido igual" es casi cero.

**Sin medir · medición 04/09**: qué noches se vendieron, a qué precio, con qué lead, por qué canal y en qué
escalón. Se compara con el caso Magnoli de Alexander (medición 09/09), que corrió la estrategia inversa.

## 2026-08-31 · Directa 31/10 (exhuésped de Nicasio): cotización a paridad y nacimiento del manual DIRECTAS (PRESUPUESTO ENVIADO)

**El caso** · Una exhuésped de Nicasio pide por WhatsApp UNA noche, la del sábado 31/10 (salida
6:00 por vuelo). El min-stay 3 la bloquea en todos los canales y en la web propia (comparten
calendario). Jacobine descartado (vendido 27/10→02/11); los tres de Madrid libres, en el medio
de tramos abiertos de 9–16 noches → venderla no crea huérfanas (los restos quedan ≥4 noches).

**Cotización (paridad ×0,8124 sobre canal, limpieza 60 € incluida, redondeo arriba)** · canal:
343 (NICA) / 325 (ALEX) / 292 (MARE) → directo: **280 / 265 / 240 €**. Neto tras coste real de
limpieza: ~226 / 221 / 196 €, todos 1,4–1,8× su ADR de equilibrio.

**El contexto de mercado que respaldó no regalar** (comp set 267 pisos 1BR, leído 31/08):
p25 149 · p50 185 · p75 236 · p90 321. Publicados estamos en p75–p90; en directo el huésped
paga mediana-p75 por pisos del cuartil alto (MARE directo queda −3 % vs mediana). Mercado 33 %
vendido a 62 días (+6,5 pp vs STLY 26,3 %), cierre LY de esa noche: 96 %. **Hallazgo**: la zona
aún NO repreció el puente (p50 del 31/10 = 185 < p50 del sábado normal 24/10 = 194, y el viernes
publicado más caro que el sábado) — es finde largo en Madrid (festivo trasladado al lunes 02/11)
y la competencia no se enteró; nuestros precios ya lo tenían puesto. Hotel 4★ centro esa noche:
~305 € (tarifa fechada, Trip.com, con caveat) → el directo queda −8/−21 % vs habitación de hotel.

**Lo que nació de acá** · `docs/operativa/DIRECTAS.md`: fórmula de paridad (con la trampa del
doble descuento de limpieza, que estuvo a punto de pasar), términos de pago (100 % transferencia
en ≤2 noches / señal 50 % + saldo efectivo — cicatriz Magnoli: el efectivo nunca bloquea; no
reembolsable con UN cambio de fecha ≥7 días; validez 48 h) y la plantilla definitiva del mensaje
fijada por Stag, con sus reglas de voz (§4.2). Los 100 € a Claudio NO eran el coste de cobrar
efectivo (cubrían relevamiento + puerta de Marechal + recogida) — corregido en CASUISTICAS §1.4.

**Estado** · Presupuesto enviado el 31/08 con validez 48 h. **Medir ~02/09**: si reservó (qué
piso, qué método de pago) o si se dejó vencer — y anotar acá el resultado. Si entra: reserva
manual `confirmed` + Record a payment con nota (DIRECTAS §5). Sin tocar PriceLabs: la reserva
manual ignora el min-stay.
