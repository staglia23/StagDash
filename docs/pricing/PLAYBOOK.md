# Playbook de pricing — Samavi

**Qué es esto**: las reglas permanentes de revenue management de Samavi. Cada regla nació de
un error que costó dinero o credibilidad; por eso cada una lleva su **cicatriz** (la fecha y el
incidente que la produjo). Una regla sin su porqué se descarta a la primera; con la cicatriz, no.

**Cuándo se lee**: SIEMPRE antes de tocar un precio, un mínimo, un min-stay o una promoción.
No se responde de memoria sobre qué hay publicado — se lee el estado real (§1).

**Qué NO es**: no es el histórico. Lo que se probó y qué pasó vive en [BITACORA.md](BITACORA.md).
El estado de hoy vive en [ESTADO.md](ESTADO.md).

---

## 1. Checklist obligatorio para cambiar un precio

Ningún paso es opcional. Los cuatro incidentes más caros del proyecto fueron saltarse uno.

**Antes de escribir**
1. **Leer el estado real**, nunca la memoria: `get_listing_date_overrides` del piso y rango,
   y `select … from pricelabs_prices` del calendario sincronizado. Si no coinciden entre sí,
   parar y averiguar por qué antes de tocar nada.
2. **Calcular el precio que verá el huésped**, no el publicado: aplicar los descuentos nativos
   de Airbnb vigentes (§3) y comprobar el peor apilamiento posible.
3. **Elegir la herramienta correcta** (§2): `min_price` para no bajar, `price` fijo para bajar.

**Al escribir**
4. Escribir **siempre** con `reason`: `<fecha> <quién> <intención> <cuándo se revisa>`. El
   `reason` es la firma forense del sistema (§2.6).
5. **Verificar el bloque `overrides_after_update`** que devuelve la API. Si aparece un campo que
   no mandaste (un `price` porcentual viejo, por ejemplo), el merge lo conservó: borrar y recrear.

**Después de escribir**
6. `refresh_listing_pricing` y **leer el `pricing_array`** de las fechas tocadas: ahí se ve el
   precio que realmente quedó, que puede no ser el pedido (el algoritmo puede subir por encima
   de un `min_price`).
7. **Pedirle el push a Stag** ("Sincronizar Ahora" por piso) y verificar `last_date_pushed`
   posterior a la hora del cambio. Sin push, el canal sigue con el precio viejo.
8. **Verificar el último eslabón**: lo que ve el huésped en Airbnb. No decir "aplicado" mientras
   falte un paso fuera de mi control (§5.3).
9. **Anotar en la bitácora** qué se aplicó, con qué hipótesis y cuándo se mide.

---

## 2. Reglas duras de PriceLabs

**2.1 · Nunca descuentos porcentuales en overrides.**
El descuento va en Airbnb (muestra precio tachado, empuja ranking); el suelo y el precio van en
PriceLabs. Un `price_type: "percent"` en PriceLabs se **suma** al descuento nativo de Airbnb sin
ninguna señal visual: se pierde margen sin ganar visibilidad.
*Cicatriz 05/08/2026*: los overrides del 03/08 eran `-15/-20 %` + suelo. El huésped de última
hora pagaba recomendado × 0,80 × 0,85. Nicasio 14/08: recomendado 158 → el huésped veía 110,50,
cuando esas noches se vendieron a 140,60 el año anterior.

**2.2 · `min_price` evita bajar; NO obliga a bajar.**
Para forzar un precio hacia abajo hace falta `price` con `price_type: "fixed"`. Poner un
`min_price` más bajo solo suelta el freno: el algoritmo puede quedarse arriba igual.
*Cicatriz 06/08/2026*: Alexander 13/08 con suelo bajado a 119 publicó 123, porque su
recomendación había subido. En Marechal hubo que usar `price` fijo para que bajara de verdad.

