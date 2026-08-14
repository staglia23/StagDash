# Nicasio (1A_NICA)

> El único piso en propiedad (modelo titular): no paga renta, y por eso aporta **71,8 % del
> margen neto de las cuatro** con un colchón de 41 puntos sobre su equilibrio. Es también el
> único que vende de verdad por Booking.com.

*Datos consultados el 14/08/2026. Los del motor son ventana ene–ago 2026 a mes completo
(el motor no corta a mitad de mes), así que agosto incluye noches ya reservadas hacia adelante.*

---

## Identidad

| | |
|---|---|
| Código | `1A_NICA` |
| PriceLabs / Guesty listing_id | `684f06ed66e5c60022ef8e05` (es el mismo en los dos) |
| Airbnb | `707824343240170720` |
| Booking.com | `15469439` |
| Nombre público | *MAD_NICASIO — Modern & Stylish Apt Plz Mayor/La Latina* |
| Modelo de negocio | **titular** (único de los cuatro) |
| Bajo gestión desde | **01/06/2024** — el más antiguo; los otros tres son de 2025 en adelante |
| Ciudad / edificio | Madrid — mismo edificio que Alexander y Marechal |
| Dormitorios | 1 |
| Limpieza que se **cobra** al huésped | **60,00 €** (PriceLabs `cleaning_fees`) |
| Limpieza que **cuesta** | **53,72 €** (`listings.limpieza_por_reserva`) — la más cara de los cuatro |

Ojo con la limpieza: los 60 € que se cobran **no entran netos**, porque la comisión de canal se
lleva su parte también sobre la limpieza. Para cubrir los 53,72 € habría que cobrar **~66,12 €**
(PLAYBOOK §3.3). Hoy cada reserva pierde unos pocos euros ahí, y es a propósito: subir la tarifa
de limpieza penaliza la conversión.

---

## Cómo gana dinero

**Modelo titular**: el piso es de la sociedad. `renta_base = 0,00` — no hay casero, no hay
contrato de alquiler que renovar ni renta que subir. **Todo el `host_payout` es de Samavi.**

Qué implica para el margen, comparado con los otros tres:

- En **subarriendo** (Alexander, Marechal) la renta ya está pagada, así que cada noche extra cae
  casi íntegra a contribución — pero el equilibrio arranca altísimo porque hay que cubrir la
  renta primero (Alexander necesita 84,1 % de ocupación, Marechal 83,1 %).
- En **comisión** (Jacobine) solo entra el 25 % + IVA del bruto.
- En **titular** no hay renta, y por eso Nicasio se equilibra al **48,8 % de ocupación**: la mitad
  que sus vecinos. Ese es todo el secreto de por qué gana lo que gana.

Sus costes fijos propios no son renta sino **comunidad + IBI (331,12 €/mes)** y **suministros
(150,00 €/mes)**, más la pila operativa que comparten los cuatro (Guesty 30,00 · PriceLabs 13,91 ·
Minut 7,81 · Akiles 6,05) y 30,00 € de extras (trastero Box2box).

---

## Los números que mandan

**Ventana ene–ago 2026 · `f_breakeven` y `f_ranking` consultados el 14/08/2026**

| | Valor |
|---|---|
| ADR de equilibrio (bruto) | **≈ 116 €** |
| Contribución por noche | **153,94 €** |
| Ocupación de equilibrio | **48,77 %** (119 noches de 243) |
| Ocupación actual | **90,12 %** (219 noches) |
| **Colchón** | **+41,35 pp** — el mayor de los cuatro, por lejos |
| Costes fijos del período | 18.243,84 € |

**YTD 2026 (real, devengado)**

| | Valor |
|---|---|
| Ingreso Samavi | **37.130,40 €** (incluye 1.000,95 € de cancelaciones retenidas) |
| Bruto facturado | 43.485,85 € |
| Noches vendidas | **219** de 243 disponibles |
| Reservas | 61 |
| ADR bruto | **198,57 €** · ADR neto 164,97 € |
| RevPAR | 178,95 € |
| Margen directo | 24.300,27 € |
| Cuota de overhead | −8.830,83 € (25 %, igual para los cuatro) |
| **Margen neto** | **15.469,44 € (41,66 %)** · 70,64 €/noche |

