# Casuísticas — el manual de "esto ya nos pasó"

**Qué es esto**: el catálogo de las situaciones que se repiten en la operación de Samavi y
cómo se resuelve cada una. Cuando aparezca algo que huele a conocido, se busca acá antes de
volver a decidirlo desde cero.

**Cuándo se lee**: en cada cierre mensual, al clasificar un gasto raro, al ver un número que
no cuadra, y antes de tocar SQL o de decirle a Stag que algo está hecho.

**Qué NO es**:
- **No es pricing.** Todo lo de precios, mínimos, min-stay y promociones vive en
  [`../pricing/PLAYBOOK.md`](../pricing/PLAYBOOK.md) (reglas), [`../pricing/BITACORA.md`](../pricing/BITACORA.md)
  (qué se probó) y [`../pricing/ESTADO.md`](../pricing/ESTADO.md) (cómo leer la verdad). Acá
  solo se enlaza.
- **No es la ficha de cada piso.** Lo específico de Nicasio / Alexander / Marechal / Jacobine
  va en `docs/propiedades/`.
- **No es la lista de pendientes.** Eso es [`../relevamiento-pendientes-2026-08.md`](../relevamiento-pendientes-2026-08.md).

**Regla de veracidad de este documento**: cada cifra que aparece acá se verificó contra
producción (Supabase `enlslwuokresrwbqpyeo`) o contra el repo **el 14/08/2026**. Lo que viene
de la memoria del proyecto y no se pudo verificar está marcado *(de memoria, sin verificar)*.
Donde la memoria y los datos se contradicen, están las dos versiones y cuál manda — ver §9.

---

## Índice