**2.3 · El update hace MERGE, no reemplazo.**
Para **quitar** un campo (un `price` porcentual, un `min_stay`) hay que `delete` y volver a crear.
Mandar solo los campos nuevos deja vivos los viejos, invisibles.
*Cicatriz 09/08/2026*: Jacobine conservaba un `-20 %` manual del 06/08 debajo del suelo nuevo;
lo delató el bloque `overrides_after_update` y hubo que borrar y recrear.

**2.4 · Recalcular ≠ publicar.**
`refresh_listing_pricing` mueve `last_refreshed_at` pero **no** `last_date_pushed`. El MCP no
tiene función de push: lo dispara Stag desde la UI ("Sincronizar Ahora", arriba a la derecha de
Review Prices) o el sync automático diario (~06:00–07:00 UTC). "Guardar y Actualizar" del panel
izquierdo solo guarda Mínimo/Base/Máximo: **no publica**.
*Cicatriz 03/08/2026*: los precios quedaron correctos dentro de PriceLabs y Airbnb publicó los
viejos durante horas. Lo detectó Stag, no el sistema.
*Actualización 05/09/2026*: la hora del refresh+push **es por piso y se mueve** — observado el
03–04/09: ALEX 05:18, MARE 07:51→08:37, NICA 09:49, JACO 11:01 UTC. El "~06:50" no es universal:
antes de dar algo por publicado, leer `last_date_pushed`; y al programar una routine "antes del
sync", saber que la de las 05:15 corrió **3 minutos** antes del refresh de Alexander.

**2.5 · Los suelos del anuncio mandan; un override que baja el suelo propio es casi siempre un error.**
Cada listing tiene su `min` configurado. Si el 67–100 % de las noches se venden AL mínimo
mientras se le gana al mercado por 20–40 puntos de ocupación, el mínimo está mal calibrado —
la respuesta no es bajarlo más, es revisarlo hacia arriba.
*Cicatriz 05/08/2026*: los overrides ponían suelos por debajo del `min` del propio anuncio en los
cuatro pisos a la vez.

**2.6 · El campo `reason` es la firma forense.**
Mis overrides llevan siempre motivo fechado. Los que aparecen con `reason` **vacío** son ediciones
manuales desde la UI. Comparar `updated_at` + `reason` permite saber quién cambió qué y cuándo,
que es la única forma de detectar que el plan vigente ya no es el que se aplicó.
*Cicatriz 13/08/2026*: el plan del 09/08 (Marechal 93/115/105) había sido reemplazado el 12/08
a las 08:15 UTC por 84/119 con motivo vacío, y el análisis se estaba haciendo sobre datos falsos.

**2.6-bis · CTA/CTD: la máscara es al revés de lo intuitivo, y `1` significa PERMITIDO.**
Los campos son `check_in_check_out_enabled` ("0"/"1"), `check_in` y `check_out` — los dos últimos,
string binario de 7 caracteres **lunes→domingo**, donde **`1` = permitido y `0` = cerrado**. Para
cerrar las llegadas de un viernes se manda `1111011`. Hay que enviar SIEMPRE los tres campos.
Requisito previo: la función tiene que estar activada a nivel listado (Stay Restrictions →
Check In/Check Out), y eso **solo se hace por UI** — `update_listing_data` solo acepta
min/base/max/tags. Se comprueba en el `pricing_array`: `1111111` = activa y neutra, `-1` = sin
activar. Al reescribir un override que ya tenía `min_stay`, reenviar el objeto COMPLETO
(min_stay + reason + los tres campos CICO) o se pierde lo que no se manda.
*Cicatriz 17/08/2026*: se aplicaron los cierres de los días de vuelo de Stag (06/11, 15/11 y
19/01) y se descubrió que ALEX y JACO tenían la función sin activar mientras NICA y MARE ya
estaban en `1111111` — el override se guarda igual, así que el fallo sería silencioso.

