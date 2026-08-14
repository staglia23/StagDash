# Alexander (4B_ALEX)

> ⚠️ **Ojo con la ventana**: esta ficha está calculada sobre **ene–jul 2026**, mientras que
> las otras tres y el [README](../README.md) usan **ene–ago**. Las dos series son correctas —
> cada una en su rango — pero no se pueden comparar entre fichas. Pendiente: unificar a ene–ago.

> El piso que más factura de Madrid y el que menos margen deja: vende casi lleno, con la
> antelación más larga de los cuatro, y una renta que se lleva el 41,5 % del ingreso y que
> **sube sola el 01/10/2026**.

Datos consultados el **viernes 14/08/2026** contra el motor (Supabase) y PriceLabs.
Salvo aviso, el período del motor es **ene–jul 2026 devengado** (`cierre_hasta` = julio).

---

## Identidad

| | |
|---|---|
| Código | `4B_ALEX` |
| PriceLabs / Guesty listing_id | `68de7eea3a04a20013151869` |
| Airbnb | `1489717538166644615` |
| Booking.com | `15469385` (conectado, **cero reservas**) |
| Modelo | Subarriendo |
| Bajo gestión desde | **01/10/2025** (`listings.fecha_inicio`) |
| Ciudad / edificio | Madrid — mismo edificio que Nicasio y Marechal |
| Dormitorios | 1 (PriceLabs, 14/08) |
| Limpieza que **se cobra** | 50 € por reserva (media real cobrada 50,50 €; máximo visto 60 €) |
| Limpieza que **cuesta** | **43,80 €** (`listings.limpieza_por_reserva`) — coste real devengado ene–jul: 2.630,11 € / 57 reservas = **46,14 €** |

La limpieza **pierde plata**: la comisión de canal se cobra también sobre ella (18,69 % medido
acá), así que de los 50 € entran 40,66 € contra un coste de 43,80 € → **−3,14 € por reserva**
(−5,48 € si se usa el coste real devengado). No es palanca de conversión — ver PLAYBOOK §3.3.

---

## Cómo gana dinero

**Subarriendo**: Samavi le paga una renta fija al propietario y se queda con todo lo que venda
por encima. Eso significa que **el coste grande ya está pagado el día 1 del mes** y cada noche
extra cae casi íntegra a contribución.

- `listings.renta_base` = **1.414,22 €/mes** (lo que se transfiere hoy). El motor carga el
  **peor caso fiscal**: base × 1,21 con el IVA como coste no deducible (migración 022, consulta
  a Confisic sin respuesta) → **1.677,65 €/mes** de coste modelado. La retención del 19 % **no
  es coste** (es IRPF del propietario que Samavi ingresa por el modelo 115).
- La renta se lleva el **41,50 %** del ingreso de Samavi (11.280,06 € de 27.178,17 € YTD).
  Costes totales, incluida la cuota de overhead: **92,13 %** del ingreso.
- **Contribución por noche: 126,54 €.** Las primeras **177,1 noches** del año pagan todos los
  costes fijos (22.409,51 €, cuota de overhead de 7.746,54 € incluida). De la noche 178 en
  adelante, cada noche deja esos 126,54 € casi enteros.

Traducido: en Alexander el margen no lo hace el ADR, lo hacen **las últimas 16 noches del año**.

---

## Los números que mandan

**Fecha del dato: 14/08/2026.** Fuente: `f_breakeven` y `f_ranking` / `f_pnl_mensual_propiedad`
sobre `2026-01-01 → 2026-07-31`. Todo **real (devengado)**.

| | |
|---|---:|
| **ADR de equilibrio** | **160,41 €** |
| ADR real YTD | **174,11 €** (+13,70 €/noche de colchón) |
| Contribución por noche | 126,54 € |
| Ocupación real | **91,51 %** (194 de 212 noches) |
| Ocupación de equilibrio | **83,54 %** (177,1 noches) |
| **Colchón** | **+7,97 pp ≈ 16 noches** |
| Costes fijos del período | 22.409,51 € |
| Ingreso bruto YTD | 33.776,48 € |
| Ingreso de Samavi YTD | 27.178,17 € |
| Comisión de canal | 6.312,29 € (18,69 % del bruto = 32,54 €/noche) |
| RevPAR | 159,32 € |
| **Margen neto YTD** | **+2.138,56 €** (7,87 % · 11,02 €/noche) |

