# Marechal (3G_MARE)

> El piso más nuevo de la cartera (arrancó el 01/12/2025) y el que menos margen deja: llena
> como los mejores (88,5 % YTD) pero al ADR más bajo de los cuatro (144,28 €), así que el
> colchón sobre el equilibrio es de apenas 5,4 pp. Es también el único de Madrid con bloqueos
> de calendario y el que más problemas dio en agosto de 2026.

**Todos los números de esta ficha se consultaron el 14/08/2026** contra el motor SQL y
PriceLabs. Datos frescos ese día: `guesty-sync` 09:00 UTC, `pricelabs-sync` 07:10 UTC
(`v_freshness`). Cierre contable cerrado hasta julio; agosto en curso.

---

## Identidad

| Campo | Valor |
|---|---|
| Código | `3G_MARE` (3º G) |
| PriceLabs `listing_id` | `6932ff2750f82e0013dbe977` (`pms` = `guesty`) |
| Guesty `listing_id` | `6932ff2750f82e0013dbe977` |
| Nombre del anuncio | `MAD_MARECHAL — Cozy & Warm Boho Apt Plaza Mayor/La Latina` |
| Airbnb | `1561722374319789678` |
| Booking.com | `17046956` — **conectado entre el 09 y el 13/08/2026**, todavía sin ninguna reserva |
| Modelo de negocio | **subarriendo** |
| Bajo gestión desde | **01/12/2025** (`listings.fecha_inicio`) |
| Ciudad / edificio | Madrid — mismo edificio que Nicasio y Alexander |
| Dormitorios | **1** (PriceLabs, comp set "1 BR") |
| Limpieza que se **cobra** | **60 €** desde el 30/08/2026 (decisión de Stag: unificó los 4 pisos en 60 €). Histórico: 50 € en 73 de 89 reservas; 60 € en 15; 0 € en 1. Media 51,12 € |
| Limpieza que **cuesta** | **43,80 €** por reserva (`listings.limpieza_por_reserva`) |

Con 60 € la limpieza deja de ir en pérdida: la comisión de canal se cobra también sobre la
tarifa de limpieza (18,6 % medido acá), así que entran ~48,84 € contra 43,80 € de coste:
**+5,04 € por reserva** (con los 50 € históricos era −3,18 €; cubrir coste exigía ~53,91 €).
No es palanca de conversión — ver [PLAYBOOK §3.3](../pricing/PLAYBOOK.md). OJO 30/08/2026: al
verificar por API, PriceLabs aún mostraba `cleaning_fees` 50 € acá y en Alexander — pendiente
confirmar que el cambio quedó guardado en Guesty/Airbnb (protocolo §5.3).

---

## Cómo gana dinero

**Subarriendo**: Samavi le paga una renta fija al propietario y se queda con todo lo que el
piso produzca por encima de esa renta y de los costes directos. El canal cobra su comisión
sobre el bruto y el resto es de Samavi.

- **Renta**: `listings.renta_base` = **1.100,00 €/mes**, que son **euros transferidos**, no
  base imponible. El contrato dice "1.100 neto al propietario", así que la base se deriva:
  base 1.078,43 + IVA 21 % (226,47) − retención IRPF 19 % (204,90) = 1.100,00 transferidos.
  El motor carga el **peor caso** (IVA no deducible, decisión de Stag del 25/07/2026):
  coste modelado **1.304,90 €/mes**. Si Confisic confirma que el IVA es deducible, el coste
  baja a 1.078,43 y basta poner `listings.renta_iva_pct = 0`.
  Detalle en la memoria `rentas-iva-retencion-confisic`.
- **Factura desde**: `renta_factura_desde` = 01/06/2026. Antes de junio se pagaban los 1.100
  sin factura, o sea que ese alquiler no era deducible en condiciones.
- **Qué implica para el margen**: la renta ya está pagada el día 1. Cada noche extra que se
  vende cae casi entera a contribución — **106,83 € por noche** YTD, después de comisión de
  canal y de la limpieza. Al revés también: cada noche vacía cuesta esos 106,83 €, y con
  1.304,90 € de renta más ~57,77 €/mes de servicios recurrentes (Minut 7,81 + Akiles 6,05 +
  PriceLabs 13,91 + Guesty 30,00) más suministros (~125 €/mes), el piso arranca cada mes con
  ~2.572 € de agujero antes de vender la primera noche.