**El dato que ordena todo**: el margen neto del portfolio YTD es 21.534,38 € y Nicasio pone
15.469,44 → **71,8 %**. Alexander aporta 1.927,35, Marechal 1.393,06 y Jacobine 2.744,53. Si
Nicasio se cae, no hay negocio.

Colchón comparado: Nicasio +41,35 pp · Jacobine +17,47 · Alexander +6,39 · Marechal +5,37.

> **Sobre el ADR de equilibrio**: el PLAYBOOK §4.5 cita **124 €**. Recalculado hoy sobre esa misma
> ventana (ene–**jul**) da **122,00 €**; sobre ene–**ago** da **115,84 €**. No es un error de
> ninguno de los dos: el número se mueve con la ventana, y agosto entra con costes ya cargados y
> noches todavía llenándose. Usá siempre el de la ventana que estés mirando.

---

## Cómo se vende de verdad

Medido sobre las **61 reservas confirmadas con entrada entre el 01/01 y el 31/08/2026**
(`reservations`, `status = 'confirmed'`; verificado que ninguna cae en el bulk import de
Guesty de junio-2025, así que los lead times son limpios).

### Antelación — este piso se vende con MUCHO tiempo

| | |
|---|---|
| Lead time **mediana** | **89 días** |
| Lead time medio | 84,4 días |
| Reservas a ≤7 días | **9,8 %** |
| Reservas a ≤14 días | **11,5 %** |
| Reservas a ≥90 días | **49,2 %** |

Esto es lo más accionable de la ficha. **Casi la mitad de las reservas entran con 3 meses o más
de antelación**, o sea dentro de la ventana del descuento nativo de **reserva anticipada (−10 %)**:
ese descuento se está aplicando a la mitad del inventario. En cambio el de **última hora (−15 %)**
solo alcanza al 11,5 %. Bajar precios "para llenar" en ventana corta mueve muy poco acá; la
palanca real de Nicasio está 3 meses antes.

### Estancia y días de la semana

- **ALOS 3,61 noches** (mediana 3).
- Ocupación por día de la semana (ene–ago 2026), casi plana: **martes 97,1 %** · sábado 94,3 % ·
  viernes 91,4 % · miércoles 91,2 % · domingo 88,6 % · lunes 85,7 % · **jueves 82,9 %**.
  No hay un patrón de fin de semana marcado — se llena entre semana igual que el sábado.

### Mix de canal (noches, ene–ago 2026)

| Canal | Reservas | Noches | % noches | ALOS | Lead mediana | ADR bruto |
|---|---:|---:|---:|---:|---:|---:|
| Airbnb | 57 | 200 | 90,9 % | 3,51 | 87 d | 197,52 € |
| **Booking.com** | 3 | 15 | 6,8 % | **5,00** | **164 d** | **210,17 €** |
| Manual / directa | 1 | 5 | 2,3 % | 5,00 | 158 d | 202,00 € |

**Booking.com vende de verdad acá, y vende mejor**: pocas reservas pero con **estancias de 5
noches** (contra 3,5 de Airbnb), **lead de 164 días** y **ADR más alto (210,17 vs 197,52)**.
Es el único de los cuatro con Booking funcionando: Marechal ni lo tenía conectado hasta agosto y
Jacobine no cerró ninguna en el semestre. Booking históricamente son 3 reservas confirmadas
(junio-2026 y las dos de agosto-2026), 15 noches.

Cartera **hacia adelante** al 14/08: Airbnb 84 noches (lead medio 161 d) · Booking 12 noches ·
**una directa por web de 5 noches para enero-2027** (`source = 'website'`, en estado `reserved`).

Contexto de riesgo: a nivel portfolio, el 98 % del bruto entra por **una sola cuenta de Airbnb**
(ver [canal-concentracion-comision] en la memoria). Nicasio es el que menos depende de ella y el
único con dos canales vivos — es el laboratorio natural para diversificar.

### En qué meses rinde mejor

RevPAR bruto por mes, sobre todo el histórico bajo gestión (jun-2024 → 13/08/2026):

| Mes | RevPAR | Ocup. | | Mes | RevPAR | Ocup. |
|---|---:|---:|---|---|---:|---:|
| **Abril** | **225,55 €** | 91,7 % | | Junio | 166,14 € | 75,6 % |
| **Mayo** | **212,40 €** | 95,2 % | | Enero | 163,76 € | 95,2 % |
| Diciembre | 175,95 € | 91,9 % | | Julio | 156,89 € | 91,4 % |
| Octubre | 175,01 € | 93,5 % | | Marzo | 156,36 € | 88,7 % |
| Septiembre | 172,90 € | 91,7 % | | Noviembre | 152,61 € | 81,7 % |
| | | | | Febrero | 147,23 € | 92,9 % |
| | | | | **Agosto** | **112,61 €** | 81,3 % |