El ADR de equilibrio se calculó hoy así: costes fijos ÷ noches vendidas (115,51) + limpieza por
noche (13,56), dividido por lo que queda tras la comisión de canal (0,8046) = **160,41 €**.
El PLAYBOOK §4.5 anota 159 € para este piso: misma cuenta, ventana distinta — la diferencia es
ruido, no contradicción.

### Vende por debajo de su equilibrio: cuánto

| Período | Noches | Bajo 160,41 € | % | ADR de esas noches |
|---|---:|---:|---:|---:|
| YTD ene–jul (real) | 194 | **98** | **50,5 %** | 131,13 € |
| Forward 14/08–31/12 (ya reservado) | 78 | **30** | 38,5 % | 136,85 € |

- YTD faltaron **2.869,62 € de bruto** (≈2.309 € netos de comisión) en esas 98 noches. Las 96
  noches restantes lo compensan de sobra — el margen neto es positivo —, pero **la mitad del año
  se vende por debajo del punto de equilibrio y lo salva abril–junio**.
- **Agosto restante (14–31)**: 18 de 18 noches vendidas, ADR 150,71 €. **15 de las 18 van por
  debajo del equilibrio** → −9,70 €/noche.
- **Noviembre**: las 11 noches ya vendidas están **todas** bajo equilibrio, a 124,01 € → −36,40 €
  por noche. Es el agujero más caro del forward.
- **Enero 2027**: 9 de 9 noches vendidas bajo equilibrio, a 147,74 €.
- Septiembre (217,63 €) y octubre (224,78 €) están muy por encima: ahí no hay nada que tocar.

Matiz honesto: una noche por debajo del ADR de equilibrio **no es una noche que pierde plata**
—cada noche vendida aporta ~80 % de su tarifa contra costes que ya están pagados—. El equilibrio
es un **promedio anual**: es la vara para decidir si conviene bajar el suelo, no un piso por noche.

### El mes a mes deja ver dónde está el problema

| Mes | Noches | Ocup. | ADR | Margen neto |
|---|---:|---:|---:|---:|
| Ene | 29 | 93,5 % | 125,36 € | **−482,59 €** |
| Feb | 27 | 96,4 % | 126,11 € | **−753,51 €** |
| Mar | 28 | 90,3 % | 155,64 € | +39,59 € |
| Abr | 28 | 93,3 % | 220,88 € | +758,42 € |
| May | 29 | 93,5 % | 211,56 € | **+1.603,68 €** |
| Jun | 27 | 90,0 % | 214,29 € | +833,39 € |
| Jul | 26 | 83,9 % | 164,32 € | +139,58 € |

Enero y febrero llenaron el piso (93 % y 96 % de ocupación) y aun así perdieron 1.236 € entre
los dos. **No es un problema de ocupación: es de tarifa de invierno.**

---

## Cómo se vende de verdad

Medido hoy sobre `reservations` (confirmadas, estancias del 01/01 al 13/08/2026, n = 60).

**Se reserva con muchísima antelación — es el rasgo que lo separa de los otros tres.**

| Lead time | 4B_ALEX | NICA | MARE | JACO |
|---|---:|---:|---:|---:|
| Mediana | **104 días** | 88 | 70,5 | 71 |
| % a ≤7 días | **1,7 %** | 8,8 % | 8,3 % | 17,0 % |
| % a ≤14 días | **5,0 %** | 10,5 % | 10,0 % | 17,0 % |

Rango intercuartílico 71–125 días; **61,7 % de las reservas entran a ≥90 días**; máximo 214 días.
Segunda fuente que dice lo mismo: en `pricelabs_prices` las 101 noches forward ya vendidas tienen
una mediana de **116 días** entre reserva y estancia, con solo un 3 % a ≤30 días.

