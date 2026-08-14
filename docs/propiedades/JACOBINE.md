# Jacobine (1A_JACO)

> El único piso en **modelo comisión** y el único fuera de Madrid: Samavi no paga renta ni
> suministros acá, solo se queda el 25 % del bruto — y por eso su economía no se compara con la de
> los otros tres. Su rasgo propio de 2026: **el calendario está cerrado a partir del 09/02/2027**
> por una ventana de reserva de ~6 meses que ningún otro piso tiene.

*Ficha construida el 14/08/2026 contra el motor SQL y PriceLabs en vivo. Los importes de negocio
son del rango **01/01/2026 – 31/08/2026** salvo que diga otra cosa.*

---

## Identidad

| Campo | Valor |
|---|---|
| Código | `1A_JACO` |
| Nombre en Guesty | `SEV_JACOBINE` |
| PriceLabs `listing_id` | `684f06ec655a18002949024a` (`pms` = `guesty`) |
| Airbnb | `1442571300903459334` |
| Booking.com | `16710783` (conectado, **cero reservas confirmadas** desde que se gestiona) |
| Modelo de negocio | **comisión** (`listings.modelo = 'comision'`) |
| Bajo gestión desde | **01/06/2025** (`listings.fecha_inicio`) |
| Ciudad | Sevilla — zona Feria / Alameda (según el nombre del anuncio en PriceLabs) |
| Dormitorios | **2** (`no_of_bedrooms` de PriceLabs, 14/08/2026) |
| Limpieza que se **cobra** al huésped | **60 €/reserva** (`cleaning_fees` de PriceLabs, 14/08/2026) |
| Limpieza que **cuesta** a Samavi por reserva | **0,00 €** (`listings.limpieza_por_reserva`) — no se paga por reserva sino por la cuota fija mensual, ver abajo |
| Renta base | **0,00 €** — no hay contrato de alquiler |
| Banco por el que entra | Revolut (`listings.banco`) |

No comparte edificio con nadie: Nicasio, Alexander y Marechal están los tres en el mismo edificio de Madrid
(Madrid); Jacobine está sola en Sevilla. Eso explica que su limpieza, sus amenities y su manitas
sean otra gente y otro circuito.

---

## Cómo gana dinero

**Samavi no es la titular ni la inquilina: es la gestora.** No hay renta que pagar, ni
suministros, ni comunidad (las tres columnas están en 0 en `listings`). Lo que entra es
**comisión sobre el bruto**:

- Se factura a la dueña el **30,25 % del bruto** (`listings.comision_pct = 0,3025`).
- Ese 30,25 % es **25 % de comisión + 21 % de IVA**. Los 5,25 puntos de IVA son plata de Hacienda
  de paso: **no son ingreso** y no entran al margen (`listings.iva_pct = 0,21`, migración 021).
- **El ingreso real de Samavi es el 25 %.** Todo cálculo de equilibrio y todo simulador usan 0,25,
  nunca 0,3025.
- La base es el **bruto post-descuento** (`host_payout + host_service_fee`), no la tarifa antes de
  promociones (migración 013). Incluye la tarifa de limpieza que paga el huésped.

**Ene–ago 2026 (motor, 14/08/2026):**

| | € |
|---|---|
| Bruto gestionado | **49.350,62** |
| Ingreso Samavi (25 % neto) | **12.802,00** |
| IVA repercutido (no es ingreso) | 2.688,42 |
| Lo que le queda devengado a la dueña | **19.188,89** (`v_cuenta_duena`, ya neto de comisión, IVA, comisión de canal, los 700 €/mes de limpieza y los recobros) |

**Lo que esto le hace al margen:** en subarriendo (Alexander, Marechal) la renta ya está pagada y
cada noche extra cae casi entera a contribución. Acá **no**: cada noche vendida aporta solo su
25 %. Vender una noche más a 250 € deja **62,50 €** de ingreso, no 250. Por eso Jacobine necesita
**más ADR** que los otros para mover la aguja, y por eso su palanca fuerte no es el precio marginal
sino **el volumen de bruto gestionado**.