**2.7 · `price_type` SIEMPRE `"fixed"`. Nunca `"percent"` — ni en la API ni en la UI.**
En el formulario de override, el campo de precio tiene un selector fijo/porcentaje. Si queda en
porcentaje, escribir `149` **no publica 149 €: publica +149 % (×2,49)**.
*Cicatriz 10–11/08/2026*: se cargaron `99`, `149` y `129` como porcentaje desde el móvil (00:31,
21:35 y 10:13). Marechal publicó las noches 22–25 a **190–281 €**, entre 1,6 y 1,8 veces el
percentil 90 del barrio, durante los únicos días en que ese bloque estuvo abierto a la venta.
Es la tercera aparición del mismo anti-patrón (03/08, 05/08, 10–11/08).
**El cortafuegos es la guardia de precios, no un techo.** Se propuso poner un `max_price` y
**Stag lo rechazó el 14/08/2026**: no quiere topes que aten al algoritmo. En su lugar asumo yo la
vigilancia — ver §5.7. Los cuatro pisos siguen con `max` = null a propósito.

**2.8 · Un bloqueo rotulado "Control" en Guesty es de Stag. No es un hueco.**
Stag viaja a inspeccionar los pisos y bloquea esas noches él mismo, rotulándolas **"Control"**.
Son deliberadas: **no se desbloquean, no se cuentan como noches por vender, no entran en ningún
cálculo de "euros sobre la mesa"**. Antes de analizar cualquier noche bloqueada, leer su rótulo
en el calendario de Guesty.
*Cicatriz 13–14/08/2026*: se dedicó un diagnóstico entero a averiguar por qué no se vendían las
noches 22–25 de Marechal, se estimaron 369 € recuperables y se le pidió a Stag que abriera
Guesty — eran su viaje de control. Jacobine 18–20/08 es el mismo caso.
*Ampliación 15/08/2026*: los bloqueos personales (amigos, familia) se rotulan **"Personal —
<motivo>"** y Stag avisa por chat; se registran en ESTADO §4. Un bloqueo sin reserva y sin rótulo
conocido se PREGUNTA antes de analizarlo o tocarlo.
*Cicatriz 15/08/2026*: Jacobine 13–14/11 aparecieron bloqueadas sin reserva la misma tarde en que
se aplicaba el min-stay de esa semana — eran un casamiento de amigos de Stag; el min 7 recién
escrito dejó el hueco 8–12 invendible hasta reajustarlo a 5.

**2.9 · Los bloqueos de calendario son invisibles para el motor.**
`guesty-sync` **no** ingesta bloqueos: la tabla `reservations` solo guarda `canceled`, `closed`,
`confirmed`, `declined`, `inquiry` y `reserved`. Por eso **"noches libres según Guesty" puede
mentir**: una noche bloqueada aparece como libre. La única señal es
`pricelabs_prices.booking_status = 'Blocked'` (o `demanda='Unavailable'` con `reservado=false`).
Al listar noches libres, excluir siempre las bloqueadas.
*Cicatriz 13/08/2026*: se planificó, se aplicó precio y se monitorizó durante días un bloque de
4 noches de Marechal (22–25/08) que estaba **cerrado a la venta**. Ninguna pantalla lo gritó.
Ojo al contar: hay un artefacto de borde en las 2 últimas fechas sincronizadas del horizonte
(migración 064) que también aparece como no vendible y no es un bloqueo real.
*Trampa gemela, 31/08/2026*: al revés también miente. Tras cancelarse una reserva, `get_listing_prices`
puede seguir devolviendo `booking_status: "Booked"` con la `booked_date` vieja **mientras `occupancy` ya es 0
y `ADR` es −1**: el estado quedó fantasma. **Para saber si una noche se vendió, mirar `occupancy` (y
`unbookable`), nunca `booking_status`** — y contrastar con `reservations`. Toda routine que decida "no tocar
porque ya se vendió" tiene que usar esos campos, o se queda paralizada ante un fantasma.
*Trampa tercera, 05/09/2026*: **`user_price` (nuestro `precio_usuario`) NO es un override.** La
knowledge base de PriceLabs lo define como "el último precio que el sistema vio en el PMS cuando
empujó tarifas": es el `price` del refresh anterior. Verificado en Marechal: en las 10 noches libres
del 20/10–04/11 el `user_price` de hoy era exactamente el `price` de ayer, sin ningún override. Los
overrides se leen SOLO con `get_listing_date_overrides`. Consecuencia: `f_pricelabs_oportunidades`
(/precios) usa `precio_usuario` como "publicado" y mide otra cosa — rediseño pendiente (ESTADO §5).
*Actualización 15/08/2026 (guesty-sync v8 + migración 081)*: los bloqueos YA NO son invisibles —
guesty-sync ingesta el calendario de Guesty con sus bloqueos y **su rótulo** → tabla
`guesty_bloqueos` / vista `v_bloqueos` (refresco cada 3 h, ventana 365 días). Ante una noche
'Blocked', el primer reflejo es `select tipo, nota from v_bloqueos where codigo=… and fecha=…`:
tipo m = manual de Stag (la nota dice por qué), bw = ventana de reserva, an = antelación mínima.
La señal de PriceLabs queda como contraste, no como única fuente.