**Consecuencia directa sobre los descuentos de Airbnb**: el −15 % de última hora **casi no se
usa acá** (solo el 5 % de las reservas cae dentro de la ventana de 14 días). El que muerde de
verdad es el **−10 % de reserva anticipada (≥3 meses)**, que alcanza a 6 de cada 10 reservas.
Evidencia dura de hoy: la reserva que ocupa el 17–21/08 se cerró a **116,10 €/noche**, que es
exactamente el suelo publicado de 129 € menos un 10 % (129 × 0,90 = 116,10).

**Duración y días de la semana**

- Estancia media **3,35 noches** (mediana 3). 57 reservas devengadas ene–jul.
- La ocupación es **plana** — se llena todos los días: lun 93,8 %, mar 84,4 %, mié 90,6 %,
  jue 87,9 %, vie 87,5 %, sáb 90,6 %, dom 93,8 %.
- Lo que cambia es el precio: **jue 188,10 · vie 188,95 · sáb 186,73** contra **lun 156,67 ·
  mar 156,14 · dom 164,03**. El martes es el día flojo por los dos lados.

**Mix de canal**

- **99,78 % del bruto entra por una sola cuenta de Airbnb** (`airbnb2`): 59 reservas, 200 noches,
  34.523,82 €. La única otra reserva del año es una manual de 75 €.
- **Booking.com está conectado y nunca vendió una noche**: 0 reservas en los 143 registros
  históricos del piso. Ver [[canal-concentracion-comision]] en la memoria del proyecto.

**Estacionalidad (ADR real por mes de estancia, 2026)**

Abril 220,88 · junio 214,29 · mayo 211,56 · julio 164,32 · marzo 155,64 · febrero 126,11 ·
enero 125,36. Del histórico 2025 bajo gestión: oct 178,44 (87,1 %), nov 151,68 (76,7 %),
dic 164,37 (96,8 %).

**Dónde actuar, entonces**: no en agosto ni en septiembre/octubre (ya vendidos y caros), sino
en **noviembre, enero y febrero**, y con **90–120 días de anticipación**, que es cuando este piso
realmente se llena. Para noviembre 2026 eso significa que la ventana útil **ya se está cerrando**.

---

## Configuración de precios hoy

⚠️ **Estos valores caducan.** No se citan de memoria: se leen con las consultas de
[../pricing/ESTADO.md](../pricing/ESTADO.md) §1. Foto del 14/08/2026
(`last_refreshed_at` 06:03 UTC, `last_date_pushed` 06:03 UTC, sync PriceLabs 07:10 UTC).

| | |
|---|---:|
| Mínimo | **129 €** |
| Base | **182 €** |
| Máximo | **null** (sin techo, por decisión de Stag del 14/08/2026) |
| Base recomendado por PriceLabs | 183 € (`bp_ratio` 1,01) |
| Overrides vivos | **ninguno** (`get_listing_date_overrides` desde 14/08 → vacío) |
| Min-stay del anuncio | **3 noches** en las 262 noches libres del 12/10/2026 al 14/08/2027; **2 noches** en las dos libres cercanas (30/09 y 01/10) |
| Próximos 30 días | **30 de 30 vendidas** — 0 libres, 0 huérfanas, 0 bloqueadas (`v_pricelabs_forward`) |

- **6 de las próximas 30 noches (14–19/08) están publicadas exactamente al suelo de 129 €**
  porque la recomendación pura de PriceLabs era de 86 a 122 €. El suelo está haciendo su trabajo.
  Ninguna noche se publicó por debajo del suelo.
- Precio publicado en los próximos 30 días: de 129 a 268 €, media 161,20 €.

**Frente al comp set** (`get_neighbourhood_data`, 14/08): 258 pisos de 1 dormitorio en
La Latina / Plaza Mayor. p25 **122 €** · mediana **161 €** · p75 **199 €** · p90 **241 €**.
La base de 182 € queda **entre la mediana y el p75**; el suelo de 129 € apenas por encima del p25.

