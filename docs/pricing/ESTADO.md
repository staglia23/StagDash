# Estado vigente — cómo leerlo, no dónde está escrito

> **Este archivo no contiene precios.** Un "estado actual" escrito a mano se queda viejo y da
> falsa confianza: el 13/08/2026 se analizó Marechal durante horas creyendo que estaba a 93 €
> cuando llevaba un día a 84 €. Los precios se **leen**, no se recuerdan.
>
> Lo único que se guarda acá es (a) cómo leer la verdad en 30 segundos y (b) los datos que **no**
> se pueden leer por API, con su fecha de verificación.

---

## 1. Leer la verdad (hacer esto SIEMPRE antes de opinar sobre precios)

**a) Qué noches están libres, por piso**

```sql
with dias as (select d::date as fecha
              from generate_series(current_date, date '2026-08-31', interval '1 day') d),
     pisos as (select unnest(array['1A_NICA','4B_ALEX','3G_MARE','1A_JACO']) as codigo),
     cal as (select p.codigo, d.fecha from pisos p cross join dias d)
select c.codigo,
       count(*) filter (where r.id is null) as libres,
       array_agg(to_char(c.fecha,'DD') order by c.fecha) filter (where r.id is null) as noches
from cal c
left join reservations r
  on r.codigo = c.codigo and r.status in ('confirmed','reserved')
 and r.checkin_local <= c.fecha and r.checkout_local > c.fecha
group by c.codigo order by c.codigo;
```

**b) Qué precio hay publicado de verdad** (calendario sincronizado desde PriceLabs)

```sql
select codigo, fecha, precio, min_stay, reservado, no_vendible, demanda, stly_adr, refreshed_at
from pricelabs_prices
where codigo = '3G_MARE' and fecha between current_date and current_date + 30
order by fecha;
```

**c) Qué overrides hay puestos y quién los puso**
`get_listing_date_overrides(listing_id, pms="guesty", start_date, end_date)`.
Mirar `reason` (vacío = edición manual desde la UI) y `updated_at`.

**c-bis) Restricciones de check-in/check-out (CTA/CTD)** — desde el 17/08/2026:
en `refresh_listing_pricing` → `pricing_array`, campos `check_in` / `check_out`. String binario
de 7 chars **lunes→domingo, 1 = permitido, 0 = cerrado**. `1111111` = función activa y neutra ·
`-1` = función SIN activar en ese listado (requisito previo, solo se activa por UI).

**d) Si el precio llegó al canal**
`get_listing_data(listing_id)` → comparar `last_date_pushed` con la hora del último cambio.
Si `last_date_pushed` es anterior, **el canal sigue con el precio viejo**.

**e) Frescura general del dato**: `select * from v_freshness;`

**f) Por qué está bloqueada una noche (con su rótulo)** — desde el 15/08/2026 (081):

```sql
select codigo, fecha, tipo, nota from v_bloqueos order by codigo, fecha;
```

(tipo `m` = bloqueo manual de Stag y la nota dice el motivo — convención §4; `bw`/`an` =
bloqueos técnicos de Guesty. Lo refresca guesty-sync cada 3 h.)

**Regla**: si (b) y (c) no cuadran entre sí, parar y averiguar por qué antes de tocar nada.

---

## 2. Identificadores

| Piso | Código base | PriceLabs listing_id | Canales |
|---|---|---|---|
| Nicasio | `1A_NICA` | `684f06ed66e5c60022ef8e05` | Airbnb `707824343240170720` · Booking `15469439` |
| Alexander | `4B_ALEX` | `68de7eea3a04a20013151869` | Airbnb `1489717538166644615` · Booking `15469385` |
| Marechal | `3G_MARE` | `6932ff2750f82e0013dbe977` | Airbnb `1561722374319789678` · Booking `17046956` *(conectado entre el 09 y el 13/08/2026)* |
| Jacobine | `1A_JACO` | `684f06ec655a18002949024a` | Airbnb `1442571300903459334` · Booking `16710783` |

`pms` / `pms_name` = `"guesty"` en todas las llamadas. Supabase project: `enlslwuokresrwbqpyeo`.

---

## 3. Lo que NO se puede leer por API — verificar con Stag antes de usar en un cálculo

Estos datos solo se conocen por captura de pantalla o porque Stag lo confirma. Cada uno lleva la
fecha en que se verificó por última vez. **Si la fecha tiene más de un mes, volver a preguntar.**