**2.9 · Personalizaciones por defecto que la API no expone** (confirmadas por capturas, activas de
fábrica; se cambian solo por UI: Review Prices → Customizations → All Customizations):
- **Último Minuto** "Market Driven (Balanced)": hasta **−40 %** el mismo día, decreciendo a 0 % a
  los 11 días.
- **Días Huérfanos**: **−20 %** en huecos de ≤2 noches.
- **Factor de Recencia**: +5 % (sin reservas en 15 días) → +15 % (45 días).
- **Incremento de Fechas Lejanas**: **+18 %** más allá de 60 días. *No tocar*: ahí entra el 71 % de
  las reservas.
- **Precio Mínimo de Seguridad**: 110 % del ADR del año pasado más allá de 180 días. *No tocar.*

Para que el descuento de último minuto muerda, el recomendado debe superar el suelo × 1,67. Con
los suelos actuales casi nunca pasa — por eso se decidió (05/08) no tocar estas personalizaciones.

**2.10 · Un suelo solo es gratis si nace por DEBAJO del precio publicado — y nunca por encima del 140 % del `precio_base`.**
"Un suelo no cuesta nada si no se vende" (§4.4) vale solo para suelos INERTES. Un `min_price` por
encima de lo que el algoritmo publica no es un seguro: es una subida de escaparate disfrazada, y en
modelo comisión una noche perdida cuesta el 25 % de TODO su bruto (una noche de Karol G: ~224 €).
Antes de escribir un suelo, leer el publicado de esa noche y quedarse por debajo (típicamente 88–92 %).
*Cicatriz 20/08/2026*: el plan v1 proponía Karol G a 1.039 sobre 935 publicados, Feria a 706 y
pre-Feria a 555 sobre 443–455 — tres subidas con nombre de seguro — y 5 de los 7 suelos de la
cobertura 19–25/04 mordían (el 20/04 publicaba 500 sobre base 312, +60 %). La auditoría las tumbó todas.
*Trampa descubierta al borrarlos (20/08/2026)*: al quitar un override la noche NO cae al precio de
demanda si la agarra el **Precio Mínimo de Seguridad** (110 % del ADR del año pasado, >180 días) —
y como su STLY va por día de semana, el 20–22/04/2027 heredó precios de Feria 2026 y quedó clavado
a 544/544/698 (149–174 % del base). Se suelta solo al entrar en los 180 días (~22/10/2026).

---

## 3. Reglas duras de Airbnb

**3.1 · Descuentos nativos vigentes** (se aplican POR DEBAJO del precio que empuja PriceLabs, así
que todo suelo se calibra ×1/0,85):

| Descuento | Condición | Valor | Estado |
|---|---|---|---|
| Última hora | ≤14 días de antelación | **−15 %** | activo |
| Reserva anticipada | ≥3 meses | **−10 %** | activo |
| Semanal | ≥7 noches | −5 % | activo |
| Mensual | ≥28 noches | −12 % | activo |
| Viajeros con valoraciones excelentes | 4,8+ y 3 evaluaciones | — | **no activar** (margen regalado) |