1. [Cierre mensual y conciliación bancaria](#1-cierre-mensual-y-conciliación-bancaria)
2. [Facturas y proveedores](#2-facturas-y-proveedores)
3. [Recobros a la dueña de Jacobine](#3-recobros-a-la-dueña-de-jacobine)
4. [Bloqueos de calendario](#4-bloqueos-de-calendario)
5. [Cancelaciones y cobros retenidos](#5-cancelaciones-y-cobros-retenidos)
6. [Sincronización y frescura del dato](#6-sincronización-y-frescura-del-dato)
7. [Seguridad al crear objetos SQL nuevos](#7-seguridad-al-crear-objetos-sql-nuevos)
8. [Trabajo con el usuario](#8-trabajo-con-el-usuario)
9. [Contradicciones detectadas el 14/08/2026](#9-contradicciones-detectadas-el-14082026)

---

## 1. Cierre mensual y conciliación bancaria

### Cuándo aparece

A principios de cada mes, para cerrar el mes anterior. Es el único ritual del negocio que
tiene fecha propia y que, si se saltea, envenena todo lo demás: el margen por piso, el
break-even y el simulador salen de acá.

**Cómo sabés en qué mes vas**: `select cierre_hasta from v_freshness`. Verificado el
14/08/2026: **`cierre_hasta = 2026-07-01`**, o sea que el último mes conciliado es **julio
2026**. El chequeo 9 de `v_cuadre` ("Conciliado contra bancos") devuelve lo mismo: mes 7.

### Cómo se resuelve, paso a paso

**Paso 1 — Stag sube los archivos a Drive.** Ruta fija:
`Confisic → SAMAVI GLOBAL VISION SL → <año> → "MM - Mes" → BANCOS EXTRACTOS`.
Tienen que estar los cuatro:

| Archivo | Formato | Ojo |
|---|---|---|
| Extracto **Revolut** del mes | CSV `account-statement_*.csv` | trae 1–2 días del mes anterior |
| Extracto **BBVA** del mes | "xls" que en realidad es XLSX renombrado | no nombra al pagador de las transferencias |
| Reporte de transacciones de **Airbnb**, cuenta Revolut | CSV | Revolut cobra Nicasio + Jacobine |
| Reporte de transacciones de **Airbnb**, cuenta BBVA | CSV | BBVA cobra Alexander + Marechal |

Los CSV que llegan de Drive vienen en base64: se decodifican con `base64 -D` (macOS).

**Paso 2 — cargar banco y Airbnb.** El lector es `scripts/parse_extractos.py`, que entiende
los tres formatos y escribe SQL idempotente (borra por `archivo` antes de insertar). El
procedimiento completo está en [`scripts/RUNBOOK_conciliacion.md`](../../scripts/RUNBOOK_conciliacion.md),
incluido el mapeo fijo de cada cuenta bancaria a sus dos pisos.

```bash
python3 scripts/parse_extractos.py rev-<mes>.csv bbva-<mes>.csv airbnb-a-<mes>.csv airbnb-b-<mes>.csv > carga.sql
```

Alimenta dos tablas:
- `bank_deposits` (`banco, iban, fecha, importe, concepto, es_airbnb, archivo`). Julio 2026
  verificado hoy: **26 depósitos, 14.644,88 €** (BBVA 11 / 6.772,81 · Revolut 15 / 7.872,07).
- `airbnb_tx` (`tipo, fecha, fecha_llegada, confirmation_code, iban, noches, cobrado, …`).
  Verificado hoy: **464 filas, del 02/12/2025 al 31/07/2026**, con tres tipos: `Payout`,
  `Reserva`, `Resolucion`.

**Paso 3 — clasificar cada movimiento del extracto** con las reglas permanentes (§1.3).

**Paso 4 — cargar las diferencias como `events`.** Un `event` es un ajuste mensual por
propiedad. La tabla es `(anio, mes, propiedad_codigo, categoria, concepto, importe, notas)` —
**ojo: no tiene columna `fecha`**, se imputa por año+mes. Signo: **negativo = gasto, positivo
= crédito**. Categorías vivas en 2026 (verificadas hoy): `OTROS` (100 events, −11.683,46 €),
`CORPORATIVO` (19, −7.699,78 €), `SAMAVI_GEN` (10, −1.075,88 €), `RENTA` (7, +1.623,48 €) y
`SUMINISTROS` (3, −135,87 €).

**Paso 5 — verificar.** Abrir `/cuadre` y mirar los 10 chequeos de `v_cuadre`. Estado del
14/08/2026: los 9 chequeos con veredicto en **ok** y el nº 9 en `info` (mes 7). Referencias
del día: ingreso YTD 105.921,96 €, resultado Samavi 11.430,40 €, pool de overhead prorrateado
35.323,40 €.

Volumen típico de un cierre, para saber si te quedaste corto (events por mes, 2026,
verificado hoy): enero 15 · febrero 17 · marzo 17 · abril 17 · mayo 18 · junio 21 · **julio
26**. Julio suma **−3.775,54 €**.

### 1.3 Cómo se clasifica un movimiento

Las reglas permanentes viven en la memoria del proyecto
(`clasificacion-bancaria-reglas.md`) — **consultarla siempre antes de clasificar**, porque se
actualiza. Resumen operativo al 14/08/2026:

| Qué | A dónde va | Desde cuándo |
|---|---|---|
| Compras hogar/reposición Madrid (Amazon, Ikea, Zara Home, ferreterías, El Corte Inglés, Rituals, flores, H&M) | **1A_NICA**, event mensual | 21/07/2026 |
| **DIA de Madrid** | **en tercios** entre los 3 pisos de Madrid (NICA se lleva el céntimo del redondeo) | regla de Stag 10/08/2026; retroactivo ene–jun en la migración 075 |
| DIA Sevilla y "Mp\*\*Día" | **1A_JACO**, event "Amenities/consumibles Sevilla" | 26/07/2026 (migración 048; antes lo cubría una provisión fija que ya no existe) |
| Lavandería de Sevilla | **1A_JACO**, event mensual | — |
| Tiendas de decoración/regalos de Sevilla | **1A_JACO**, amenities, event aparte | 23/07/2026 |
| Comidas de negocio (Uber Eats, Glovo, restaurantes; MCC 5812/5813/5814) | `SAMAVI_GEN` (overhead operativo) | — |
| Transporte: taxis/VTC (MCC 4121), Renfe, iryo, vuelos | **`CORPORATIVO`**, nunca a un piso | ratificado por Stag 26/07/2026 |
| Herramientas de trabajo (equipo informático, auriculares) | `SAMAVI_GEN`, **no** a compras de hogar de Nicasio | migración 036 |
| Impuestos **personales** de Stag pagados desde la cuenta de empresa | **no son gasto**: ni P&L ni overhead → cuenta con el socio, lo regulariza Confisic | 26/07/2026 |
| Limpieza puntual contratada por app en Sevilla | **1A_JACO** como coste de Samavi, fuera de la refactura fija de 700 € a la dueña | 10/08/2026 |
| Resoluciones del Resolution Center de Airbnb (cobros y devoluciones) | **SIEMPRE Samavi** | decisión de Stag 11/08/2026 |

Y las tres reglas de desempate:

1. **Si un gasto está en el extracto y en la lista de bolsillo de Stag, manda el extracto.**
   Cargarlo dos veces fue el error que corrigió la migración 050.
2. **El comercio miente.** El barrido bancario imputa por comercio, pero una ferretería de
   Madrid puede ser la copia de llaves de Sevilla y un Amazon puede ser un mini UPS de
   Jacobine. Sin la lista de Stag no hay forma de saberlo.
3. **Antes de imputar un Amazon grande, abrir el extracto.** En junio 2026 un cargo de
   731,00 € eran diez pedidos menos un reembolso, y uno no era del piso.

Distinguir Madrid de Sevilla cuando aparece una tienda nueva: (a) el número de tienda del
comercio, (b) la tarjeta — las compras de Sevilla las hace el empleado de allá con la tarjeta
**Standard**; con la **Metal** compra Stag donde esté. Si la tienda es nueva y fue con la
Metal, **se le pregunta a Stag**, no se adivina. Mapa de tarjetas Revolut: Metal = Stag día a
día · Standard = el empleado de Sevilla · Virtual = suscripciones y compras online ·
PriceLabs = PriceLabs.

### 1.4 Por qué el extracto solo NO alcanza

Cuatro agujeros estructurales, todos descubiertos con casos reales:

1. **Hay pagos en efectivo que nunca llegan al banco.** Precedentes del 26/07/2026: 210 € al
   un tercero del edificio en Marechal, dos NRUA (32,73 + 28,67) y 82,22 € de bolsillo en Jacobine. Solo
   aparecen en las listas de gastos de bolsillo de Stag (el libro privado de ingresos y
   finanzas en Drive, cuatro columnas, una por piso, con fecha + importe +
   concepto). Precedente del 18/08/2026: la gratificación de 250 € a José, pagada con el
   efectivo de una reserva cobrada por fuera (migración 084). **Un gasto marcado como pagado en
   efectivo no se busca en el extracto**: que no aparezca es lo esperado.
2. **Hay que abrir SIEMPRE los dos bancos.** Del BBVA salen cosas que no están en el Revolut:
   TGSS, comunidad, TotalEnergies, Telefónica, Orange, Ayuntamiento/IBI, los adeudos de la
   tarjeta, el préstamo y transferencias sueltas. El 26/07/2026 se descubrió que dos cargos
   estaban marcados "sin respaldo bancario" cuando estaban en el BBVA.
3. **Hay gastos que Samavi ya se cobró** → antes de cargar un gasto de Jacobine, mirar la
   columna GASTOS de la cuenta corriente de la dueña: si está ahí es **neutro** y no va al
   P&L (ver §3). Precedentes: mini UPS 77 € (feb-2026) y aspiradora 130 € (mar-2026),
   cargados por error como coste de Nicasio hasta la migración 049.
4. **Hay ingresos sin depósito.** Una reserva directa cobrada en efectivo ya está devengada
   por Guesty y **no** se carga a `bank_deposits` ni a `events`; el efectivo queda en poder de
   Stag → cuenta con el socio. Precedente: una reserva directa de 3 noches de julio-2026, 520 €. En el
   cuadre esa reserva nunca va a tener respaldo bancario y **eso es normal, no un agujero**.

   **Cómo se identifican sin preguntar** (hallazgo del 18/08/2026): el sync guarda el objeto
   `money` de Guesty entero en `reservations.money_raw`, y ahí vive `payments[]` con la nota,
   el importe, la fecha y el método de cada cobro. El `paymentMethodId`
   `58a1931c0000000000000e87` es el que Guesty usa para todo lo cobrado **fuera de la
   pasarela**; qué fue exactamente lo dice la nota que escribe Stag ("Pago en efectivo",
   "Entregado a Jose en mano", "Cash Claudio", "CA USD Galicia"…). No hay campo tipado: la
   nota es la fuente. Antes de dar por descuadrado un ingreso sin depósito, correr esto:

   ```sql
   select r.codigo, r.confirmation_code, r.checkin_local, r.bruto,
          p->>'note' as nota_pago, (p->>'amount')::numeric as importe, p->>'paidAt' as pagado_el
     from reservations r, jsonb_array_elements(r.money_raw->'payments') p
    where p->>'paymentMethodId' = '58a1931c0000000000000e87'
    order by r.checkin_local desc;
   ```

La procedencia de las fuentes también tiene regla (Stag, 26/07/2026): **la planilla manual es
cómo se manejaba antes del dashboard y puede tener errores** — se contrasta contra
documentación real o contra confirmación suya, nunca se asume. Los apuntes que descansan solo
en ella quedaron marcados con ⚑ en `events.notas` para que nadie los lea como conciliados.

### 1.5 Trampas

- **Convención temporal**: cada cargo se imputa al mes del extracto donde aparece. Los
  extractos de Revolut traen 1–2 días del mes anterior: no duplicar.
- **Facturas que vencen a caballo**: los dos pagos de Ecocleans de julio vencieron el 11/08 y
  caen en el extracto de agosto. Ya están cargados en julio por devengo — **no recargarlos**
  (aviso del 11/08/2026).
- **Adeudos de tarjeta**: el adeudo de la tarjeta que aparece en agosto ya está dentro del
  event de julio (470,06 €). No se carga dos veces.
- **AEAT modelo 111** (retenciones): tratamiento fijado el 11/08/2026 con el PDF del 2T. La
  retención de la nómina de Stag **no** genera event (ya vive dentro de la provisión "Sueldo
  Stag bruto", 3.333,33 €/mes; **verificada contra banco el 18/08/2026**: 3.333,33 × 0,90 =
  3.000,00 netos exactos, que son los que salen de Revolut cada mes como "Retribución
  administrador" — ver [RETRIBUCION_CEO.md](RETRIBUCION_CEO.md)); la del empleado de
  Sevilla **sí** (event mensual en JACO de −10,56 €, −10,55 € al cierre de trimestre); las
  retenciones de profesionales van como event `CORPORATIVO` en el mes del pago (julio 2026:
  −71,86 €, verificado hoy).
- **Pagos extra a José (gratificaciones, bonus).** Van como event `OTROS` en `1A_JACO` y **los
  asume Samavi** — no se refacturan a la dueña, igual que amenities, lavandería y toallas; lo
  único que la dueña paga en Jacobine son los 700 €/mes de limpieza. Precedente: 250 € el
  18/08/2026 por las 5 estrellas del anuncio (migraciones 083 y 084). **Ojo con el medio de
  pago**: ése se pagó **en efectivo**, de una reserva que Stag cobró por fuera (le dio 250 € a
  José y el resto se lo quedó), así que **no tiene respaldo bancario y no debe buscarse en el
  extracto** — ver §1.4, punto 1. El efectivo cobrado queda en poder de Stag → cuenta con el
  socio, y pagar con él un gasto de Samavi baja ese saldo.
- **Booking no descuenta su comisión.** Booking es "payment by the property": el motor ve el
  bruto y no la comisión, así que la cuenta como ingreso y nunca la resta. Verificado hoy: las
  dos reservas de Booking de Nicasio de agosto tienen `host_payout = bruto` (1.054,52 € del
  16–23/08 y 1.215,52 € del 29/08–03/09). Además **Booking factura por fecha de salida**, así
  que una reserva a caballo cae en el mes equivocado — la del 29/08 al 03/09 es justo ese
  caso. Hoy se parchea con un event cuando llega la factura (precedente: junio 2026,
  181,52 €); el motor propio está pendiente (item A3 del relevamiento).

### 1.6 Dónde están los datos

| Qué | Dónde |
|---|---|
| Ritual completo, paso a paso | `scripts/RUNBOOK_conciliacion.md` |
| Lector de los 3 formatos | `scripts/parse_extractos.py` |
| Depósitos bancarios | tabla `bank_deposits` |
| Transacciones de Airbnb | tabla `airbnb_tx` |
| Ajustes del cierre | tabla `events` |
| Panel de control | `/cuadre` → vistas `v_cuadre`, `v_cuadre_banco`, `v_conciliacion_airbnb` |
| Hasta dónde está cerrado | `v_freshness.cierre_hasta` |
| Reglas de clasificación (fuente viva) | memoria del proyecto → `clasificacion-bancaria-reglas.md` |

**Advertencia sobre `/cuadre`**: `v_conciliacion_airbnb` se calcula desde `reservations`, o
sea desde **Guesty**, no desde Airbnb. El panel compara "lo que Guesty dice que Airbnb pagó"
contra el banco. Desde que `airbnb_tx` está completa (dic-2025 → jul-2026, migraciones 074 y
078) la tercera punta existe de verdad para ese período; fuera de él, la pata Airbnb sigue
siendo Guesty.

---

## 2. Facturas y proveedores

### 2.1 Ecocleans (limpieza de los tres pisos de Madrid)

**Cuándo aparece**: todos los meses, con **un mes de desfase entre factura y pago** (la
factura de diciembre se paga el 16/01). Jacobine no entra: la limpia el empleado de Sevilla y
en el motor cae al estimado.

**Dónde están los archivos** (Stag pidió que quedara escrito): Drive → `05 - PROVEEDORES` →
`EcoCleans` → `2026` → `"MM - Mes"`. Cada mes trae cuatro cosas: factura de **limpieza**,
factura de **mantenimiento** (separada desde julio 2026), `RESUMEN SERVICIOS MENSUAL.pdf` y la
hoja "Conciliación Ecocleans MM-AAAA" del Apps Script.

**Cómo se lee una factura, paso a paso**:

1. **Ir al RESUMEN, no a la factura ni a la hoja de conciliación.** La factura trae tres
   líneas a tanto alzado (limpieza / amenities / renting) sin horas ni unidades. El detalle
   está solo en el `RESUMEN SERVICIOS MENSUAL.pdf` y **su tabla es una imagen incrustada**:
   hay que leerla visualmente, la capa de texto solo tiene el título.
2. **Verificar las tres identidades**:
   - Σ horas = línea de limpieza ÷ **16,40 €/hora**
   - Σ renting = línea de renting
   - Σ servicios × **1,80 €/kit** = línea de amenities
3. **Descontar los servicios SUR**: no facturan horas, pero sí renting y kit. En marzo 2026 la
   tabla sumaba 41,17 h y la factura cobraba 38,17: la diferencia eran dos SUR de 1:30. Sin
   descontarlos, cualquier chequeo de horas da falso positivo.
4. **Separar los abonos.** Algunas facturas traen abonos que corrigen meses anteriores (enero
   −52,50 €, marzo −12,30 €): no son coste del mes ni atribuibles a un piso.
5. **Cargar en `limpieza_mensual`** (`anio, mes, codigo, servicios, horas, limpieza_eur,
   kits_eur, renting_eur, base_eur, iva_eur, factura, fiable`). Con eso el motor deja de
   estimar.
6. **El mantenimiento va aparte, a `events`, con IVA y por piso** (precedente migración 076).

**Tarifas vigentes** (esquema nuevo desde julio 2026): hora **16,40 €**, kit **1,80 €**,
renting **13,24 €/servicio plano** (antes 10,44 € normal / 20,24 € cuando CD=2). Apareció
además la partida **"Deshecho textil"** dentro de la línea de renting, sin piso asignado: en
julio se asignó a Nicasio porque el servicio del 29/07 fue un cambio de textil.

**Último mes cargado, verificado hoy**: julio 2026, factura **F260609**, `fiable = true` en
las tres filas — Nicasio 7 servicios / 14,00 h / 373,01 € de base · Marechal 5 / 7,50 h /
198,20 € · Alexander 4 / 6,00 h / 158,56 €. Junio es la F260506, con el fix del kit de
Alexander (9 → 8 kits) que la dejó cuadrando al céntimo.

**Trampas conocidas**:

- **Las hojas de conciliación del Apps Script mienten.** Su función de chequeo compara
  `kitsCuadra` y `rentingCuadra` **consigo mismos**: no pueden fallar nunca, así que un ✅ suyo
  no prueba nada. Errores reales encontrados: marzo asignó un SUR al piso equivocado y validó
  1.127,64 € ignorando el abono de −12,30 € (el bueno era 1.112,76 €); mayo se comió una fila
  entera y contó 24 servicios en vez de 25. El fix está escrito en
  `integrations/apps-script/FIX_chequeos_tautologicos.md` y **no hay evidencia de que esté
  aplicado** (item E7 del relevamiento, abierto al 14/08/2026).
- **Falsos negativos**: la hoja de julio dijo "⚠️ NO CUADRA 836,88 vs 883,02" y era falso (no
  conoce el "Deshecho textil", chequeo tautológico e IVA mal transcrito). Julio se cargó a
  mano con la migración 079.
- **Riesgo de pisado**: `limpieza_mensual` de julio **no** entró por la Edge Function
  `limpieza-ingest`. Si el ingest de Cowork corre después con sus números, **pisaría los
  buenos**. Coordinar el fix con Fede antes de dejarlo correr.
- **Anomalía abierta**: 9 checkouts del 02–11/07/2026 sin servicio facturado (16 servicios
  contra 24 checkouts; el primer servicio del resumen es del 12/07). Vigilar retro-factura en
  agosto o preguntar a Ecocleans quién limpió esos.

**Dónde vive la conciliación**: en el **Apps Script** (`Ecocleans_Auto.js`, proyecto de Claude
Cowork), no en el dashboard, y así debe seguir — tiene acceso nativo a Gmail/Drive y autoriza
el pago. Lo que se conectó (migración 031) es la salida: escribe `limpieza_mensual` en
Supabase vía la Edge Function `limpieza-ingest`.

### 2.2 Suministros: el CUPS manda

**Cuándo aparece**: cada vez que llega una factura de luz o gas de los pisos de Madrid.

**La regla, en una línea**: **el CUPS es lo único que identifica el piso**. Es el punto de
suministro físico y no cambia aunque cambien el titular o la comercializadora. El nombre de la
factura NO sirve — hay facturas de un piso a nombre personal de Stag —, y la carpeta de Drive
tampoco. La tabla CUPS ↔ piso está en la memoria del proyecto (`suministros-cups-mapeo.md`,
verificada el 25/07/2026 contra las facturas del Drive de Confisic) y los detalles por piso
van en `docs/propiedades/`.

**Paso a paso**: abrir el PDF → leer el CUPS → cruzarlo con la tabla → prorratear por días →
cargar. Nunca al revés.

**Trampas**:

- **Convención de días de cada comercializadora** (deducida el 26/07/2026 reproduciendo la
  serie completa): **TotalEnergies factura con inicio inclusive y fin exclusive** ("11.02–11.03,
  28 días" = del 11/02 al 10/03); **papernest factura con ambos extremos inclusive** ("DEL
  12/01 AL 04/02, 24 días"). Con esa regla, 16 de los 17 meses-propiedad cargados reproducen
  dentro de 0,16 € de redondeo.
- **Los meses con cambio de comercializadora no cierran**: el único mes que no reprodujo es
  justo aquel en que un CUPS pasó de papernest a TotalEnergies con solape. Si un mes no
  cuadra, mirar primero si hubo cambio de comercializadora.
- **Los períodos anteriores a que el CUPS fuera de Samavi no tienen factura propia** y quedan
  como hueco a reclamar al titular anterior, etiquetados `real_revisar`.
- **Una factura puede cubrir dos servicios**: una factura de internet de 55,00 €/mes cubre dos
  fibras y se parte entre dos pisos (30,00 + 25,00).

### 2.3 Cómo se imputa un gasto: las tres capas

Antes de decidir a dónde va un gasto, la pregunta no es "¿es grande o chico?" sino **"¿esto es
gestionar pisos o hacer crecer el negocio?"** (motor de tres capas, migración 025, decisión de
Stag del 25/07/2026):

1. **Coste directo de la propiedad** — si el gasto está en un piso concreto y es atribuible
   sin juicio. Va a `events` con `propiedad_codigo`.
2. **Overhead operativo** (`SAMAVI_GEN` o `general_expenses` con `es_corporativo = false`) —
   gastos generales de gestionar los pisos. **Se prorratea por días bajo gestión**
   (`v_dias_gestion`), no por ingreso: con los 4 pisos activos todo el mes, 25 % cada uno.
3. **Corporativo** (`es_corporativo = true` o `events.categoria = 'CORPORATIVO'`) — financieros,
   litigio heredado, formación, marketing de crecimiento, viajes de desarrollo de negocio,
   roaming internacional. **No se prorratea**: sale del resultado de Samavi, no del margen de
   ningún piso.

Precedentes ya decididos: móviles, dispositivos a plazos y suscripciones de apps son
**operativos**; los viajes de desarrollo de negocio y el roaming son **corporativos**.

**Trampa de las provisiones con fecha de fin**: una cuota a plazos **no** es gasto recurrente.
Si se carga en `general_expenses` sin `hasta`, el forward asume que se paga para siempre. Ya
pasó dos veces. Verificado hoy: de las 15 líneas de `general_expenses`, dos llevan `hasta`
(Apple Watch hasta 31/12/2026 e iPhone+AirPods hasta 31/10/2027) y tres son corporativas.

**Trampa del cambio de precio futuro**: cuando una promoción vence o una renta sube en una
fecha conocida, se carga en `avisos` para que el forward lo vea. Verificado hoy hay tres:
01/10/2026 (renta de Alexander, −237,95 €/mes), 27/10/2026 (promoción de internet de Marechal,
−10,00 €/mes) y 01/12/2026 (trastero de Nicasio, −33,58 €/mes).

**Ojo con el IVA de las rentas**: por decisión de Stag del 25/07/2026 se modela el **peor
caso** (IVA soportado no deducible), migración 022 — el motor carga `transferencia × 1,21/1,02`.
La consulta a Confisic que decide esto sigue abierta y vale ~6.200 €/año. Si responden que es
deducible, basta poner `listings.renta_iva_pct = 0`. Lo fiscal se deriva al proyecto
**Samavi — Administración & Fiscal**, no se resuelve en este repo.

---

## 3. Recobros a la dueña de Jacobine

### Cuándo aparece

Cada vez que Samavi (o Stag de su bolsillo) paga un arreglo o una compra **del piso de
Sevilla** que le corresponde a la dueña. Jacobine es el único piso en modelo **comisión**: el
piso no es de Samavi, así que sus costes de propietario tampoco.

### Qué son y por qué son neutros

Un recobro es plata que Samavi adelanta y después le descuenta a la dueña en su cuenta
corriente. **Entra y sale**: no es ingreso ni gasto de Samavi, es un movimiento de tesorería.
Por eso la regla dura:

> **Un gasto repercutido a la dueña NUNCA entra a `events` ni al P&L.**

Si entra, aparece dos veces mal: como coste que Samavi no tuvo y, cuando se cobra, como
ingreso que no existe. Precedentes de la migración 049: mini UPS 77 € (feb-2026) y aspiradora
130 € (mar-2026) estaban cargados como coste de Nicasio — el piso equivocado, además.

### Cómo se resuelve, paso a paso

0. **Se captura en el momento**: Stag lo dicta en `/anotar` desde el móvil y cae en
   `notas_inbox` como `SIN_PROCESAR` (migración 087). La nota no imputa nada; se convierte
   en recobro o en event con revisión humana, y queda marcada `REGISTRADA` con lo que salió
   de ella. Si no se captura, no existe: no hay extracto que traiga un bizum personal.
1. **Antes de cargar cualquier gasto de Jacobine**, mirar **`v_recobros`**: si ya está ahí,
   no se duplica. ⚠️ **La hoja `2026_JACOBINE_MADRE_INGRESOS` ya no es fuente**: Stag confirmó
   el 19/08/2026 que hace tiempo que no la actualiza. Los `descuentos` cargados vienen de
   cuando sí se llevaba; de ahí en adelante **el registro es el dashboard**, no la planilla.
2. Si es un adelanto nuevo, se registra en la tabla **`recobros`** (`propiedad_codigo, fecha,
   concepto, importe, pagado_por, pagado_a, medio, estado, liquidacion, resuelto_fecha,
   resuelto_nota, notas`), estado `PENDIENTE`.
2b. **Y se elige carril** (`liquidacion`, migración 089 — decisión de Stag del 19/08/2026):
   · **`CUENTA_DUENA`** si lo pagó Samavi → se le descuenta en su cuenta corriente. El dinero
     salió de la sociedad y vuelve a la sociedad: circuito cerrado.
   · **`DIRECTO_FAMILIA`** si salió del bolsillo de Stag → lo arreglan él y su madre entre
     ellos (efectivo o compensación). **No toca `v_cuenta_duena` ni el P&L.**
   Por qué importa: mezclarlos hacía que Samavi se quedara con dinero que había puesto Stag
   y quedara debiéndoselo. Pasó con los 83,00 de la 077 y él los dio por saldados: 83 €
   perdidos de verdad. **El carril se elige por quién puso la plata, salvo que ya se le haya
   descontado a la dueña de hecho** — que es justamente el caso de esos 83,00, que siguen
   en `CUENTA_DUENA` porque así ocurrió.
3. El recobro pasa a `LIQUIDADO` **cuando se emite la liquidación a la dueña** — no cuando
   alguien lo anota en una planilla, porque esa planilla ya no se lleva. Estados posibles:
   `PENDIENTE`, `LIQUIDADO`, `INCOBRABLE` (este último exige nota).
4. La cuenta devengada de la dueña se lee en `v_cuenta_duena`: pasivo por noche + su parte de
   cancelaciones retenidas − refactura de limpieza (700 €/mes, `listings.refactura_limpieza_mes`)
   − recobros liquidados. **No** resta transferencias hechas: los pagos viven en los bancos.
5. En la UI: `web/components/CuentaDuena.tsx` y `RecobrosCard.tsx`, al final de la ficha de la
   propiedad.

**Estado verificado el 19/08/2026**: **5 recobros PENDIENTES por 220,09 €** (125,00 € pagados
desde la cuenta personal de Stag + 95,09 € desde la de Samavi) y 8 LIQUIDADOS por 3.098,39 €.

### Trampas

- **Lo que se paga por fuera no llega al motor salvo que alguien lo escriba.** Los adelantos
  pagados desde la cuenta **personal** de Stag no aparecen en ningún extracto de Samavi: la
  conciliación mensual no los va a detectar sola. Mismo patrón que los pagos en efectivo
  (§1.4).
- **Y la trampa simétrica: el recobro pagado con tarjeta de Samavi SÍ aparece en el extracto**,
  y ahí parece un gasto corriente. Si se carga como `event`, el P&L se come un coste que Samavi
  no tuvo. Antes de clasificar un cargo de Jacobine, mirar `v_recobros`. Casos vivos: las dos
  compras de Amazon de agosto de 2026 — patas de los muebles de baño 47,98 (14/08) y trona
  47,11 (18/08), migración 086.
- **Riesgo de doble descuento.** Un recobro cuyo concepto en la planilla no coincide con el
  del bizum puede ser el mismo dinero que un descuento ya aplicado. Pasó: dos bizums de
  octubre 2025 (53 + 30 = 83 €) eran el mismo dinero que un descuento de noviembre 2025
  anotado con otro concepto. Se resolvió preguntándole a Stag (migración 077, 11/08/2026).
  **Regla: ante coincidencia exacta de importe con otro concepto, preguntar antes de
  liquidar.**
- **Las resoluciones del Resolution Center de Airbnb son de Samavi, no de la dueña**
  (decisión de Stag del 11/08/2026). Si en `airbnb_tx` aparece una `Resolucion` que toca
  Jacobine, se corrige a mano en el cierre: cobro → recobro a la dueña; devolución → crédito a
  ella. Madrid no necesita nada.
- **Excepciones conscientes existen**: un termo de abril 2026 (258,94 €) lo asumió Samavi sin
  refacturar, confirmado por Stag. Si hay excepción, se anota; no se convierte en regla.
- **La liquidación de la deuda con la dueña es tema fiscal**, no del dashboard: vive en el
  proyecto Samavi — Administración & Fiscal.

---

## 4. Bloqueos de calendario

### Cuándo aparece

Cuando una noche libre aparece como no vendible, o cuando se está por proponer "desbloquear
para vender".

### La regla nueva (14/08/2026)

> **Un bloqueo rotulado "Control" en Guesty es un viaje de inspección de Stag: es
> DELIBERADO, no es un hueco por vender y no se desbloquea jamás.**

Al 14/08/2026 hay dos: **Marechal 22–25/08** y **Jacobine 18–20/08**.

Esto sustituye el criterio anterior. La memoria del proyecto (`bloqueos-calendario-deliberados.md`,
06/08/2026) decía que Stag había decidido **abrir** Marechal el 22–23/08 porque el viaje era
probable pero no seguro y las fechas eran caras. **Manda la regla del 14/08**: los "Control"
no se tocan.

Regla que sí sigue vigente de aquella memoria: un bloqueo deliberado **que no sea "Control"**
puede no ser definitivo, y antes de descontarlo como "sin palanca" conviene decir qué valen
esas noches y si al abrirlas se **fusionan con huecos vecinos** — un hueco de 4 noches vale
mucho más que dos de 2 (ver [`../pricing/PLAYBOOK.md`](../pricing/PLAYBOOK.md)).

### Por qué el motor es ciego a los bloqueos

**Verificado el 14/08/2026, y es más grave de lo que decía la memoria**: los bloqueos no
son invisibles para el motor devengado y solo se ven por una columna de PriceLabs.

1. **`reservations` no los ve.** `guesty-sync` consulta `/v1/reservations` filtrando por
   `lastUpdatedAt`; los bloqueos de calendario de Guesty son otra entidad y **no** entran por
   ahí. Comprobado hoy: no hay ninguna fila de `reservations` que cubra Jacobine 18–20/08 ni
   Marechal 22–25/08. Para el motor esas noches simplemente están libres.
2. **`pricelabs_prices` SÍ los ve — pero por una columna que casi nadie mira.** Las siete
   noches (Jacobine 18, 19 y 20/08; Marechal 22, 23, 24 y 25/08) están con
   **`booking_status = 'Blocked'`**. La trampa es que salen con `reservado = false` **y**
   `no_vendible = false`, así que cualquier consulta que filtre por esos dos campos las cuenta
   como libres. `booking_status` es el único que las delata, y por eso `f_pricelabs_forward`
   las separa bien.

Consecuencia operativa: al listar noches libres hay que excluir **siempre**
`booking_status = 'Blocked'`. Una consulta que solo mire `reservado` y `no_vendible` va a leer
esas noches como **oportunidad perdida** y no lo son. Ojo con el artefacto de borde de la
migración 064: la última fecha del horizonte de cada piso también sale bloqueada y no es un
bloqueo real.

### Trampas

- **No proponer desbloquear sin preguntar.** La conclusión por defecto ante una noche
  bloqueada es "esto es deliberado"; recién después se pregunta.
- **La foto de PriceLabs puede estar desfasada respecto de Guesty.** El sync de PriceLabs
  corre una vez al día (07:10 UTC) y refleja lo que PriceLabs vio, no lo que hay en Guesty
  ahora. Un bloqueo puesto hoy puede tardar hasta un día en aparecer, si es que aparece.
- **Jacobine tiene el calendario CERRADO más allá de ~6 meses, y eso no es un bloqueo
  deliberado: es una ventana de reserva mal configurada.** Verificado el 14/08/2026: 190 noches
  con `booking_status = 'Blocked'`, de las cuales 3 son el "Control" y el resto es una frontera
  que avanza un día por día. Deja Semana Santa y Feria de Abril de 2027 fuera de venta.
  Ver [`../propiedades/JACOBINE.md`](../propiedades/JACOBINE.md) — es el pendiente más caro
  del portfolio.
- **El error que hay que no repetir**: la primera versión de esta sección afirmó que esas
  noches "hoy no están" porque se consultaron las columnas `reservado` y `no_vendible` en vez
  de `booking_status`. La memoria del 06/08 tenía razón. Antes de contradecir a la memoria con
  un "hoy no está", verificar que se está mirando la columna correcta.

---

## 5. Cancelaciones y cobros retenidos

### Cuándo aparece

Cuando un huésped cancela y Airbnb igual paga (política estricta o cancelación tardía), o
cuando un mes no cuadra contra el PDF de Airbnb.

### Cómo lo trata el motor

- **Las canceladas se excluyen del ingreso, SALVO que haya cobro retenido.**
- El cobro retenido entra como **línea de ingreso separada** (`v_ingreso_cancelaciones`) que
  **nunca toca noches, ADR ni ocupación**. Por eso la cascada del cuadre es
  `ingreso = noches + cancelaciones retenidas`: chequeos 4 y 5 de `v_cuadre`, los dos en **ok**
  el 14/08/2026 (canal 103.970,48 € + retenidas = ingreso 105.921,96 €).
- En Jacobine, el importe de la línea ya viene **neto de IVA** (es el 25 % de comisión, no el
  30,25 % facturado) y la vista devuelve el IVA aparte en `iva_cancelaciones`.

**Cobros retenidos verificados el 14/08/2026** (`v_ingreso_cancelaciones`, año 2026):

| Piso | Mes | Ingreso retenido |
|---|---|---:|
| Jacobine | enero | 103,28 € (neto de IVA) |
| Marechal | febrero | 144,66 € |
| Nicasio | marzo | 601,22 € |
| Jacobine | abril | 391,43 € (neto de IVA) |
| Nicasio | agosto | 399,73 € |
| Marechal | agosto | 311,17 € |
| Alexander | septiembre | 163,97 € |

De 752 reservas en la base, **90 están canceladas** (554 confirmadas, 93 inquiries, 9
rechazadas, 3 cerradas, 3 en `reserved`).

La tabla de arriba es el año 2026 **completo**, incluidas las de meses que todavía no
transcurrieron: suma 2.115,46 €. El chequeo YTD de `v_cuadre` llega hasta hoy, y por eso su
diferencia (105.921,96 − 103.970,48 = 1.951,48 €) es exactamente esa suma **menos la de
Alexander de septiembre**. Si la resta no da, el sospechoso es el corte temporal antes que un
error.

### Trampas

- **El PDF mensual de Airbnb nunca va a coincidir con el panel mensual, y está bien.** Dos
  causas conocidas (regla de reconciliación del 24/07/2026, con H1 2026 cerrado al céntimo:
  24 celdas, 103.689,26 €):
  1. **Airbnb atribuye por fecha de PAGO** (~check-in + 1 día); el motor imputa por
     **devengo/noche**. Una reserva con check-in el último día del mes cae en el PDF del mes
     siguiente.
  2. **Airbnb lista las canceladas con cobro retenido** dentro del total; nuestra suma de
     confirmadas las excluye y las lleva a la línea aparte.
- **Herramienta para cerrar el mes contra el PDF**: `v_conciliacion_airbnb` (migración 014,
  interna) devuelve por (codigo, anio, mes) el `payout_confirmado`, el
  `payout_cancelado_retenido` y el `payout_total_airbnb` — este último es el "Total" del PDF.
- **Las reservas en estado `reserved` no entran al motor**: hay 3, y hoy no se muestran en
  ningún lado. Es una decisión pendiente de Stag (item B2 del relevamiento), no un bug.
- **Un reembolso del Resolution Center infla el ADR** sin afectar el ingreso: `bruto` no ve el
  reembolso. Precedente documentado en Jacobine, febrero 2026 (ADR 214,86 € contra 205,72 €
  reales). El ingreso está bien; miente solo el precio de referencia.
- **El export de transacciones de Airbnb no trae las filas de Resolución** de forma completa:
  las resoluciones no se concilian por esa vía, se miran en `airbnb_tx` (tipo `Resolucion`).

---

## 6. Sincronización y frescura del dato

### Cuándo aparece

Cuando `v_freshness` o el chequeo 8 de `v_cuadre` marcan dato viejo, cuando `/precios` muestra
una foto rara, o cuando alguien pregunta "¿esto está actualizado?".

### Los dos syncs

| Sync | Cadencia | Qué escribe | Puerta |
|---|---|---|---|
| `guesty-sync` | cron cada **3 h** (`0 */3 * * *` UTC) | `reservations`, `listings`, `sync_state` | cabecera `x-sync-secret` |
| `pricelabs-sync` | cron **diario 07:10 UTC** | `pricelabs_prices`, `pricelabs_fotos`, `sync_state` | cabecera `x-sync-secret` |

Ambos corren con `service_role` (bypassan RLS) y los dos sacan el secreto de Vault. El horario
de PriceLabs no es casual: PriceLabs refresca sus recomendaciones ~06:00 UTC.

**Estado verificado el 14/08/2026** (`select * from v_freshness`):

- `last_sync` (Guesty) = 14/08/2026 09:00:06 UTC → **0,5 h de antigüedad**, contra un umbral de
  6 h. El chequeo 8 de `v_cuadre` está en **ok**.
- `pricelabs_last_run` = 14/08/2026 07:10:05 UTC, `pricelabs_last_error` = **null**,
  `pricelabs_refreshed` = 14/08/2026 06:57 UTC.
- `costes_cargados_hasta` = 01/12/2026 · `cierre_hasta` = 01/07/2026.

### Qué hacer cuando el dato está viejo

1. **Mirar `sync_state.last_error` y `sync_state.pricelabs_last_error`.** Desde la migración
   069 las funciones no devuelven el error crudo al cliente: el detalle va a `sync_state`, que
   es de donde lo lee `v_freshness`. Si `v_freshness` envejece **sin error visible**, el
   sospechoso nº 1 es un **401**: el cron perdió la cabecera `x-sync-secret` o el secreto de
   Vault cambió. Ese es el modo de falla silencioso del diseño.
2. **Verificar que los jobs de cron existan y lleven la cabecera.** El archivo de referencia es
   `supabase/cron_setup.sql` — **no está en `migrations/` a propósito** (`cron.schedule` no es
   idempotente y la URL lleva el project ref): se ejecuta a mano en el SQL Editor.
3. **Si hay que rehacer la puerta, el ORDEN es obligatorio**: (1) secreto en Vault, (2)
   reprogramar los cron jobs, (3) recién entonces desplegar las funciones. Al revés, el sync se
   rechaza a sí mismo y el dato envejece sin error visible.
4. **No martillar los syncs a mano**: quema la cuota de Guesty/PriceLabs.

### Trampas

- **El cron NO se autentica con `service_role`, sino con la anon key.** Cualquier guard que
  compare contra `SUPABASE_SERVICE_ROLE_KEY` **rompe el cron**.
- **`pricelabs_fotos` es insert-only y no se reconstruye hacia atrás.** Cada día que el cron
  diario no corre es historia de *pace* perdida para siempre. Vigilarlo tiene valor aunque
  nadie mire la pantalla ese día.
- **Dos artefactos de origen de PriceLabs, ya corregidos en la migración 064**: el STLY previo
  a `listings.fecha_inicio` ahora es NULL (PriceLabs manda cadena vacía y parecía "0 % de
  ocupación"), y la última fecha de la ventana llega "unbookable" por artefacto de borde (el
  sync pide un día extra y lo descarta).
- **El dato de PriceLabs es forward y operativo: NUNCA entra al P&L devengado.**
- **El deploy de una Edge Function vía MCP puede rebotar en el WAF de Cloudflare** si el
  archivo es largo; funcionó acortando comentarios.
- **La reconciliación con PriceLabs dio 0 €** y eso es correcto: sus cifras usan alojamiento
  sin limpieza, cuentan bloqueos como ocupados y cortan en hoy. Son diferencias
  definicionales, no errores.

---

## 7. Seguridad al crear objetos SQL nuevos

Esto es un **recordatorio**, no un tratado. La doctrina completa está en el
[`CLAUDE.md`](../../CLAUDE.md) del repo, sección *Seguridad*.

### La checklist, en cuatro líneas

1. **Toda vista o función nueva nace sin permisos y necesita su GRANT explícito** — `to
   authenticated` **SOLO**, nunca `to anon`. Un `to anon` copiado de una migración vieja
   reabre la lectura sin login y **el dashboard no lo delataría** (él ya lee como
   `authenticated`).
2. **Toda `f_` nueva necesita su `revoke execute on function … from public, anon` ANTES del
   grant.** El candado de la migración 061 **no alcanza**: el default cableado de Postgres da
   EXECUTE a `PUBLIC` en cada función nueva y el `pg_default_acl` se **suma** a ese default en
   vez de anularlo. Patrón correcto: migraciones 063 y 064.
3. **Toda `f_` usada dentro de una vista necesita GRANT a `authenticated` aunque sea
   "interna"**: el EXECUTE se comprueba contra el usuario que consulta.
4. **El smoke test de `anon` debe probar el camino `/rpc/`**, no solo `select` sobre las
   vistas. Una función abierta no se delata desde la vista, porque las `f_` son SECURITY
   DEFINER y saltan el RLS.

### Las cicatrices (por qué existe cada regla)

| Migración | Fecha | Qué se cerró |
|---|---|---|
| 008 | — | Fuga de **lectura**: una vista exponía el payout por reserva |
| 056 | 27/07/2026 | Fuga de **escritura**: una vista era auto-actualizable con la anon key (se podía cambiar la renta base o insertar pisos fantasma) |
| 059 | 30/07/2026 | `revoke` de lectura a `anon`: sin login no se lee nada |
| 061 | — | Revocados los default privileges de `postgres` para funciones y secuencias |
| 068 | 04/08/2026 | Las 065/066 omitieron el `revoke … from public, anon` y `anon` podía leer los recobros y la cuenta de la dueña **sin login** |
| 069 | 04/08/2026 | Las dos Edge Functions estaban abiertas a internet |

### Edge Functions: `verify_jwt` NO es una puerta

Lección del 04/08/2026, con **dos ataques reproducidos contra producción**: el gateway solo
valida que el JWT esté bien *firmado*, y la anon key es exactamente eso, publicada en el bundle
del dashboard. `verify_jwt = true` sube el listón de "cualquiera del planeta" a "cualquiera que
abrió el sitio una vez", nada más. La auditoría invocó `guesty-sync` con un curl pelado (200, y
escribió en la base) y `pricelabs-sync` con la anon key descargada del propio sitio.

Desde la 069 las dos exigen la cabecera **`x-sync-secret`**, que el cron saca de Vault y el
handler valida con `f_sync_secret_ok` (security definer, EXECUTE solo para `service_role`)
**antes de tocar nada**.

### PII — inviolable

NIF, IBAN, datos bancarios, nombres de huéspedes y apellidos o datos de contacto de
propietarios **no salen a vistas públicas ni al repo**. En los seeds van como `'PENDIENTE'`: eso
es un placeholder por diseño, no un pendiente.

---

## 8. Trabajo con el usuario

### 8.1 Commits: los hace Claude, el push lo hace Stag

**Regla del 30/07/2026.** Al cerrar un bloque de trabajo, Claude hace `git add` + `git commit`
directamente, con mensaje en español siguiendo el estilo del repo y el trailer
`Co-Authored-By`. A Stag se le dice **únicamente "dale a Sync"**.

**Por qué**: si le da "Commit" en VS Code sin mensaje, se le abre el editor `COMMIT_EDITMSG` y
le pide escribir algo — fricción inútil para un usuario no técnico.

**Por qué el push sigue siendo suyo**: la terminal no tiene credenciales de GitHub y `gh` no
está instalado. Su parte del flujo es Source Control → Sync, y de ahí Vercel despliega solo
(root = `web`).

**Trampa**: las variables `NEXT_PUBLIC_*` se hornean en el build. Si cambian, hace falta
**Redeploy**, no basta con el push.

### 8.2 Migraciones: cómo se aplican

- Van numeradas en `supabase/migrations/`. **La última al 14/08/2026 es la 079**
  (`079_ecocleans_julio.sql`).
- Se aplican con el MCP de Supabase (`apply_migration`, proyecto `enlslwuokresrwbqpyeo`).
- **Si el conector está caído**, se le da a Stag un bloque para pegar en el SQL Editor — y en
  ese caso el bloque **DEBE ser idempotente** (`where not exists` / `on conflict`): ya ejecutó
  uno dos veces.
- `apply_all.sql` y `seed/seed.sql` se mantienen sincronizados con producción (secciones
  "SYNC"): tras cambiar datos o esquema en producción, hay que actualizarlos. Hay deuda
  conocida acá (item E4 del relevamiento: el seed tiene drift fino).
- `supabase/cron_setup.sql` es la excepción: **no** está en `migrations/` a propósito y se
  ejecuta a mano.

### 8.3 Verificar el último eslabón

**Regla de Stag del 03/08/2026**, tras dos fallos seguidos en la misma tarea: *"este tema del
pricing es crucial para mí, sé muy cuidadoso y precavido; hagamos siempre un chequeo de que
esté todo correcto en el momento"*.

1. **Verificar el ÚLTIMO eslabón, no el primero.** La cadena es PriceLabs → Guesty → Airbnb.
   Comprobar el calendario de PriceLabs no prueba nada sobre lo que ve el huésped.
2. **Predecir el número exacto** que Stag debería ver y contrastarlo. Si no coincide al euro,
   hay un problema — no redondear la explicación ni asumir "latencia".
3. **Nunca decir "aplicado" mientras quede un paso fuera de mi control.** Se dice "configurado,
   falta publicar" y se nombra el paso que falta.
4. **Escritura en PriceLabs SOLO con confirmación explícita de Stag**, y verificación inmediata
   después. Stag rechazó poner techo de precio (`max_price`): prefiere que Claude vigile los
   precios y le avise si alguno es irrisorio o excesivo.

La regla nació en pricing pero **se aplica a todo**: un cierre "cargado" que no se verificó
contra `v_cuadre` no está cargado.

### 8.4 Cómo se le habla y qué se deriva

- **Idioma**: español de Argentina, con **voseo**. Stag no es técnico y lee desde el móvil.
- **Doctrina de comunicación** (del prompt CEO): respuesta primero; todo número lleva su
  comparación o consecuencia; cero vanity metrics; el único umbral objetivo es el punto de
  equilibrio (no se inventan targets); todo importe etiquetado como **real** / **ya reservado**
  / **simulado**.
- **Preguntas de precios y números se responden como experto en revenue management**, con
  veredicto y trade-offs en euros, no solo datos (regla del 06/08/2026).
- **Qué se deriva a otro proyecto**: lo fiscal, societario y administrativo va a *Samavi —
  Administración & Fiscal*; las automatizaciones (mail → Drive, IA de huéspedes, N8N) van a
  *Stag Automatizaciones*; la captación de propietarios y el marketing van a *Stag Marketing*
  (ex *Stag Captacion*, renombrado 16/08/2026). **Excepción
  decidida el 06/08/2026**: pricing y revenue management **sí** viven en este repo, porque acá
  están los datos y el MCP de PriceLabs.
- **Convención del usuario**: una conversación = un tema.
- **Regla técnica**: la memoria de Claude se indexa por ruta absoluta → **no mover ni renombrar**
  la carpeta del repo (incluido el espacio final del nombre) sin renombrar también su
  directorio en `~/.claude/projects/`.

---

## 9. Contradicciones detectadas el 14/08/2026

Todo lo de abajo se verificó hoy contra producción o contra el repo. Se deja escrito en vez de
copiar la versión vieja.

| # | La memoria dice | Lo verificado el 14/08 | Cuál manda y por qué |
|---|---|---|---|
| 1 | `bloqueos-calendario-deliberados.md` (06/08): Stag decidió **abrir** Marechal 22–23/08 | El brief operativo del 14/08 dice que Marechal 22–25/08 está bloqueado como "Control" | **La regla del 14/08.** Es posterior y es una regla general, no una decisión de una fecha |
| 2 | Los bloqueos deliberados se ven en `/precios` como "bloqueadas a mano" | Ni `reservations` ni `pricelabs_prices` marcan hoy Jacobine 18–20/08 ni Marechal 22–25/08: `reservado = false`, `no_vendible = false`, y no hay reserva que las cubra | **El dato.** `guesty-sync` solo lee `/v1/reservations`; los bloqueos son otra entidad de Guesty y no entran. Hay que descontarlos a mano |
| 3 | Misma memoria: Jacobine tiene **187 noches bloqueadas** del 31/01/2027 al 05/08/2027 | En ese rango, `pricelabs_prices` no tiene para Jacobine **ninguna** noche `reservado` ni `no_vendible` | **El dato.** Antes de razonar sobre 2027, verificar |
| 4 | El índice `MEMORY.md` dice "5 recobros pendientes / 208 €" | Tabla `recobros`: **3 PENDIENTES / 125,00 €** (y 8 liquidados / 3.098,39 €) *(el 19/08 pasaron a 5 / 220,09 € con la migración 086 — coincidencia de número, importe distinto)* | **El dato**, que coincide con el cuerpo de la memoria de recobros tras la migración 077. El índice quedó viejo |
| 5 | `clasificacion-bancaria-reglas.md` mantiene un ⚠️: "el transporte del día a día no lo cubre nada: ~1.390 € de ene–jun sin cargar" | Hay events `CORPORATIVO` "Transporte (real bancos)" de feb a jul 2026; feb–jun suma **1.389,84 €**, el importe exacto de la advertencia | **El dato.** Se cargó (migración 051 según `auditoria-pisos-pendientes.md`); el ⚠️ es texto residual |
| 6 | `conciliacion-airbnb-tx-vacia.md` abre diciendo que el histórico dic-2025 → jun-2026 "sigue sin cargar" (nota del 10/08) | `airbnb_tx` tiene **464 filas desde el 02/12/2025**; el propio pie de esa memoria lo da por cerrado el 11/08 (migración 078) | **El dato y el pie.** El encabezado de esa memoria es la versión vieja |
| 7 | `supabase/cron_setup.sql` comenta que la `PRICELABS_API_KEY` está "pendiente de Stag" | La key está viva desde el 05/08/2026 y `pricelabs_last_error` es `null` con corrida de hoy | **El dato.** El comentario es obsoleto (item E5 del relevamiento, todavía abierto) |

### Cosas que no se pudieron verificar hoy

- **La ruta de Drive** de extractos y de Ecocleans, y el contenido de las carpetas: no se
  accedió a Drive en esta sesión *(de memoria, sin verificar el 14/08)*.
- **Las tarifas de Ecocleans** (16,40 €/h, 1,80 €/kit, 13,24 €/servicio de renting) salen de la
  lectura de las facturas registrada en la memoria; hoy solo se verificó lo cargado en
  `limpieza_mensual` *(de memoria, sin verificar el 14/08)*.
- **El estado del fix de los chequeos tautológicos** del Apps Script de Ecocleans: vive en el
  proyecto de Cowork, fuera de este repo.
- **Si los bloqueos "Control" existen en Guesty ahora mismo**: no se consultó la API de Guesty
  en esta sesión, solo la base. Lo verificado es que el dashboard no los ve.