| Dato | Valor | Verificado | Cómo |
|---|---|---|---|
| Airbnb — descuento última hora | −15 %, ≤14 días, **los 4 pisos** | 07/08/2026 (Stag corrigió) | captura de Descuentos |
| Airbnb — reserva anticipada | −10 %, ≥3 meses | 07/08/2026 | captura |
| Airbnb — semanal / mensual | −5 % (≥7 n) / −12 % (≥28 n) | 07/08/2026 | captura |
| Airbnb — viajeros con valoraciones excelentes | disponible, **sin activar** | 07/08/2026 | captura |
| PriceLabs — personalizaciones por defecto | ver PLAYBOOK §2.7 | 05/08/2026 | capturas |
| Ventana de la promo anticipada | 3 meses exactos | 07/08/2026 | captura |

⚠️ Solo hay capturas de **Jacobine**. Los descuentos de Nicasio, Alexander y Marechal se asumen
iguales porque Stag lo confirmó de palabra el 07/08 — no están verificados anuncio por anuncio.

---

## 4. Bloqueos deliberados (no son huecos por vender)

**La regla que los identifica**: en el calendario de Guesty, un bloqueo rotulado **"Control"** es
un viaje de inspección de Stag. Es deliberado — no se desbloquea, no se cuenta como noche por
vender y no entra en ningún cálculo de euros recuperables. **Antes de analizar una noche
bloqueada, leer su rótulo en Guesty.**

| Piso | Fechas | Motivo | Fuente |
|---|---|---|---|
| Marechal | **22–25/08/2026** | rotulado "Control": viaje de inspección | Stag, 14/08/2026 |
| Jacobine | **18–20/08/2026** | rotulado "Control": viaje de inspección a Sevilla | Stag, 03 y 14/08/2026 |
| Jacobine | **13–14/11/2026** | personal: casamiento de amigos de Stag — confirmado que son SOLO 2 noches, la del 15/11 va a la venta (rótulo "Personal — casamiento" pendiente de poner en Guesty) | Stag, 15/08/2026 (por chat, ×2) |
| Marechal | noches huérfanas sueltas | PriceLabs bloquea automáticamente los huecos de 1 noche; **Stag decidió mantenerlo solo en Marechal** (09/08/2026) | Stag |
| Nicasio / Alexander | — | min-stay 1 **autorizado** en huecos huérfanos desde el 09/08/2026 | Stag |

---

## 5. Compromisos con fecha