**El −15 % de última hora es igual en los cuatro pisos.**
*Cicatriz 07/08/2026*: se infirió un −20 % para Marechal a partir de una sola observación y se
publicó 99 € cuando debía ser 93 €. Stag lo corrigió. **Regla derivada: una configuración externa
que no puedo leer por API no se usa en un cálculo hasta que Stag la confirma** (§5.1).
*⚠️ NO VERIFICADO (05/09/2026)*: hay un **−10 % que no aparece como promoción** en 9 de 13 reservas de
Airbnb desde el 05/08 con 30–160 días de antelación, en los 4 anuncios: el huésped paga el 90 % del
publicado y la reserva no trae línea PROMOTION (4 reservas pagaron el 100 %). No es la anticipada de esta
tabla, que llega como línea "Early bird" y arranca a los 88–100 días; tampoco es markup de Guesty. Hasta que
Stag lo identifique en el desglose de `HMR5SYFTDZ` en Airbnb, asumir que en la ventana de 1–3 meses el
huésped puede estar viendo **0,9× el publicado** — y el percentil de §4.2 va 10 % optimista ahí. Detalle:
BITACORA 05/09, Resultado.

**3.2 · Apilamiento.** Los descuentos se combinan: mensual + anticipada ≈ −21 %; semanal + última
hora ≈ −19 %. El suelo debe aguantar el **peor apilamiento posible** y seguir por encima del ADR
de equilibrio.

**3.3 · La comisión de canal se cobra también sobre la limpieza.** Verificado al céntimo
(18,64–19,32 % según piso). Por eso la tarifa de limpieza **no es un ingreso neto** y no sirve
como palanca de conversión: hoy ya va en pérdida. Coste real por reserva: Marechal y Alexander
**43,80 €**, Nicasio **53,72 €**. Cobrando 50 € en Marechal entran 40,62 € → **−3,18 € por
reserva**. Para cubrir coste habría que cobrar ~53,91 € (MARE/ALEX) y ~66,12 € (NICA).
*Cicatriz 13/08/2026*: PriceLabs recomienda bajar la limpieza a 41 € en los tres pisos de Madrid
(es una plantilla de mercado que ignora nuestro coste). Aplicarlo habría costado ~2.365 €/año.
**Descartada con número, no con opinión.**

**3.4 · Asimetría que decide dónde poner el descuento.** El descuento de Airbnb muestra **precio
tachado** (atrae clics y empuja ranking); el de PriceLabs solo baja el precio, sin señal visual.
Mismo coste, distinto efecto. Por eso: descuento en Airbnb, suelo en PriceLabs.

---

## 4. Cómo se decide un precio

**4.1 · La pregunta correcta ante una noche vacía** no es "¿bajo o no bajo?" sino
**¿está vacía por precio, por forma del hueco, o porque el mercado también está vacío?**
Solo la primera se arregla con tarifa.

**4.2 · El percentil se calcula sobre el precio que VE EL HUÉSPED** (publicado × 0,85 dentro de la
ventana de 14 días), nunca sobre el publicado. PriceLabs no conoce el descuento nativo y su
recomendación nos coloca en una mediana en la que ya estamos.

**4.3 · La elasticidad medida en el rango p22–p76 es ~0.** Marechal en percentil 22–30 hace la
misma ocupación que Nicasio en p70–76: mismo edificio, mismo comp set, cuartil de precio opuesto.
Bajar dentro de ese rango no compra ocupación, solo regala margen.
*Cicatriz 07–09/08/2026*: Marechal estuvo a percentil ~10 varios días y no vendió ni una noche de
agosto, mientras vendía septiembre y octubre a 184–228 €/noche sin descuento.

**4.4 · Perecedero vs no perecedero.** Con ≤7 días y noche vacía, el precio agresivo es correcto
(compite contra 0 €). A >10 días no es perecedera: bajar ahí es regalar. Toda bajada táctica lleva
**escalón automático** (fecha y precio de reversión decididos al aplicarla).