---

## Los números que mandan

**Consultado el 14/08/2026.** Período YTD = 01/01–31/08/2026 (agosto incluye lo ya reservado).

| Métrica | Valor | Lectura |
|---|---|---|
| **ADR de equilibrio** (ene–ago) | **138,92 €** | derivado: contribución necesaria + limpieza, engordado por la comisión efectiva 18,61 % |
| ADR de equilibrio (ene–jul cerrado) | 134,32 € | el corte "limpio", sin agosto a medio vender |
| **ADR real** | **144,28 €** | colchón de **+5,36 €/noche** sobre el equilibrio |
| **Contribución por noche** | **106,83 €** | `(ingreso_samavi + limpieza) / noches` |
| **Ocupación actual** | **88,48 %** (215 de 243 noches) | real + ya reservado |
| **Ocupación de equilibrio** | **83,11 %** (202 noches) | |
| **Colchón** | **+5,37 pp** = 13 noches de margen | el más fino de los tres de Madrid |
| Costes fijos del período | 21.575,39 € | renta + suministros + otros + cuota de overhead |
| **Ingresos YTD (bruto)** | **31.019,46 €** | fareAccommodation + fareCleaning |
| Ingreso Samavi (host_payout) | 25.702,49 € | de ahí, 455,83 € son cancelaciones retenidas |
| Comisión de canal YTD | 5.772,80 € (18,61 % efectivo) | |
| **Noches vendidas YTD** | **215** en 64 reservas | |
| RevPAR YTD | 127,65 € | |
| Margen directo YTD | 10.223,89 € | |
| **Margen neto tras overhead** | **1.393,06 €** (5,42 %) | **el último de los cuatro pisos** |
| Neto por noche | **6,48 €** | Nicasio 70,64 · Alexander 8,76 · Jacobine 13,86 |

*(fuente: `f_breakeven` y `f_ranking` con rango 2026-01-01 → 2026-08-31; el ADR de equilibrio
se calcula a partir de esos mismos números, no viene como columna. Ojo: el
[PLAYBOOK §4.5](../pricing/PLAYBOOK.md) cita 136 € para Marechal — es el mismo cálculo con otra
fecha de corte, no una contradicción.)*

### Mes a mes 2026 (ocupación contra su propio equilibrio)

| Mes | Noches | Ocup. | ADR | RevPAR | Ocup. equilibrio | Colchón |
|---|---|---|---|---|---|---|
| ene | 31/31 | 100,0 % | 109,81 € | 109,81 € | 121,0 % | −21,0 pp |
| feb | 22/28 | 78,6 % | 113,69 € | 89,33 € | 112,7 % | −34,1 pp |
| mar | 29/31 | 93,5 % | 129,02 € | 120,69 € | 114,3 % | −20,8 pp |
| abr | 28/30 | 93,3 % | 176,89 € | 165,09 € | 109,9 % | −16,6 pp |
| may | 29/31 | 93,5 % | 176,35 € | 164,97 € | 31,8 % | **+61,7 pp** |
| jun | 30/30 | 100,0 % | 170,85 € | 170,85 € | 51,7 % | **+48,3 pp** |
| jul | 27/31 | 87,1 % | 139,07 € | 121,13 € | 83,1 % | +4,0 pp |
| **ago** | 19/31 | 61,3 % | 127,66 € | 78,24 € | 79,8 % | **−18,5 pp** |
| sep | 28/30 | 93,3 % | 196,90 € | 183,77 € | 56,3 % | +37,1 pp |
| oct | 25/31 | 80,6 % | 219,17 € | 176,75 € | 49,5 % | +31,1 pp |
| **nov** | 6/30 | 20,0 % | 144,37 € | 28,87 € | 75,9 % | **−55,9 pp** |
| dic | 3/31 | 9,7 % | 126,47 € | 12,24 € | 94,1 % | −84,5 pp |

⚠️ **El mes a mes engaña y hay que leerlo con cuidado.** Enero–abril salen en rojo porque ahí
cayeron los gastos de montaje (mobiliario Sequra 304,34 × 3, TV Xiaomi 460,78, aire
acondicionado 1.834,50); mayo y junio salen verdes porque la renta se compensó contra ese
mismo aire acondicionado. **Los extraordinarios de 2026 suman 3.822,72 € de los 4.284,88 € de
"otros"** — el 89 %. La lectura honesta es la del YTD, no la del mes.