**La otra cara, que es enorme:** la **comisión de canal la soporta la dueña, no Samavi**. Airbnb se
llevó **9.112,36 €** ene–ago (18,5 % del bruto) y esa línea sale del bolsillo de ella
(`comision_canal_samavi = 0,00` en el P&L). En los pisos de Madrid ese mismo coste es el mayor
gasto directo de Samavi. Acá es cero riesgo.

**Costes que sí paga Samavi (ene–ago 2026):**

| Concepto | € |
|---|---|
| Directos (`otros`: amenities, lavandería, termo, toallas, coste laboral del empleado, retención del 111) | 1.226,64 |
| Cuota de overhead (prorrateo por días bajo gestión, 25 % del pool) | 8.830,83 |
| **Total costes** | **10.057,47** |
| **Margen neto** | **2.744,53** (21,4 % del ingreso · **13,86 €/noche**) |

El **87,8 % de sus costes es overhead**, no gasto propio. Traducido: Jacobine casi no tiene coste
directo — lo que la lastra es su cuarta parte de la estructura de Samavi.

**La limpieza pactada.** A la dueña se le descuentan **700 €/mes fijos** en concepto de limpieza
(`listings.refactura_limpieza_mes`). Con eso Samavi paga a el empleado de Sevilla, que limpia el piso
(no es Ecocleans, que solo hace Madrid). Los números, verificados contra banco el 26/07/2026:

- Coste laboral mensual **688,86 €** (el desglose de nómina y cotización vive en el proyecto Admin & Fiscal, no en este repo)
- Contra los 700 € refacturados → `event` mensual **+11,14 €**
- Menos la retención del modelo 111 → `event` mensual **−10,56 €**
- **Neto real para Samavi: +0,58 €/mes.** La refactura de limpieza no pierde plata, pero tampoco
  gana: es un pass-through, no un negocio.

---

## Los números que mandan

*Todo de `f_breakeven` / `f_ranking` / `f_pnl_mensual_propiedad` con rango 01/01/2026–31/08/2026,
consultado el **14/08/2026**.*

| Métrica | Valor | Lectura |
|---|---|---|
| **ADR bruto de equilibrio** | **203,18 €** | a las noches que vende hoy, es el precio medio que cubre exactamente los costes |
| ADR real | **249,25 €** | vende **46 € por encima** de su equilibrio |
| **Contribución por noche** | **64,66 €** | lo que le queda a Samavi por cada noche vendida (25 % del bruto medio) |
| Ocupación actual | **81,48 %** | 198 noches vendidas de 243 disponibles |
| Ocupación de equilibrio | **64,01 %** | 156 noches |
| **Colchón** | **+17,47 pp** | 42 noches de margen |
| RevPAR bruto | 203,09 € | contra un RevPAR de equilibrio de 165,55 € |
| Reservas | 56 | ALOS 3,4 noches |
| Ingreso Samavi YTD | 12.802,00 € | incluye 494,71 € de cancelaciones retenidas |
| Margen neto YTD | 2.744,53 € | **2.º del portfolio**, detrás de Nicasio |

**Cómo se calcula el ADR de equilibrio acá** (distinto a los otros tres, por el modelo):
`costes_fijos ÷ (noches vendidas × 0,25)` = `10.057,47 ÷ (198 × 0,25)` = **203,18 €**.
Se usa 0,25, **no** 0,3025: el IVA no es ingreso.

⚠️ **Contradicción abierta**: `docs/pricing/PLAYBOOK.md` §4.5 anota el equilibrio de Jacobine en
**189 €**. Recalculado hoy con la fórmula de arriba da **203 €**, y con el rango ene–jun da 200,70 €.
No pude reproducir 189 con ninguna combinación de rango. Fiarse del número recalculado en sesión
(la doctrina del proyecto es leer, no recordar) y corregir el playbook cuando alguien confirme de
dónde salía el 189.