**Abril y mayo son el negocio**; **agosto es el peor mes del año** (RevPAR la mitad que abril:
Madrid se vacía y el ADR cae a 138 €). Septiembre y octubre recuperan fuerte. La ventana de
decisión que importa es **principios de septiembre para octubre**, no agosto.

*(Los meses tienen distinto número de ciclos: junio y julio llevan 3, agosto 2 más los 13 días
de este año, el resto 2. Sirve como señal estacional, no como promedio exacto.)*

---

## Configuración de precios hoy

> ⚠️ **Estos valores caducan.** Están leídos el **14/08/2026** (PriceLabs refrescó a las 06:57 UTC;
> el sync diario corrió 07:10 UTC). Antes de opinar sobre cualquier precio, releelos con las
> consultas de [ESTADO.md](../pricing/ESTADO.md) §1 — nunca de memoria ni de esta ficha.

| | |
|---|---|
| Mínimo | **150 €** |
| Base | **214 €** |
| Recomendado por PriceLabs | **214 €** (`bp_ratio` 1 → base y recomendado alineados) |
| Máximo | **sin techo** — Stag rechazó el `max_price` el 14/08/2026 |
| Último push al canal | 14/08/2026 06:57 UTC |
| % de los próximos 30 días al mínimo | **33 %** |

**Min-stay**: no hay un valor de anuncio legible por API. Observado noche a noche en
`pricelabs_prices`: **2 noches en agosto, 3 en septiembre**.

**Overrides vivos** (`get_listing_date_overrides`, 14/08):

| Fecha | Qué | Estado |
|---|---|---|
| 28/08/2026 | `min_stay = 1` — noche huérfana, plan del 09/08 | **Vive. La noche sigue sin vender** (181 € publicados, *Good Demand*, STLY 168,15 €) |
| 14 y 15/08/2026 | 99 € fijo + `min_price` 99 + min-stay 2 | **Las dos se vendieron** (Airbnb). Son hoy y mañana: ya no hay nada que revertir |

Ojo con esos dos: el `reason` dice *"Test 48h 07/08… huésped ve 119 (140 × 0,85). Revisar 09/08"*,
pero el precio quedó en **99 €** (editado el 12/08) y la revisión del 09/08 nunca se anotó. El
huésped terminó viendo ~84 € con el −15 % nativo, **contra un STLY de 140,60 €**. Se vendieron,
pero muy por debajo del año pasado. Es un caso de libro de la regla "el `reason` desactualizado
miente" (PLAYBOOK §2).

**Frente al comp set** (`get_neighbourhood_data`, 258 pisos de 1 dormitorio en La Latina /
Plaza Mayor — el mismo comp set que Alexander y Marechal, mismo edificio):

| Percentil del barrio | Precio |
|---|---:|
| p25 | 122 € |
| **mediana** | **161 €** |
| p75 | 199 € |
| p90 | 241 € |

Con base 214 €, Nicasio se posiciona **entre el p75 y el p90**: es el caro del edificio, y le
funciona. Lo confirma el rendimiento contra mercado:

- Ocupación próximos 30 días **93 % vs 55 % del mercado**; a 60 días **83 % vs 57 %**.
- **MPI a 60 días = 1,5** (índice de penetración: vende un 50 % por encima de su mercado).
- RevPAR próximos 30 días **175 € vs 136 € el año pasado (+29 %)**.
- YTD según PriceLabs: ingreso 37.406 € vs 37.039 € STLY; ADR 184 € vs 175 € STLY.

Es la evidencia directa de PLAYBOOK §4.3: Nicasio en p70–76 hace la misma ocupación que Marechal
en p22–30. **Bajarle el precio no compra ocupación, regala margen.**

Subida de mínimo ya planificada: **150 → 160 € el 01/10/2026** vía Custom Seasonal Profile,
no antes (PLAYBOOK §6).

---

## Casuísticas propias

Lo que aplica a este piso y no a los otros tres.