### Noviembre es la pendiente número uno

| Dato | Valor |
|---|---|
| Noches vendidas | **6 de 30** (2 reservas) |
| Noches libres | **24** (ninguna bloqueada) |
| Ocupación de equilibrio | 75,88 % → hacen falta **23 noches** |
| **Colchón** | **−55,88 pp** — 3× el agujero de agosto |
| Contribución por noche implícita | 112,99 € |
| Costes fijos del mes | 2.571,97 € |
| Precio medio publicado de las 24 libres | 169,92 € (rango 125–247 €) |
| Min-stay | **3 en las 30 noches** |
| STLY | **null** — no hay noviembre de 2025 con que comparar (el piso arrancó el 01/12/2025) |

**Por qué se decide hoy y no en octubre**: Marechal vende con una **mediana de 80 días de
antelación**. Del 14/08 al 01/11 hay 79 días. O sea que la reserva mediana de noviembre se
está tomando ahora mismo, en otro anuncio. Las dos reservas que ya tiene noviembre entraron
con 199,5 días de mediana — gente que reserva muy temprano.

---

## Cómo se vende de verdad

Medido sobre `reservations` el 14/08/2026: **89 reservas confirmadas/reservadas** desde el
06/12/2025, 307 noches. Los porcentajes de abajo excluyen diciembre de 2025 salvo donde se
diga, porque el mes de lanzamiento (mediana de lead 6 días) distorsiona todo.

### Lead time — vende MUY temprano

| Métrica (check-in en 2026+, 81 reservas) | Valor |
|---|---|
| **Mediana** | **80 días** |
| Media | 84,7 días |
| P25 / P75 | 43 / 119 días |
| Reservas a ≤7 días | **6,2 %** |
| Reservas a ≤14 días | **7,4 %** |
| Noches (no reservas) a ≤14 días | 10,1 % |
| Noches a ≥60 días | **62,5 %** |
| Noches a ≥90 días | 47,2 % |

**Consecuencia operativa directa**: dos de cada tres noches de Marechal se venden con más de
dos meses de antelación. La palanca de última hora casi no existe acá — es un piso que se
gestiona en la ventana larga. Y explica por qué el test de bajada agresiva del 07/08 no
movió ni una noche de agosto: a esa altura ya no quedaba demanda en su ventana natural.

Lead time por mes de check-in: dic-25 **6** · ene **32** · feb **52** · mar **75** · abr **46**
· may **119** · jun **103** · jul **112,5** · ago **122** · sep **96,5** · oct **74** · nov
**199,5** · dic **163**.

### Duración de estancia

- **ALOS 3,45 noches** de media (3,51 contando solo check-ins de 2026).
- Por mes: los meses fuertes alargan (sep 4,17 · oct 4,00 · jun 4,29) y los flojos acortan
  (ago 2,71 · dic-25 2,75).
- **Min-stay 1 está PROHIBIDO en Marechal** (decisión de Stag, 09/08/2026): es el único piso
  que conserva la restricción de huecos huérfanos. Nicasio y Alexander sí lo tienen
  autorizado. **No volver a proponerlo** — ver PLAYBOOK §4.7.

### Días de la semana (01/12/2025 → 13/08/2026, noches pasadas reales)

| Día | Ocupación |
|---|---|
| **sáb** | **97,2 %** |
| **vie** | **94,4 %** |
| mar | 89,2 % |
| dom | 88,9 % |
| mié | 86,5 % |
| jue | 83,8 % |
| **lun** | **81,1 %** — el más flojo |

Fin de semana casi lleno y **el déficit está entre semana**, concentrado en la ventana corta
(el diagnóstico del 13/08 midió MPI 0,78 a 7 días contra 1,41–1,50 a 15–30 días). Las noches
libres de agosto caían todas de domingo a jueves, ninguna en viernes/sábado — si el problema
fuera precio, los findes también estarían vacíos.

### Mix de canal

| Canal | Reservas | Noches | % noches | ADR | Comisión efectiva |
|---|---|---|---|---|---|
| **Airbnb** (`airbnb2`) | 85 | 294 | **95,8 %** | 153,79 € | 18,64 % |
| Manual (directa) | 3 | 8 | 2,6 % | 126,16 € | 0 % |
| Web | 1 | 5 | 1,6 % | 152,40 € | — (una sola reserva, ene-2027) |
| **Booking.com** | **0** | **0** | **0 %** | — | — |