**El segundo puesto del ranking engaña un poco.** Jacobine deja 2.744,53 € de margen con
**cero riesgo de renta** — no tiene un contrato que pagar si el piso se vacía. Alexander deja
1.927,35 € y Marechal 1.393,06 €, pero ambos con renta comprometida. En riesgo/retorno Jacobine es
mejor negocio de lo que su margen absoluto sugiere; en euros por noche (13,86 €) es floja.

**Mes a mes 2026** (ingreso Samavi · ADR · ocupación):

| Mes | Noches | ADR | Ocup. | Ingreso Samavi |
|---|---|---|---|---|
| Ene | 19 | 225,22 | 61 % | 1.173,05 |
| Feb | 24 | 214,86 | 86 % | 1.234,31 |
| Mar | 27 | 237,40 | 87 % | 1.602,47 |
| **Abr** | 27 | **398,44** | 90 % | **3.080,92** |
| May | 26 | 296,55 | 84 % | 1.927,55 |
| Jun | 27 | 226,56 | 90 % | 1.553,78 |
| Jul | 24 | 187,93 | 77 % | 1.127,60 |
| Ago (ya reservado) | 24 | 183,72 | 77 % | 1.102,32 |
| Sep (ya reservado) | 25 | 254,58 | 83 % | 1.591,15 |
| Oct (ya reservado) | 24 | 289,50 | 77 % | 1.737,03 |
| Nov (ya reservado) | 10 | 239,17 | 33 % | 606,68 |
| Dic (ya reservado) | 2 | 407,50 | 6 % | 203,75 |

---

## Cómo se vende de verdad

*Medido en `reservations` (status confirmed), check-ins entre el 01/01/2026 y el 14/08/2026 — solo
fechas ya pasadas, para no sesgar el lead time con el futuro a medio llenar. 54 reservas.*

**Lead time: es el piso que se reserva con más anticipación después de Alexander.**

| | Jacobine | Nicasio | Marechal | Alexander |
|---|---|---|---|---|
| Mediana | **81 días** | 87,5 | 69 | 101 |
| ≤7 días | **16,7 %** | 10,3 % | 8,2 % | 1,6 % |
| ≤14 días | **16,7 %** | 12,1 % | 9,8 % | 4,9 % |
| ≥90 días | **50,0 %** | 46,6 % | 37,7 % | 60,7 % |

Dos lecturas operativas:

1. **La mitad de las reservas entra a 90 días o más.** El descuento nativo de **reserva anticipada
   (−10 %, ≥3 meses)** se está aplicando sobre la mitad del inventario. No es gratis.
2. **Un 16,7 % entra a ≤7 días y nada entre 8 y 14 días.** Su última hora es *muy* última: las
   bajadas tácticas acá tienen sentido dentro de la semana, no a 10 días.

**Duración**: media **3,35 noches**, mediana 3. Solo el **1,4 %** de las reservas es de 1 noche y
el **2,7 %** llega a 7+. Es un piso de estancia corta de fin de semana largo.

**Días fuertes y flojos** (ocupación real 01/01–13/08/2026):

| Día | Ocupación | Check-ins |
|---|---|---|
| Lunes | 78,1 % | 7 |
| Martes | **71,9 %** | 5 |
| Miércoles | 84,4 % | 8 |
| Jueves | **72,7 %** | 7 |
| Viernes | 87,5 % | **11** |
| **Sábado** | **90,6 %** | 7 |
| Domingo | 87,5 % | 8 |

El hueco está en **martes y jueves**. El check-in se concentra el **viernes**.

**Canal: monocultivo de Airbnb.**

| Canal | Ingreso Samavi ene–ago | % |
|---|---|---|
| Airbnb | 12.177,30 € | **98,9 %** |
| Directa (`manual`) | 130,00 € | 1,1 % |
| Booking.com | 0,00 € | 0 % |

Booking está conectado (`16710783`) y en todo el año solo produjo **una reserva, cancelada**.

**Estacionalidad — y acá está lo que hace distinto a este piso.** Sevilla tiene la curva invertida
respecto de Madrid: **abril manda y el verano es temporada baja** (el calor vacía la ciudad).