| Cuándo | Qué |
|---|---|
| **01/09/2026 (tarde) — VENCE** | **Botón de exención de comisión de Booking** (`BC-jg7mnkyGW` / nº 5425115874). El 30/08 se marcó la tarjeta del huésped como NO VÁLIDA por indicación de Atención al Cliente; a las 24–48 h aparece en la reserva un botón para reclamar que NO se cobre la comisión (206,64 €) y **hay que apretarlo, no es automático**. Lo hace Stag en la extranet. **Recordatorios automatizados por mail a info@**: `trig_01J1R5d6Cagh7EAfVoRXtekU` (01/09 12:30 UTC, al cumplirse las 48 h) y `trig_01UyEAUZTG9J2pR8WwAs5QDn` (02/09 07:00 UTC, último aviso). Detalle: CASUISTICAS §5.4 punto 2-bis |
| **01/09/2026 05:15 UTC** | Nicasio, bajada táctica del hueco del no-show (BITACORA 31/08), escalón: 02/09 `min_price` 136→**120** (su D−1, suelo duro) y 03/09 150→**140**. **AUTOMATIZADO** → routine `trig_01DwgBps3cRpnwbQTdE48wZT`. Guardas: occupancy + `reservations` (NUNCA `booking_status`, quedó fantasma), check-in del 04/09 vivo, `last_date_pushed` posterior al escalón anterior |
| **02/09/2026 05:15 UTC** | Nicasio, escalón FINAL: 03/09 140→**131** (su D−1; = mediana reservada del comp set). **AUTOMATIZADO** → routine `trig_01DKf85LxxLhspUR1vGXsKTM`. Después no hay más escalones: los overrides caducan con el check-in del 04/09. **Suelos duros: 120 lun–mié, 131 el jueves — no se baja de ahí** |
| **02/09/2026 05:15 UTC** | Hueco Magnoli (objetivo LLENAR, decisión Stag 30/08), escalón 2 (D−5): ALEX 07/09 y 08/09 `min_price` 162/175 → **147/153** (min-stay 2 se reenvía). **AUTOMATIZADO** → routine `trig_01XhA7Bnb22zsjcnJ5ZNCd7A` (relee estado; NO escribe si el hueco ya se vendió o si alguien editó a mano; mail a info@). Publica el sync ~06:50 |
| **04/09/2026 05:15 UTC** | Escalón 3 (D−3): se QUITA el suelo (delete + recreate solo con `min_stay 2`) → manda el mínimo del anuncio 129 (huésped ve 109,65). **AUTOMATIZADO** → routine `trig_01XgJ56kELgbaSp1HZSt78oV` |
| **06/09/2026 05:15 UTC** | Escalón 4 (D−1, último): `min_stay 1` en 07 y 08/09 (autorizado en ALEX desde el 09/08). **AUTOMATIZADO** → routine `trig_01Ugf4RGSXB5BGpG8cJ5w5KJ`. Los overrides caducan con el check-in |
| **09/09/2026** | Medir el caso Magnoli (BITACORA 29/08 + bloque 30/08): vendida o no, escalón, precio, lead, canal. Cerrar la entrada y ajustar PLAYBOOK §4.8 con lo aprendido. Primer dato prospectivo del detector de noches liberadas (plan de automatización guardado en memoria, para ejecutar más adelante) |
| **04/09/2026** | Medir el no-show de Nicasio (BITACORA 30/08 + 31/08): noches 30/08–03/09 vendidas o no, precio, lead, canal y en qué escalón de la bajada. Cerrar las dos entradas y comparar con Magnoli (09/09), que corrió la estrategia inversa. Ojo al separar qué compró qué: el min-stay 1 y la bajada se aplicaron el mismo día |
| **Primera semana de octubre** | Extracto de Booking de septiembre (factura por fecha de SALIDA): `BC-jg7mnkyGW` debe figurar con **comisión 0** (tarjeta declarada no válida + exención reclamada el 01/09). Si aparece la comisión igual, disputar por el Inbox con el registro de las llamadas del 30/08. De paso, cargar como events las dos comisiones de agosto (216,92 + 250,03) |
| Sin fecha (poco probable) | Cobro del no-show: **607,76 €** (50 % no reembolsable). Con la tarjeta declarada no válida Booking ya no lo intenta; solo queda que la huésped transfiera por el mail que le mandó Stag el 30/08. Si entrara: cobro retenido de Nicasio (línea aparte, no toca noches) + comisión de Booking sobre él como event |
| 01/09/2026 | Recalcular foto forward y decidir promos de Airbnb vivas antes de octubre |
| 01/10/2026 | Subida estructural de mínimos vía Custom Seasonal Profile (PLAYBOOK §6). **No antes.** |
| A las 2 semanas de aplicarla | Revisar y, si el pickup no responde, apagar el perfil |
| **21/09/2026 07:00 UTC** | Escalón 2 del min-stay "semana despedida": 7→**3** (NICA 4→3) en llegadas 7–15/11 (JACO 8–15/11). ⚠️ En el 15/11 REENVIAR los 3 campos CICO o se pierde el cierre de llegadas. **AUTOMATIZADO** → routine `trig_013aGy9oHDKkwSaB4h5UVyFp` (agente en la nube; avisa por mail a info@). Si se desprograma, hacerlo a mano |
| **25/10/2026 08:00 UTC** | Escalón 3 (último): min-stay **2** en la misma ventana, misma advertencia del 15/11. **AUTOMATIZADO** → routine `trig_01EdEUADEk3iFTs6gN7JMwe4`. Cierra el experimento en la bitácora |
| 01/10/2026 | Decisión larga distancia JACO (criterio 20/08: ≥1 reserva/semana con lead >176 d Y calendario ≥6 % sobre 2026 → evaluar subir Fechas Lejanas; si no, NO tocar) + expediente Early bird Madrid (~7.000 €/año simulado, mal medido) + verificar que la subida 155→170 no pisa los suelos 2027 |
| 25/10/2026 | (además del escalón min-stay) T−180 del 20–22/04/2027: verificar que el Precio Mínimo de Seguridad los soltó (hoy los clava a 544/544/698 por STLY de Feria 2026 desalineado) |
| 13/12/2026 | Karol G T−180: revisar pickup del 10–13/06/2027 (suelos 430/850, inertes). NO bajar todavía |
| 12/01/2027 | Feria T−90: pickup del 12–18/04 contra suelos; si el frente 12–15 quedó atascado por una venta de finde, cascada de min-stay en 12–14 |
| 09/02/2027 | Pre-Feria: guardas 400/390 del 09–10/04 — retirar si siguen sin vender |
| 11/03/2027 | Karol G T−90: si cero pickup, bajar suelos a 700 (11–13/06) y 380 (10/06) |
| Pendiente sin fecha | Único eslabón sin verificar de los cierres del 17/08: probar en **Airbnb** como huésped que rebota una llegada el 06/11 y una salida el 19/01 (PriceLabs y Guesty ya verificados) |