**1 · Es el único sin contrato de alquiler.** No hay renovación, ni aviso de vencimiento, ni renta
que suba. Lo que sí tiene son **cargas de propiedad** que los otros no: comunidad, IBI y derramas.

**2 · Derrama del forjado de C.P. Segovia 8 — 1.530,00 € en 2026, ya pagada.**
Febrero −765,00 (50 %), junio −382,50 (1/2) y julio −382,50 (2/2). *Fuente: `events`, recibos del
25/02 y 24/06; el de julio confirmado por Stag.*

**3 · La derrama IEE está escondida dentro de la comunidad y **infla el equilibrio**.**
De los **331,12 €/mes** de `comunidad_ibi_mes`, **149,83 € son derrama** y solo **181,29 € es la
cuota real** (181,29 + 149,83 = 331,12 ✓). Está modelada como perpetua, o sea que **le suma
~1.798 €/año de costes fijos que en algún momento se terminan**. Falta la fecha de la última
cuota; cuando llegue, `comunidad_ibi_mes` baja a 181,29 y la derrama sale a una línea con fecha de
fin. *Auditoría del 26/07/2026 — hay que pedírsela a la administración de la comunidad.*

**4 · IBI propio** (ningún otro piso lo tiene): enero −385,09 · abril −109,93 · julio −354,96
(PAC 2026 243,93 + fraccionamiento 2025 111,03). **Próximas cuotas: octubre 112,13 € y la final
del PAC el 15/12.** *Fuente: `events`, verificado contra la Carpeta Tributaria.*

**5 · Booking.com: el motor NO ve su comisión. Es la trampa más cara de este piso.**
Booking usa *payment by the property* — el huésped paga el bruto y Booking factura la comisión
aparte, así que `host_payout = bruto` y el motor cuenta el ingreso **sin restar nada**. Se parchea
a mano con un `event` cuando llega la factura. Junio ya está (−181,52 €). **Pendientes las dos de
agosto: 216,92 € + 250,03 € = 466,95 € con IVA.** Y hay un segundo filo: **Booking factura por
fecha de SALIDA**, así que una reserva a caballo de dos meses cae en el mes equivocado si no se
prorratea por noche. *Auditoría 26/07/2026, reconfirmado el 11/08 — no es un bug del motor.*
Esto escala con el canal: si Booking crece, hay que decidir si se netea del ingreso o se carga
como coste separado **antes** de crecer.

**6 · Suministros — el CUPS es lo único que identifica el piso.**
CUPS `ES0022000007651492DT1P`, TotalEnergies **dual luz + gas**, contrato a
nombre de la sociedad. Es el único de los tres de Madrid que nunca estuvo a nombre personal.
**Nicasio no lleva internet en sus costes directos**: su fibra es Orange y va al overhead
(Marechal y Alexander sí llevan Movistar). *Verificado 25–26/07/2026 contra facturas.*

**7 · La limpieza más cara de los cuatro** (53,72 € vs 43,80 € de Alexander y Marechal), cobrando
60 €. **No aplicar la recomendación de PriceLabs de bajarla a 41 €**: es una plantilla de mercado
que ignora nuestro coste y habría costado ~2.365 €/año en los tres pisos de Madrid.
*Descartada con número el 13/08/2026 (PLAYBOOK §3.3).*

**8 · Min-stay 1 está AUTORIZADO en Nicasio** (Stag, 09/08/2026), junto con Alexander; Marechal
conserva la restricción. ⚠️ Esto **supersede** la decisión del 06/08 que lo rechazaba y que sigue
escrita en la memoria `pricing-huecos-cortos-no-se-venden`. La autorización del 09/08 es posterior
y está corroborada por tres fuentes: PLAYBOOK §4.7, ESTADO.md §4 y un override real creado el
09/08 en PriceLabs. Aun así, los huecos de 1 noche se venden solo el **1,4 %** de las veces:
abrirlos es gratis, no es una palanca.

**9 · Sin bloqueos deliberados hoy.** Los viajes de control de Stag de agosto son de **Marechal
(22–25/08)** y **Jacobine (18–20/08)**, no de este piso. *Verificado 14/08/2026.*

**10 · Costes reimputados que se leen raro en `events`**: el **termo eléctrico de enero
(−450,00 €)** figura en Nicasio pero venía cargado en Alexander (migración 023, corregido tras
confirmación de Stag del 17/07). No confundirlo con el Ariston de abril, que sí es de Alexander.
Los **auriculares de oficina** (145,80 €/plazo) van al **overhead, no a compras de hogar de
Nicasio**.