- **Abril 2026: ADR 398,44 €** — Semana Santa + Feria. Dentro de ese mes, la Feria se vendió a
  **624,20 €/noche** (17–20/04) y **664,95 €/noche** (21–23/04). Semana Santa, a 263,77–482,60 €.
- **Julio y agosto son el piso de la curva**: ADR 187,93 y 183,72 €.
- Contra 2025 mejoró fuerte igual: julio 143,14 → 187,93 (**+31 %**) y agosto 132,76 → 183,72
  (**+38 %**).
- **Septiembre y octubre 2026 ya están vendidos por encima del año pasado**: sep 254,58 € vs
  201,62 € (+26 %) y oct 289,50 € vs 236,94 € (+22 %).

**Regla que se cae de acá: en Jacobine no se trabaja el verano, se trabaja marzo–mayo y
septiembre–octubre.** Y las dos semanas que valen el año (Semana Santa y Feria) están hoy
inaccesibles — ver la sección siguiente.

---

## Configuración de precios hoy

> ⚠️ **Estos valores caducan.** No los cites mañana sin releerlos. La verdad se lee con las
> consultas de `docs/pricing/ESTADO.md` §1. Leído el **14/08/2026**.

**PriceLabs (`get_listing_data`, 14/08/2026 08:56 UTC):**

| Campo | Valor |
|---|---|
| Mínimo (`min`) | **155 €** |
| Base (`base`) | **210 €** |
| Máximo (`max`) | **sin fijar** — Stag rechazó el techo el 14/08/2026 (PLAYBOOK §5.7: la vigilancia es de Claude, no de un tope) |
| Base recomendada por PriceLabs | 210 € (coincide con la base puesta; `bp_ratio` = 1) |
| Push al canal | activo · último push **14/08/2026 08:56 UTC** |
| Última reserva entrada | 11/08/2026 · pickup 15 días: 8 reservas |

**Min-stay observado en el calendario** (no pude leer el mínimo a nivel anuncio, ver dudas):

| Min-stay | Noches | Rango |
|---|---|---|
| 1 | 4 | solo las 4 con override |
| 2 | 53 | ago 2026 – jun 2027 |
| **3** | **265** | dominante desde sep 2026 |
| 4 | 29 | dic 2026 – mar 2027 |
| 5 | 15 | dic 2026 – abr 2027 |

**Overrides vivos** (`get_listing_date_overrides`, 14/08/2026):

| Fecha | Override | Motivo registrado |
|---|---|---|
| 28/08/2026 | min-stay 1 | hueco huérfano de 1 noche, autorizado por Stag 05/08 |
| 01/09/2026 | min-stay 1 | ídem |
| 06/09/2026 | min-stay 1 | ídem |
| 13/09/2026 | min-stay 1 | ídem |
| 14/08/2026 | `min_price` 120 € fijo | plan del 09/08 aprobado por Stag (suelo 155→135, borrando un −20 % heredado). **Esa noche ya se vendió** — el override quedó consumido |

**Dónde queda frente al comp set.** PriceLabs lo compara contra la categoría **1 dormitorio** del
barrio: 62 anuncios, p25 108 € · p50 129 € · p75 154 € · p90 209 €. Con las noches libres de agosto
publicadas a 155–170 €, el piso aparece **entre el p75 y el p90**. Pero el anuncio tiene **2
dormitorios**: la comparación está sesgada y hace parecer caro lo que no lo es. **No usar ese
percentil para justificar una bajada** sin cambiar antes la categoría del comp set.

**Contra el mercado, la ocupación es aplastante:**

| Horizonte | Jacobine | Mercado |
|---|---|---|
| 30 días | **90 %** | 43 % |
| 45 días | 87 % | 45 % |
| 60 días | 82 % | 44 % |

MPI a 60 días = **1,8** (vende 80 % más que su mercado).

**Contra sí mismo el año pasado** (`v_pricelabs_resumen`, próximos 30 días): ocupación **80 %** vs
93,3 % en 2025, pero ADR **192,06 €** vs 130,00 €. RevPAR 153,6 vs 121,3: **+27 %**. Menos noches,
bastante más plata. El cambio es deliberado y está funcionando.