**Rendimiento contra el mercado**: ocupación próximos 30 días **100 % vs 55 %** del mercado;
45 días 98 % vs 58 %; 60 días 92 % vs 57 %. MPI a 60 días **1,6**. PriceLabs marca temporada alta
en septiembre-octubre y baja en diciembre, enero y julio, y en las dos estamos por encima del
mercado.

**Lectura de revenue**: el piso le gana al mercado por 40-45 puntos de ocupación mientras la
mitad de sus noches se venden bajo su propio equilibrio. Eso es un **suelo mal calibrado en
invierno**, no un problema de demanda (PLAYBOOK §2.5). La subida estructural de mínimos del
01/10 (ALEX 129 → 145) va exactamente en esa dirección — **no aplicarla antes** (PLAYBOOK §6).

---

## Casuísticas propias

### 1. El contrato de subarriendo — es el tema de este piso

*(Fuente: memoria `alexander-contrato-renovacion`, verificada contra el PDF firmado el
27/07/2026. Resumen sin datos personales.)*

- **Vence el 30/09/2026.** Si el propietario no preavisa dentro de los 30 días anteriores
  (ventana 01–30/09), **se prorroga 12 meses automáticamente**.
- **Samavi NO puede irse.** Ninguna parte puede desistir unilateralmente y el contrato dice
  expresamente que las dificultades económicas son "riesgo empresarial de la explotadora".
  "No renovar" no es una opción nuestra.
- **La única palanca de Samavi es la cláusula 4.3**: cada 12 meses las partes pueden renegociar
  la contraprestación. **Conviene abrirla antes del 01/09**, porque en cuanto se abre la ventana
  el propietario puede preavisar y cortar.
- IBI, basuras y las reparaciones de conservación son del propietario (por eso el termo de abril
  se le refacturó bien). Los suministros van a nombre de Samavi.

### 2. La renta sube sola el 01/10/2026

Verificado hoy en la base: `avisos` id 2, fecha 2026-10-01, `impacto_mes` **−237,95 €**; y tres
events de RENTA en oct, nov y dic de **−200,58 €** cada uno (en euros de transferencia).

Se agota el descuento del amoblamiento (saldo a favor de Samavi de 3.064 € ÷ 12 = 255,31 €/mes).
El coste modelado pasa de **1.677,65 → 1.915,60 €/mes**: **+237,95 €/mes = +2.855 €/año**.
Contexto: el margen neto de siete meses fue de 2.138,56 €. **La subida se come más de lo que el
piso ganó en todo lo que va del año.** Ocurre sola, sin que nadie firme nada.

### 3. La adenda pendiente (tres lecturas de la misma renta)

Hay tres cifras en circulación: el **pacto verbal** (el propietario recibe 1.614,80 € en cuenta),
el **contrato literal** (esa cifra como base, no como transferencia) y la **planilla** (con un
typo). El motor modela la verbal —la más favorable— **por instrucción de Stag, rompiendo el
criterio de peor caso**. Sin adenda escrita (cláusula 8.2: solo valen modificaciones escritas),
el contrato habilita a facturar más. Vale 460–852 €/año.

La adenda debería además:
- Fijar por escrito "transferencia / base / IVA 21 % / retención 19 %", en el formato del
  contrato de Marechal.
- Sacar **comunidad y seguro** de la renta: verificado el 27/07/2026 que no son de Samavi ni por
  contrato ni por ley. Vale 168,45 €/mes (2.021 €/año) y dejaría el salto de octubre en
  +69,50 €/mes en vez de +237,95.
- Decidir si se compensan los **~598 € pagados de más en 10 meses** (el prorrateo del amoblamiento
  se descontó sobre la base equivocada).

**El dossier de la negociación NO se trabaja en este repo**: vive en el proyecto Admin & Fiscal
(ver `proyecto-admin-fiscal-separado` en la memoria).