**11 · DIA Madrid se reparte en tercios** entre los tres pisos de Madrid desde la migración 075
(regla de Stag del 10/08/2026), y **Nicasio absorbe el céntimo del redondeo**. Queda un fleco:
en junio los 39,71 € de DIA fueron **100 % a Nicasio** y está pendiente decidir si se corrige.

**12 · Trastero Box2box**: se provisionan 30,00 €/mes en `listings.extras` pero el real de julio
fue 88,80 €. El desvío va por `event` en cada cierre y **la provisión no se toca** (moverla
alteraría meses ya auditados). Aviso cargado para **diciembre-2026**: la cuota salta a ~71 €/mes
cuando se acaban las 5 primeras a −50 %.

**13 · Cicatriz del 13/08/2026**: la reserva de **11–14/08 a 144 €/noche** se presentó como prueba
del éxito del test de bajada, **se canceló cinco días después y se revendió a 93,50 €/noche**.
Una reserva no es dinero hasta que pasa su ventana de cancelación (PLAYBOOK §5.4).

---

## Pendientes abiertos

| Desde | Qué | Fecha límite |
|---|---|---|
| 26/07/2026 | **Comisiones de Booking de agosto sin cargar: 466,95 €** (dos reservas de Booking: 216,92 + 250,03). Prorratear por noche, no por fecha de salida | **cierre de agosto** |
| 26/07/2026 | **Fecha de la última cuota de la derrama IEE** (149,83 €/mes dentro de la comunidad). Sin ella el equilibrio queda inflado ~1.798 €/año | abierta |
| 07/2026 | **IBI**: cuota de octubre 112,13 € y cuota final del PAC | 15/12/2026 |
| 10/08/2026 | Decidir si se corrige el DIA de junio (39,71 € cargados 100 % a Nicasio en vez de en tercios) | abierta |
| 09/08/2026 | **28/08 sigue sin vender** a 181 € con min-stay 1 ya abierto (*Good Demand*, STLY 168,15 €) | perecedera |
| 14/08/2026 | **Tres noches huérfanas bloqueadas por min-stay 2** — 03/09 (153 €), 14/09 (188 €) y **25/09 (297 €, *High Demand*, STLY 235,17 €)** — en un piso donde el min-stay 1 **está autorizado**. Son ~638 € publicados detrás de una restricción que se puede levantar | antes de que caduquen |
| 13/08/2026 | Subida de mínimo **150 → 160 €** vía Custom Seasonal Profile | **01/10/2026**, no antes |
| — | Recalcular la foto forward y decidir promos de Airbnb vivas antes de octubre | 01/09/2026 |

---

## Enlaces

- [PLAYBOOK de pricing](../pricing/PLAYBOOK.md) — reglas permanentes con su cicatriz.
  **Leer antes de tocar cualquier precio.** Relevantes acá: §3.3 (limpieza), §4.3 (elasticidad
  ~0 en p22–p76), §4.5 (equilibrios), §4.7 (min-stay 1), §5.4 (cicatriz de la cancelación),
  §5.7 (guardia de precios sin techo), §6 (subida del 01/10).
- [BITÁCORA de pricing](../pricing/BITACORA.md) — qué se probó y qué pasó, experimento por
  experimento.
- [ESTADO.md](../pricing/ESTADO.md) — **cómo leer la verdad en 30 segundos**: las consultas que
  dan precios y noches libres, los identificadores, y los datos que no se pueden leer por API.
- Fichas hermanas: [Alexander](ALEXANDER.md) · [Marechal](MARECHAL.md) · [Jacobine](JACOBINE.md)
  *(los tres de Madrid comparten edificio y comp set; Alexander y Marechal son subarriendo y
  tienen el equilibrio arriba del 83 %).*

---

**Manual de operación** (cierre mensual, proveedores, bloqueos): [`../operativa/CASUISTICAS.md`](../operativa/CASUISTICAS.md)

*Última revisión: 14/08/2026 · Las cifras de esta ficha CADUCAN: se regeneran con las
consultas de [`../pricing/ESTADO.md`](../pricing/ESTADO.md). Ante cualquier duda entre lo escrito
acá y la base, manda la base.*