Booking está conectado desde la semana del 09–13/08/2026 y **todavía no trajo ni una noche**.
Es el experimento estructural abierto: Nicasio, en el mismo edificio, vendió **10 noches de
agosto** por Booking, incluidas las 16–22/08, exactamente las que Marechal tenía vacías.

⚠️ **Trampa del motor con Booking**: Booking usa "payment by the property" — el huésped paga
el bruto y Booking factura la comisión aparte, así que `host_payout = bruto` y el motor la ve
con comisión 0 %. Cada euro que entre por ese canal **infla el margen un 15–18 %** hasta que
llegue la factura. No comparar ADR de Booking contra ADR de Airbnb sin corregir.

### Cancelaciones

15 reservas canceladas (52 noches) sobre 104 confirmadas+reservadas+canceladas = **14,4 %**.
Hay además 11 *inquiries* y 1 declinada. Regla: una reserva no es plata hasta pasar su
ventana de cancelación (PLAYBOOK §5.4).

### Meses en que rinde mejor

Por RevPAR ya devengado/reservado 2026: **sep 183,77 € · oct 176,75 € · jun 170,85 € · abr
165,09 € · may 164,97 €**. Los peores: **ago 78,24 € · feb 89,33 € · ene 109,81 €** (y dic-25
82,13 €). Septiembre y octubre entraron solos, a 196,90 y 219,17 € de ADR, sin ningún
descuento — **no se tocan** (PLAYBOOK §4.6).

---

## Configuración de precios hoy

> ⚠️ **Estos valores CADUCAN.** Un "precio actual" escrito a mano da falsa confianza: el
> 13/08/2026 se analizó este piso durante horas creyendo que estaba a 93 € cuando llevaba un
> día a 84 €. **Antes de opinar sobre un precio, leelo con las consultas de
> [ESTADO.md §1](../pricing/ESTADO.md).** Lo de abajo es la foto del 14/08/2026, nada más.

**Panel del anuncio en PriceLabs (14/08/2026, `get_listing_data`)**

| Campo | Valor |
|---|---|
| Mínimo (`min`) | **99 €** |
| Base (`base`) | **159 €** |
| Máximo (`max`) | **null — a propósito** (Stag rechazó el techo el 14/08/2026, ver §2.7 y §5.7) |
| Base recomendada por PriceLabs | 160 € (`bp_ratio` 1,01 — el base está bien calibrado) |
| Tarifa de limpieza configurada | 50 € (foto 14/08; Stag la subió a 60 € el 30/08/2026 — ver arriba) |
| `push_enabled` | true |
| `last_date_pushed` | 2026-08-14 05:38 UTC |
| Noches a precio mínimo en los próximos 30 días | **67 %** |
| MPI próximos 60 días | 1,60 |

ℹ️ **PriceLabs y el dashboard NO dicen lo mismo, y está bien.** PriceLabs reporta para este
piso `revenue_ytd` 26.639 € y `adr_ytd` 129 €; el motor dice 31.019,46 € de bruto y 144,28 €
de ADR. Son **diferencias definicionales, no errores**: PriceLabs mide alojamiento **sin**
limpieza, cuenta bloqueos como ocupados y corta en el día de hoy. La reconciliación formal
dio 0 €. Para el P&L manda el motor; PriceLabs es forward y operativo.

🚩 **Señal a vigilar: el 67 % de las noches de los próximos 30 días publican al mínimo**
mientras el piso le gana al mercado por 28–34 puntos de ocupación (83 % vs 55 % a 30 días;
87 % vs 57 % a 45; 90 % vs 56 % a 60). Según [PLAYBOOK §2.5](../pricing/PLAYBOOK.md) eso es síntoma de
**suelo mal calibrado hacia abajo**, no de precio alto. Está previsto revisarlo el 01/10 vía
Custom Seasonal Profile.

**Min-stay (leído en `pricelabs_prices` el 14/08)**: 2 noches en agosto, **3 noches desde el
01/09 y en todo el horizonte hasta agosto de 2027**. No hay min-stay 1 en ninguna noche.

**Overrides vivos (`get_listing_date_overrides`, 14/08/2026)**