**4.5 · El único umbral objetivo es el punto de equilibrio.** No se inventan targets.
Equilibrios ADR (YTD 2026): **Nicasio 124 · Alexander 159 · Marechal 136 · Jacobine 189**.
Suelo marginal (nunca vender por debajo): 11–14 €/noche en Madrid; 71 € en Jacobine
(sostenibilidad de la dueña). Comisión de canal medida: 18,2–18,7 %.

**4.6 · Temporada media-alta no se toca.** Cuando septiembre/octubre ya van 22–28 de 30 noches
vendidas a 160–230 €/noche, la escasez trabaja sola: cualquier rebaja ahí es regalar.

**4.7 · Huecos cortos.** Los huecos de 1 noche se venden el 1,4 % de las veces contra el 51 % de
los huecos largos. Min-stay 1 está **autorizado en Nicasio y Alexander** (decisión de Stag,
09/08/2026) y **prohibido en Marechal**, que conserva la restricción.

**4.8 · Noche liberada por cancelación: primero el min-stay, después el precio — y "lo que pagaba el
que se fue" se TRADUCE a publicado, no se copia.**
PriceLabs no tiene lógica ni aviso de cancelación (confirmado en su knowledge base, 29/08/2026): al
liberarse, la noche se reprecifica como una libre cualquiera con la antelación que tenga en ese
momento (huérfano −20 % si el hueco es ≤2 noches, curva de último minuto, freno en el `min` del
anuncio). Tres reglas:
1. **Min-stay = longitud del hueco, el mismo día.** Con min-stay > hueco la noche vale 0 € y ninguna
   pantalla lo grita (Alexander 07–08/09/2026 quedó con min-stay 3 sobre un hueco de 2).
2. Si el objetivo es "no cobrar menos que la reserva caída", el suelo se calcula sobre el **NETO**:
   `publicado = (neto_objetivo ÷ 0,8124 − limpieza) ÷ noches ÷ 0,85` dentro de los 14 días (0,8124 =
   payout de Airbnb medido en 2026; 0,85 = el −15 % de última hora, §3.1; fuera de la ventana, ÷1).
   Copiar el ADR del que se fue como `min_price` se queda corto un 25–35 %: 275 € cash de Magnoli
   son **170 €/noche publicados**, no 124 ni 155.
3. Toda escalera descendente se **programa** (routines a las 05:15 UTC, antes del sync diario que
   publica ~06:50) y se anota con su fecha de medición.
4. **En un hueco huérfano el `min_price` es el PRECIO, no un piso.** El −20 % de días huérfanos
   hunde la recomendación por debajo del suelo, así que el publicado queda clavado en el suelo: se
   limita la caída pero **no se captura ninguna subida de mercado** (ALEX 08/09/2026: publicaba 168
   con recomendado 176). Tenerlo en cuenta al calibrar: el suelo de un huérfano hay que elegirlo
   como si fuera el precio de venta.
5. **Una routine que decide con el estado de ayer necesita un canal de memoria que no dependa de
   GitHub.** Si el push falla, la corrida siguiente arranca ciega. Memoria primaria: su propio mail
   del día anterior; secundaria: el campo `reason` del override, que siempre está. Cada routine relee el estado antes de
   escribir y no toca nada si el hueco ya se vendió o si los overrides no son los esperados.
6. **Cancelación lejana (≥ T−40) en un mes que el barrio cierra por encima del 90 %: la respuesta
   por defecto es NO tocar el precio.** PriceLabs reprecia solo (y suele venir subiendo por demanda);
   lo único que se verifica el mismo día es que el huérfano vecino salga del modo huérfano (min-stay
   y −20 %) y que el recálculo no hunda el bloque (si cae >10 %: suelo INERTE al 90 % del ask, con OK
   de Stag). Se reevalúa a T−30 con el pace del barrio, y el orden sigue siendo min-stay antes que
   precio. *Origen 05/09/2026*: Marechal 21–27/10 (`HMY5R38DJM`, 1.057 €) liberada a 46 días — los
   asks ya estaban en p72–p81 del compset y +36–50 % sobre la mediana pagada, con el barrio 9–19
   puntos por delante del año pasado y pickup al doble. Subir no tenía sustento; bajar, menos.