**Dinero identificado sobre la mesa:** 7 noches publicadas por debajo del recomendado, **219 €** en
total; la primera es el **28/08** (a 14 días), publicada a 155 € contra 187 € recomendados. Las
otras: 01/09 (155 vs 161), 06/09 (155 vs 176), 13/09 (163 vs 198), 24/09 (225 vs 274), 25/09
(311 vs 384) y 12/10 (217 vs 220).

---

## Casuísticas propias

### 1. El calendario está cerrado desde el 09/02/2027 — ventana de reserva de ~6 meses · CONFIRMADO 14/08/2026

La sospecha del 13/08 era correcta. **Desde el 09/02/2027 hasta el final del horizonte
sincronizado (14/08/2027), las 187 noches están en `booking_status = 'Blocked'`.** Sin excepción,
sin huecos.

**No es un bloqueo manual: es una ventana móvil.** La frontera avanza un día por día, medido en
`pricelabs_fotos` (insert-only, no se puede reconstruir hacia atrás):

| Foto | Primera noche bloqueada de 2027 |
|---|---|
| 04/08/2026 | 31/01/2027 |
| 06/08/2026 | 02/02/2027 |
| 09/08/2026 | 05/02/2027 |
| 12/08/2026 | 07/02/2027 |
| **14/08/2026** | **09/02/2027** |

Eso es una **ventana de reserva de ~179 días (≈6 meses)** configurada en Guesty o en Airbnb.
**Es el único piso que la tiene**: en 2027, Nicasio, Alexander y Marechal tienen **una sola**
noche marcada `Blocked` cada uno, y es la última del horizonte — el artefacto de borde conocido de
la migración 064, no un bloqueo real. Jacobine tiene **187**.

**La prueba de que corta demanda real, no teórica** (`reservations`, histórico completo):

| Piso | Reservas confirmadas | Lead máximo observado | Reservas a >179 días |
|---|---|---|---|
| **Jacobine** | 121 | **176 días** | **0** |
| Nicasio | 237 | 339 días | 7 |
| Alexander | 110 | 338 días | 8 |
| Marechal | 89 | 295 días | 3 |

Jacobine nunca recibió una reserva a más de 176 días **porque no puede**. Los otros tres reciben
entre el 3 % y el 7 % de sus reservas en esa franja. La distribución está censurada por la
configuración, no por el mercado.

**Qué hay del otro lado de la puerta cerrada** (precio recomendado por PriceLabs hoy, marcado como
**simulado** — nadie reservó todavía):

| Ventana | Noches | € /noche | Bruto | Comisión Samavi (25 %) |
|---|---|---|---|---|
| Semana Santa 2027 (20–28/03) | 9 | 509–633 | 5.185 € | 1.296 € |
| Feria de Abril 2027 (11–17/04) | 7 | 624–684 | 4.623 € | 1.156 € |
| **Total** | **16** | | **9.808 €** | **2.452 €** |

Esos 2.452 € simulados son el **89 % del margen neto real que Jacobine lleva en todo 2026**.
PriceLabs confirma que la demanda de mercado existe: los precios del barrio suben **+102,3 %** del
21 al 25/03/2027 y **+85,0 %** del 11 al 15/04/2027. Hay además un pico de **+318,5 %** el
11/06/2027 (recomendado 888 €/noche), también dentro de la zona cerrada.

**Matiz honesto**: la Feria y la Semana Santa de 2027 se van a poder reservar cuando la ventana
llegue (≈22/09/2026 para Semana Santa, ≈13/10/2026 para la Feria), y en 2026 las reservas de esas
semanas entraron con 42–127 días de antelación — dentro de la ventana. O sea: **la ventana
probablemente no borra esas semanas, las retrasa**. El coste medible seguro es el otro: el 3–7 %
de reservas de larga antelación que los demás pisos sí capturan, y la ausencia del anuncio en las
búsquedas de quien planifica con un año.

**Decisión de Stag pendiente**: abrir la ventana a 12 meses o dejarla. No la toqué (solo lectura).