### 4. El IVA de la renta está modelado en el peor caso

Migración 022: el motor carga base × 1,21 tratando el IVA soportado como **coste no deducible**,
por decisión de Stag del 25/07/2026. La consulta a Confisic sobre el régimen de IVA de los tres
pisos de Madrid sigue **sin respuesta** desde abril de 2026. Si el IVA resultara deducible, el
margen de este piso sube. Son ~6.200 €/año en juego contando las tres rentas.

### 5. Suministros: la luz de enero está incompleta

- **CUPS `ES0022000007651519XG1P`**. El CUPS es lo único que identifica el
  piso: nunca clasificar una factura por carpeta ni por titular.
- **Enero 2026 cargado parcial** (migración 039): solo del 24 al 31/01 = 51,93 €. Del 01 al 23/01
  el punto de suministro estaba a nombre del titular anterior → **~149 € sin factura ni
  reembolso**, etiquetado `real_revisar`. Hay que preguntárselo al propietario.
- El contrato de de luz **sigue a nombre personal de Stag** — incumplimiento
  menor pero real de la cláusula 6.3. Pendiente refacturar a nombre de Samavi.
- Julio 2026 está en el motor como `suministros_fuente = estimado` (verificado hoy): los ciclos
  12/07–12/08 llegan en agosto.
- **El agua se le reembolsa al propietario** por recibo bimensual, vía event: ene −54,04 €,
  mar −38,11 €, jul −43,72 €.
- **Internet Movistar**: 25,00 €/mes (la línea barata de una factura que cubre dos fibras; la
  cara va a Marechal). Falta la fecha de fin de la promoción → salto a 36,00 €/mes.

### 6. Incidencias y equipamiento (events verificados hoy)

- **Termo Ariston**, abril 2026: −383,06 € (Obramat + instalación), **compensado por el
  propietario** con descuentos de renta en mayo (+191,53) y junio (+199,19). Se portó bien.
- **Mobiliario Klarna-Sklum**: 162,77 €/mes de enero a junio, más una **cancelación anticipada en
  junio de −472,28 €** que saldó julio-octubre con descuento (confirmado por Stag el 17/07).
  Ya no corre.
- **Cerradura**: revisión por atasco el 29/06 (−33,88 €, Ecocleans F260507). Revisión general del
  03/07 (−50,82 €, F260610, vence el 11/08 → aparece en el extracto de agosto: **no recargar**).
- **NRUA** (registro único de alojamiento), febrero: −28,67 €, pagado desde BBVA.
- **DIA Madrid**: desde la migración 075 se reparte en tercios entre los tres pisos de Madrid.

### 7. Trampas conocidas de este piso

- **Booking está conectado y no vende**: canal abierto, cero producción histórica. Antes de
  empujarlo, ojo con la trampa del motor — Booking usa "payment by the property", así que
  `host_payout = bruto` y **la comisión no se descuenta sola**: hay que cargarla como event.
- **Los bloqueos de calendario son invisibles para el motor** (PLAYBOOK §2.9). Hoy 14/08 Alexander
  **no tiene ningún bloqueo "Control"** (esos son Marechal 22–25/08 y Jacobine 18–20/08), pero sí
  aparecen dos noches `no_vendible` — **21/09 y 05/10** — que hay que mirar en Guesty antes de
  contarlas como huecos por vender.
- **Min-stay 1 en huecos huérfanos está AUTORIZADO en Alexander** desde el 09/08/2026 (decisión de
  Stag), a diferencia de Marechal que conserva la restricción.
- **Discrepancia enero 2027**: el motor ve 9 noches vendidas y PriceLabs 14. La diferencia son
  5 noches de una reserva `website` en estado `reserved` (no `confirmed`) desde el 05/01/2027 —
  el motor no la cuenta hasta que se confirme.