| Fechas | Qué tienen | `reason` | Estado |
|---|---|---|---|
| 16, 17, 18/08 | `price` 84 € fijo + `min_price` 84 | "Test 48h: huesped ve 79 (93 x 0,85). Revisar 09/08." | ⚠️ **texto obsoleto**: dice 93 € pero el valor real es 84 €. Lo editó alguien a mano el 12/08 08:15 UTC sin actualizar el motivo |
| 22, 23, 24, 25/08 | `min_price` 119 + `min_stay` 2 | **vacío** | ⚠️ edición manual desde la UI (12/08 08:15 UTC). **Da igual: esas noches están bloqueadas** por el viaje de control de Stag |

Un `reason` vacío es la firma de una edición manual desde la UI (PLAYBOOK §2.6). Los dos
bloques de arriba están fuera del plan del 09/08 y nadie los reconcilió.

**Frente al comp set** (`get_neighbourhood_data`, 14/08/2026 — 261 anuncios de 1 dormitorio
en el barrio):

| Percentil del barrio | Precio |
|---|---|
| p25 | 122 € |
| **mediana** | **161 €** |
| p75 | 199 € |
| p90 | 243 € |

- El **base de 159 € está prácticamente en la mediana del barrio** (161 €). Bien puesto.
- El **mínimo de 99 € está por debajo del p25**, y con el −15 % nativo de Airbnb el huésped
  ve 84,15 € → percentil ~10. Ahí ya no hay palanca de precio: la elasticidad medida en el
  rango p22–p76 es ~0 (PLAYBOOK §4.3).
- Las noches 16–18/08 a 84 € publicados → el huésped ve **71,40 €**, percentil 16–19, muy por
  debajo de la mediana *reservada* del barrio (94,6–104,1) y sin una sola *inquiry*.
- PriceLabs lee el anuncio como *"a la par del mercado"* en temporada alta (sep–oct) y en
  temporada baja (dic, ene, jul), y marca subidas de mercado el 05/12/2026 (+54,8 %),
  27/12–01/01 (+50,9 %) y 01–05/06/2027 (+34,6 %).

---

## Casuísticas propias

**1. Bloqueos deliberados — es el único piso de Madrid que los tiene** *(14/08/2026, memoria
`bloqueos-calendario-deliberados` + `pricelabs_prices.booking_status`)*
Las noches **22–25/08/2026 están bloqueadas** por un viaje de control de Stag. Rotuladas
"Control" en Guesty. **No son huecos por vender, no se desbloquean, no entran en ningún
cálculo de euros sobre la mesa.** El 13/08 se gastó un diagnóstico completo (7 agentes) en
averiguar por qué no se vendían y se estimaron 369 € recuperables que no existían.
Nicasio y Alexander tienen cero bloqueos.

**2. El motor es CIEGO a los bloqueos** *(13/08/2026, PLAYBOOK §2.9)*
`guesty-sync` no ingesta bloqueos: `reservations` solo guarda `canceled`, `closed`,
`confirmed`, `declined`, `inquiry` y `reserved`. Una noche bloqueada aparece como **libre**.
La única señal es `pricelabs_prices.booking_status = 'Blocked'`. **Al listar noches libres de
Marechal, excluir siempre las bloqueadas.**

**3. Contradicción sin resolver en el bloqueo de agosto** *(13/08/2026, BITACORA)*
El calendario de PriceLabs marca 4 noches bloqueadas (22–25) y la salud del anuncio reporta
"5 blocked dates", pero el feed del PMS declara **una sola** entidad de bloqueo (22→23/08,
creada el 12/08). Hay una segunda entidad (22→24, creada el 29/07) que llega como
`available` **y con huésped asociado**. Nadie abrió Guesty con los ojos todavía.

**4. El aire acondicionado de abril y el plan de compensación** *(events, verificado hoy)*
1.754,50 € de factura del instalador + 80,00 € en efectivo al un tercero del edificio =
**1.834,50 €**, compensados exactamente contra la renta: **mayo renta efectiva 0 €** (event
+1.100,00) y **junio 365,50 € transferidos** (event +734,50). Por eso mayo y junio salen con
colchón de +61,7 y +48,3 pp en la tabla mensual: es un artefacto contable, no un mes bueno.

**5. Gastos de montaje que ya terminaron** *(events)*
Mobiliario Sequra 304,34 €/mes × 3 (**última cuota mar-2026**) y payoff anticipado de la TV
Xiaomi vía Orange 460,78 € (mar-2026). Estos ya no se repiten: desde abril el "otros"
recurrente de Marechal es de **57,77 €/mes**.