### 2. Bloqueo deliberado 18–20/08/2026 — y la trampa de leerlo mal

Tres noches bloqueadas por el **viaje de control de Stag a Sevilla**. Son deliberadas, no se
desbloquean, no se les pone precio y no cuentan como "euros sobre la mesa"
(regla del 14/08/2026, PLAYBOOK §2.8).

**La trampa**: en `pricelabs_prices` esas noches salen con `reservado = false` **y**
`no_vendible = false`. Solo `booking_status = 'Blocked'` las delata. Una consulta ingenua de
"noches libres" — incluida la del `ESTADO.md` §1a, que va contra `reservations` — las cuenta como
vendibles. `f_pricelabs_forward` sí las separa bien (`bloqueadas`). Verificado hoy: agosto de
Jacobine tiene **3 bloqueadas + 3 libres reales**, no 6 libres.

Las noches 02 y 03/08/2026 también figuran `Blocked` en el histórico (ya pasadas).

### 3. La comisión de canal la paga la dueña

Airbnb cobra 18,5 % del bruto (**9.112,36 €** ene–ago 2026) y sale de la liquidación de ella, no de
Samavi (`comision_canal_samavi = 0,00`). Es la diferencia estructural con Madrid y hay que tenerla
presente al comparar márgenes entre pisos.

### 4. Las reservas directas no cobran tarifa de limpieza — regla sin fijar (abierto desde 26/07/2026)

La única directa del año (24–27/07, 3 noches, 520 €) se cerró **sin los 60 € de limpieza** que sí
cobran las de Airbnb, y el empleado limpió igual. Antes de empujar canal directo (que es la palanca del
simulador) hay que decidir la regla.

### 5. La limpieza es el empleado de Sevilla, no Ecocleans

Ecocleans limpia solo los tres de Madrid. Acá el motor **siempre** cae al estimado
(`limpieza_fuente = 'estimado'`, verificado en los 8 meses). Los amenities los compra el empleado con
su tarjeta de la sociedad en DIA / Natura Sevilla y entran como `event` mensual real, no como provisión
(`listings.amenities = 0` desde la migración 048).

### 6. El termo Ariston de abril lo comió Samavi

258,94 € (mantenimiento, abril 2026) cargados a Samavi **sin refacturar a la dueña**: excepción
consciente al modelo comisión, confirmada por Stag (26/07/2026). Junto con las toallas de julio
(140 €, partida completa 2025 + julio) es el patrón: **el CAPEX y el textil los absorbe Samavi
aunque el modelo diga otra cosa.**

### 7. El ADR de febrero está inflado 219,43 €

Un reembolso del Resolution Center al huésped que `bruto` no ve. El ADR real de febrero fue
**205,72 €**, no los 214,86 que muestra el motor. El **ingreso está bien**; miente solo el precio
de referencia. La migración 032 dejó fuera a propósito reembolsos y ajustes manuales.

### 8. Cuenta corriente de la dueña — 27.583,57 € devengados a su favor

`v_cuenta_duena` (leída hoy): **8.394,68 €** de 2025 + **19.188,89 €** de ene–ago 2026.
Es pasivo por noche menos los 700 €/mes de limpieza menos los descuentos por recobros.
A 05/08/2026 **no se le había pagado nada** (memoria del proyecto): la plata está en el banco
esperando decisión, así que esa cuenta devengada **es deuda real**, no una referencia.
La liquidación de 2.000 € de mayo salió del Revolut como *"Retiro de socio"*, no como pago del
pasivo — caja y `pasivo_madre` corren por rieles distintos. **Eso vive en el proyecto Admin &
Fiscal, no acá.**

### 9. Recobros pendientes — 125,00 € en 3 pagos

`v_recobros_pendientes` (hoy): 3 pagos, **125,00 €**, el más viejo del **29/09/2025** (319 días).
Los tres salieron de la **cuenta personal de Stag**, no de Samavi. Son **neutros para Samavi**:
nunca entran a `events` ni al P&L. Trabajos: refuerzo de los muebles de los dos baños y repegado
de los rieles de las duchas.