*Origen 29/08/2026*: Alexander 07–08/09, reserva directa F&F de 275 € cash liberada a 9 días. Claude
recomendó min-stay 2 + suelo inerte y, si la cancelación era decisión propia, no cancelar (231 € netos
ciertos vs ~100 esperados). Stag decidió liberar y cobrar "igual o más" (escalera con suelo 170) y
**al día siguiente (30/08) cambió el objetivo a LLENAR sin suelo**: escalera 162/175 (= mediana de lo
reservado en el comp set ÷ 0,85) → 147/153 (D−5) → sin suelo, mín 129 (D−3) → min-stay 1 (D−1).
Dato de mercado que manda en este caso: en septiembre las reservas del comp set entran **1–9 días
antes** — la ventana de compra de una noche liberada a ≤10 días es *ahora*, no "cuando baje".
La evidencia y las hipótesis están en la bitácora; **medición el 09/09**.

**4.9 · Una noche no puede tener más precios que syncs le queden — y el último precio se pone el D−1, no el día D.**
PriceLabs publica al canal **una vez al día** (~06:50 UTC en el caso medido; la hora es por piso y se mueve, §2.4). Una escalera de tres escalones para una noche a la
que le quedan dos syncs se ejecuta como dos: el peldaño intermedio vive de madrugada y **no lo ve ningún
comprador**. Antes de diseñar una escalera, contar los syncs restantes de cada noche — ése es el número máximo
de precios que puede tener. Y el peldaño más bajo va en el **D−1**, no en el día mismo: el día D no compra nada
(Nicasio: cero ventas same-day en 14 meses) y es el único coste que **no caduca**, porque el precio de esa noche
entra en la serie STLY y el Precio Mínimo de Seguridad (110 % del ADR del año pasado, por día de semana)
gobierna esa misma noche del año siguiente hasta ~T−180.
*Origen 31/08/2026*: el primer diseño de la bajada del hueco de Nicasio daba 2/3/3/4 escalones a cuatro noches
que tenían 1/2/3/4 syncs por delante, con el fondo (110/115) puesto en el día D. La revisión lo tumbó: se
rediseñó a un escalón por sync, con suelo duro en el D−1.

**4.10 · Para bajar, `min_price` — no `price` fijo — y siempre que el recomendado ya esté por debajo.**
Si el `uncustomized_price` de PriceLabs está por debajo del suelo (el caso típico de una noche perecedera:
la curva de último minuto ya empuja hacia abajo y el mínimo del anuncio la frena), **bajar el `min_price`
basta para bajar el publicado** y el override pisa el mínimo del anuncio. Se prefiere a `price` fijo por su
**modo de fallo**: si una routine no corre, la noche se queda en el precio más CARO, no en el más barato.
Es la antítesis exacta de la cicatriz de §5.4. Comprobar siempre en el `pricing_array` que publica el suelo:
si publica MÁS, el suelo no está mandando (§2.2) y esa fecha no se vuelve a bajar; si publica MENOS, parar,
porque se rompió un supuesto.

---

## 5. Doctrina de trabajo con Stag

**5.1 · Lo que no puedo leer, lo pregunto.** Configuraciones externas (promos nativas de Airbnb,
personalizaciones de PriceLabs, bloqueos manuales) no se infieren de una observación: se confirman
con Stag o con una captura antes de meterlas en un cálculo. Mientras no estén confirmadas, se
marcan como **no verificadas** en la bitácora.

**5.2 · La cadencia la marca la perecibilidad, no el ritual.** En ventana corta se actúa **el mismo
día**. Un marco de revisión cada 48 h es demasiado lento para inventario que caduca en 3 días.
*Cicatriz 07/08/2026*: Stag pidió acción inmediata y se le propuso esperar la revisión.