**6. Suministros: el CUPS manda, no el nombre de la factura** *(25/07/2026, memoria
`suministros-cups-mapeo`)*
CUPS **`ES0022000007651514DE1P`**. Hubo facturas de este piso a nombre
personal de Stag (papernest) hasta el 04/02/2026, cuando pasó a
TotalEnergies. **El cambio valió ~40 % del recibo** (papernest cobraba
0,1679–0,1731 €/kWh, TotalEnergies 0,1099). Nunca clasificar una factura de luz por el
titular ni por la carpeta: leer el CUPS.

**7. Dos meses de luz siguen abiertos** *(memoria `auditoria-pisos-pendientes`)*
- **Febrero**: 96,43 € cargados contra 95,42–103,15 reconstruidos. Es el único mes con cambio
  de comercializadora a mitad de mes (el 4 de febrero aparece en dos facturas). Desvío 1–7 €.
- **Abril**: TotalEnergies no facturó del 4 al 11 (79 kWh, ~15,60 €). Marcado `real_revisar`
  por si lo regularizan en un ciclo posterior.

**8. El internet sube el 27/10/2026** *(tabla `avisos`, id 1, verificado hoy)*
Vence la promoción de Movistar (línea de fibra 600 Mb): **de 30,00 a 40,00 €/mes**, impacto
−10,00 €/mes. Es una de dos fibras que vienen en una única factura de 55 €/mes — la cara
(30,00) es de Marechal, la barata (25,00) de Alexander.

**9. Refacturación pendiente a nombre de la sociedad** *(memoria `auditoria-pisos-pendientes`)*
El contrato de luz de Marechal está a nombre personal de Stag (nº de contrato en la memoria del proyecto, no acá). Vive fuera del repo,
en el carril de Confisic.

**10. Dos apuntes en efectivo sin respaldo documental** *(migración 049, marcados ⚑ en
`events.notas`)*
Cristales 60,00 € (02/01/2026) y arreglo de bañera 150,00 € (03/03/2026), pagados en efectivo
al un tercero del edificio. Salen solo de la planilla manual de Stag, sin cargo bancario ni
factura. **Cargados por criterio de peor caso, no conciliados.**

**11. El anti-patrón del `price_type: "percent"` se cebó con este piso** *(10–11/08/2026,
PLAYBOOK §2.7)*
Tres overrides cargados como **porcentaje** desde el móvil (99, 149 y 129) publicaron las
noches 22–25 a **190–281 €**, entre 1,6 y 1,8 veces el p90 del barrio, justo en los únicos
días en que ese bloque estuvo abierto a la venta. Tercera aparición del mismo error.
**El `max` sigue en null a propósito**: Stag rechazó el techo el 14/08/2026 y a cambio la
vigilancia diaria es de Claude (PLAYBOOK §5.7).

**12. Refacturación al dueño** *(junio 2026, events)*
50 % de la inscripción registral: −218,22 €, refacturado al propietario el 19/06.

---

## Pendientes abiertos

1. **Noviembre 2026 — 55,88 pp bajo el equilibrio, 24 noches libres, ninguna bloqueada**
   *(14/08/2026)*. Es 3× el agujero de agosto y la ventana de decisión **está abierta hoy**:
   con mediana de lead de 80 días, la reserva típica del 1 de noviembre se toma esta semana.
   Hay que decidir precio y min-stay (hoy 3 en las 30 noches) **antes de fin de agosto**.
   Nada aplicado todavía; requiere OK explícito de Stag.

2. **Overrides huérfanos del 12/08 sin reconciliar** *(14/08/2026)*: 16–18/08 a 84 € con
   `reason` que dice 93 €, y 22–25/08 con `min_price` 119 + `min_stay` 2 y `reason` vacío
   sobre noches bloqueadas. Decidir si se borran o se rehacen con motivo fechado.

3. **Booking.com: medir si trae algo** *(conectado 09–13/08/2026)*. Cero reservas al 14/08.
   Nicasio vendió 10 noches de agosto por ese canal. Es el experimento estructural abierto y
   sigue **sin resultado medido**.