- **La memoria del 27/07 está desactualizada en los números**: decía ocupación de equilibrio
  97,31 % y −1.564 € YTD. Hoy el motor da **83,54 % y +2.138,56 €**. Manda el motor: aquellos
  números eran de un cierre con menos meses cargados y antes de varios ajustes. Lo que **sí**
  sigue vigente de esa memoria son las cifras del contrato y los porcentajes de renta (41,5 %)
  y comisión de canal (6.312 €), que reconcilian al céntimo con lo consultado hoy.

---

## Pendientes abiertos

1. **Antes del 01/09/2026 — abrir la cláusula 4.3 con el propietario.** Es la decisión con fecha
   más cara del año: +2.855 €/año en juego si no se negocia, +2.021 €/año más si se consigue
   sacar comunidad y seguro. Dossier en el proyecto Admin & Fiscal.
2. **Adenda de octubre**: fijar por escrito transferencia/base/IVA/retención y decidir si se
   compensan los ~598 € pagados de más. Sin ella, el contrato literal permite facturar más caro.
3. **Enero de 2027 — actualizar `listings.renta_base`** con lo que se acuerde. Los events de la
   subida solo llegan hasta diciembre de 2026.
4. **Luz del 01–23/01/2026 (~149 €)**: preguntarle al propietario si la pagó. Si la pasó, entra
   como event SUMINISTROS. Abierto desde el 25/07/2026.
5. **Refacturar el contrato de luz a nombre de Samavi** (hoy a nombre personal de Stag).
   Abierto desde el 26/07/2026.
6. **Promoción Movistar de la línea de este piso**: falta la fecha de fin (está en Mi Movistar).
   Salto de 25,00 a 36,00 €/mes. Abierto desde el 29/07/2026.
7. **Consulta de régimen de IVA a Confisic**: sin respuesta desde abril de 2026. Decide si el
   margen de este piso sube ~215 € YTD o si el IVA es coste puro.
8. **01/10/2026 — subida estructural del mínimo, 129 → 145 €** vía Custom Seasonal Profile.
   NO antes. Revisar el pickup a las 2 semanas y apagar el perfil si no responde (PLAYBOOK §6).
9. **Noviembre 2026 está entrando barato**: 11 de 11 noches vendidas a 124,01 €, 36,40 € por
   noche bajo el equilibrio, con el piso solo al 36,7 %. Dado que este piso se reserva a 104 días
   de mediana, **la ventana para corregir noviembre se está cerrando ahora**. Decisión de Stag
   pendiente.
10. **Booking.com**: decidir si se activa de verdad o se da por muerto. Si se activa, cargar la
    comisión por event (el motor no la ve).

---

## Enlaces

- [Playbook de pricing](../pricing/PLAYBOOK.md) — reglas permanentes con su cicatriz. **Leer
  siempre antes de tocar un precio.**
- [Estado vigente](../pricing/ESTADO.md) — cómo leer la verdad en 30 segundos, identificadores,
  descuentos nativos de Airbnb y bloqueos deliberados.
- [Bitácora](../pricing/BITACORA.md) — qué se probó y qué pasó.
- Fichas hermanas: [Nicasio](NICASIO.md) · [Marechal](MARECHAL.md) · [Jacobine](JACOBINE.md).
  Nicasio y Marechal comparten edificio y comp set con este piso; Marechal comparte el modelo de
  subarriendo (y también vende barato, pero por visibilidad, no por tarifa de invierno).
- Memoria del proyecto: `alexander-contrato-renovacion`, `rentas-iva-retencion-confisic`,
  `suministros-cups-mapeo`, `canal-concentracion-comision`, `motor-tres-capas`,
  `auditoria-pisos-pendientes`, `proyecto-admin-fiscal-separado`.

---

**Manual de operación** (cierre mensual, proveedores, bloqueos): [`../operativa/CASUISTICAS.md`](../operativa/CASUISTICAS.md)

*Última revisión: 14/08/2026 · Las cifras de esta ficha CADUCAN: se regeneran con las
consultas de [`../pricing/ESTADO.md`](../pricing/ESTADO.md). Ante cualquier duda entre lo escrito
acá y la base, manda la base.*