### 10. Política de resoluciones de Airbnb — decidida hacia adelante, retroactividad abierta

Desde el 11/08/2026, **todas** las resoluciones (cobros y devoluciones) son de Samavi. La
mecánica: en cada cierre, si aparece una de JACO en `airbnb_tx` (tipo Resolución), se corrige a
mano — cobro → recobro a la dueña; devolución → crédito a ella. Madrid no necesita nada.

---

## Pendientes abiertos

1. **[14/08/2026] Ventana de reserva de ~6 meses.** Decidir con Stag si se abre a 12 meses.
   Hoy corta el 3–7 % de reservas de larga antelación y deja Semana Santa y Feria 2027 fuera de
   venta hasta finales de septiembre / mediados de octubre de 2026. **Es el pendiente más caro de
   esta ficha.**
2. **[11/08/2026] Retroactividad de la política de resoluciones en JACO.** En 2026 la dueña cobró
   +68,36 € (los 98 € de junio) y absorbió −153,05 € (su 69,75 % del reembolso de febrero) → neto
   **+84,69 € a favor de ella**. Lo recomendado el 11/08 fue aplicar solo hacia adelante y dejar
   febrero y junio como están. **Esperando el OK de Stag.**
3. **[05/08/2026] Patas de los muebles de baño**: compra pendiente, generará otro recobro.
4. **[11/08/2026] Liquidar los 3 recobros (125,00 €)** cuando se le liquide el mes a la dueña.
5. **[26/07/2026] Fijar la regla de tarifa de limpieza en las reservas directas** antes de empujar
   canal directo.
6. **[05/08/2026] Diferencia de 248,97 € de 2025** (200,00 en agosto + 48,97 en septiembre):
   ajustes de la planilla manual sin respaldo en Guesty. Stag quedó en revisarlos.
7. **[14/08/2026] Corregir el ADR de equilibrio del PLAYBOOK §4.5** (dice 189 €, hoy da 203 €), o
   documentar de dónde salía el 189.
8. **[14/08/2026] Booking.com sigue en cero.** Está conectado y en todo 2026 produjo una sola
   reserva, cancelada. Decidir si se trabaja o se asume el monocultivo de Airbnb (98,9 %).
9. **[14/08/2026] Comp set de PriceLabs mal categorizado**: compara contra 1 dormitorio teniendo 2.
   Revisar antes de usar percentiles en cualquier decisión de precio.

---

## Enlaces

- **Reglas de pricing (leer antes de tocar un precio)**: [`../pricing/PLAYBOOK.md`](../pricing/PLAYBOOK.md)
- **Experimentos y resultados medidos**: [`../pricing/BITACORA.md`](../pricing/BITACORA.md)
- **Cómo leer la verdad hoy + identificadores**: [`../pricing/ESTADO.md`](../pricing/ESTADO.md)
- **Casuísticas transversales**: [`../operativa/CASUISTICAS.md`](../operativa/CASUISTICAS.md)
- Otras fichas: [`NICASIO.md`](NICASIO.md) · [`ALEXANDER.md`](ALEXANDER.md) · [`MARECHAL.md`](MARECHAL.md)

*Fuentes de esta ficha: motor SQL de Supabase (`f_breakeven`, `f_ranking`, `f_costes`, `f_canal`,
`f_pnl_mensual_propiedad`, `v_cuenta_duena`, `v_recobros_pendientes`, `v_pricelabs_resumen`,
`v_pricelabs_oportunidades`, `pricelabs_prices`, `pricelabs_fotos`, `reservations`, `listings`,
`events`), API de PriceLabs en modo lectura (`get_listings`, `get_listing_data`,
`get_listing_date_overrides`, `get_neighbourhood_data`) y la memoria del proyecto. Todo consultado
el 14/08/2026.*

---

*Última revisión: 14/08/2026 · Las cifras de esta ficha CADUCAN: se regeneran con las
consultas de [`../pricing/ESTADO.md`](../pricing/ESTADO.md). Ante cualquier duda entre lo escrito
acá y la base, manda la base.*