4. **Comisión de Booking.com: el motor no la captura** *(13/08/2026)*. `host_payout = bruto`
   en ese canal → cada euro infla el margen 15–18 %. Deuda técnica; hoy no afecta a Marechal
   porque tiene 0 reservas de Booking, pero la afectará en cuanto entre la primera.

5. **`f_pricelabs_oportunidades` no excluye `booking_status = 'Blocked'`** (migración 072,
   línea 66) *(13/08/2026)*. Hoy no se cuela ninguna fila por casualidad, pero una noche
   bloqueada con override de precio aparecería en `/precios` como euros sobre la mesa
   inexistentes. Marechal es el piso que más expuesto está, por ser el único con bloqueos.

6. **`guesty-sync` no ingesta bloqueos** *(13/08/2026)*. Deuda técnica de fondo: sin esto,
   "noches libres" miente en Marechal cada vez que Stag viaja.

7. **Contradicción del bloqueo 22–25/08 sin cerrar** *(13/08/2026)*: PriceLabs dice 4 noches
   bloqueadas, el PMS declara 1 entidad de bloqueo y otra "available con huésped". Se cierra
   abriendo Guesty y mirando el calendario.

8. **Luz de febrero (desvío 1–7 €) y de abril (~15,60 € sin facturar)** *(29/07/2026)*.

9. **Subida estructural de mínimos el 01/10/2026** vía Custom Seasonal Profile *(compromiso
   con fecha, ESTADO.md §5)*. **No antes.** Con el 67 % de las noches publicando al mínimo,
   Marechal es el candidato más claro. Revisar a las 2 semanas y apagar si el pickup no
   responde.

10. **Confisic: régimen de IVA de los pisos de Madrid** *(consulta abierta desde el
    24/04/2026, sin respuesta)*. Si el IVA soportado resulta deducible, el coste de renta de
    Marechal baja de 1.304,90 a 1.078,43 €/mes. Vive en el proyecto Admin & Fiscal.

11. **Descuentos nativos de Airbnb sin verificar anuncio por anuncio** *(07/08/2026)*. Solo
    hay capturas de Jacobine; los de Marechal se asumen iguales porque Stag lo confirmó de
    palabra. Ya costó un error una vez (se infirió −20 % y era −15 %).

---

## Enlaces

- [PLAYBOOK de pricing](../pricing/PLAYBOOK.md) — reglas permanentes con su cicatriz.
  **Leer antes de tocar un precio.** Especialmente relevantes para este piso: §2.5 (suelos),
  §2.7 (`price_type`), §2.8–2.9 (bloqueos), §3.3 (limpieza), §4.3 (elasticidad ~0),
  §4.7 (min-stay 1 prohibido acá), §5.7 (guardia de precios sin techo).
- [BITACORA de pricing](../pricing/BITACORA.md) — **entrada del 13/08/2026: el diagnóstico
  completo de Marechal** (7 agentes, 4 lentes + 3 verificadores). En cuatro líneas:
  (1) las noches 22–25 estaban **bloqueadas**, no libres — era el viaje de control de Stag;
  (2) el cero del 10 al 12/08 lo causaron tres overrides cargados como **porcentaje**, que
  publicaron 190–281 €;
  (3) las noches 16–18 están sanas y **el precio ya está agotado como palanca** (percentil
  16–19, cero *inquiries*);
  (4) la tesis "es visibilidad" quedó **sin sustento** — 87 reservas y PriceLabs lo marca
  *outperforming the market*: el déficit real es **ventana corta entre semana**, y noviembre
  es 3× el agujero de agosto.
- [ESTADO.md](../pricing/ESTADO.md) — **cómo leer la verdad en 30 segundos**, identificadores
  de los cuatro pisos, lo que no se puede leer por API y los compromisos con fecha.
- Fichas hermanas: `NICASIO.md` (1A_NICA) · `ALEXANDER.md` (4B_ALEX) · `JACOBINE.md`
  (1A_JACO) — los tres de Madrid comparten edificio, comp set y ecosistema de proveedores.

---

**Manual de operación** (cierre mensual, proveedores, bloqueos): [`../operativa/CASUISTICAS.md`](../operativa/CASUISTICAS.md)

*Última revisión: 14/08/2026 · Las cifras de esta ficha CADUCAN: se regeneran con las
consultas de [`../pricing/ESTADO.md`](../pricing/ESTADO.md). Ante cualquier duda entre lo escrito
acá y la base, manda la base.*