**5.3 · Verificar el último eslabón.** Nunca decir "aplicado" si falta un paso fuera de mi control.
El eslabón que cuenta es Airbnb (lo que ve el huésped), no PriceLabs.

**5.4 · Una reserva no es dinero hasta que pasa su ventana de cancelación.** Al reportar pickup,
comprobar `status` y etiquetar lo reciente como sujeto a cancelación.
*Cicatriz 13/08/2026*: la reserva que se presentó como la prueba del éxito del test (Nicasio
11–14/08 a 144 €/noche) se canceló cinco días después y se revendió a 93,50 €/noche.
*Actualización 29/08/2026*: la reventa a 93,50 € NO fue obra de la curva de último minuto:
`get_user_logs` muestra un `price` FIJO de 130 escrito a mano el 10/08 (00:09 UTC) y 110 a las 09:55
UTC desde el móvil, con el reason viejo del test, y 99 el 12/08; 110 × 0,85 = 93,50. La lección de
§5.4 (una reserva no es dinero hasta pasar su ventana) sigue en pie; la de "el último minuto regala"
no se sostiene con ese caso — lo que regaló fue un precio fijo sin escalón.

**5.5 · Un ADR de una sola reserva no es un precio de mercado.** Puede llevar suplementos por
huéspedes extra, tarifas de limpieza o ajustes. Antes de sacar conclusiones, mirar el desglose.

**5.6 · Los cambios de precio se aplican SOLO con confirmación explícita de Stag**, y cada uno
queda registrado en la bitácora con su motivo y su escalón de reversión.

**5.7 · Guardia de precios: la vigilancia es mía, no de un tope.**
Stag rechazó el `max_price` (14/08/2026) porque no quiere atar al algoritmo. A cambio, **la
obligación de detectar un precio irrisorio o disparatado es mía, todos los días**, en los cuatro
pisos. El monitor diario compara el precio publicado de cada noche libre contra su banda sana y
avisa; si algo llama la atención, se revisa antes de que salga al canal, y solo se cambia con el
OK de Stag.
Banda de alarma por noche (sobre el precio **publicado**, antes de descuentos nativos):
- **Alarma por bajo**: menos del 70 % del precio recomendado por PriceLabs para esa noche, o por
  debajo del suelo del anuncio, o por debajo del ADR de equilibrio del piso sin que sea una
  bajada táctica aprobada y anotada en la bitácora.
- **Alarma por alto**: más del 140 % del recomendado, o por encima del percentil 90 del comp set.
  Este es el lado que se llevó el incidente de los porcentajes (§2.7): 190–281 € publicados
  durante tres días sin que nada avisara.
Ante una alarma: primero mirar si hay un override raro o un `price_type` en porcentaje, después
avisar a Stag con el número, la banda y la causa probable.

---

## 6. Datos de referencia

- **Comp set** (idéntico para los tres de Madrid: mismo edificio, misma lat/lng): ~259 pisos de
  1 dormitorio en La Latina / Plaza Mayor. Se consulta con `get_neighbourhood_data`.
- **Mínimos y base por piso**: ver [ESTADO.md](ESTADO.md) — cambian, no se citan de memoria.
- **Subida estructural de mínimos** prevista para el **01/10/2026** vía Custom Seasonal Profile
  (NO antes): NICA 150→160, ALEX 129→145, MARE 99→115→121 (dos pasos), JACO 155→170. Evidencia:
  oct–dic 2025 rindió ADR +12 %/+32 % vs verano sin perder ocupación. Rollback: apagar el perfil
  a las 2 semanas si el pickup no responde.
- **Modelo de ingreso por piso**: Nicasio (titular), Alexander y Marechal (subarriendo) → todo el
  margen es de Samavi. Jacobine (comisión 25 % + IVA) → cada noche vendida aporta poco a Samavi
  pero sostiene la relación con la dueña.
