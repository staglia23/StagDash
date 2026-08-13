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

**d) Si el precio llegó al canal**
`get_listing_data(listing_id)` → comparar `last_date_pushed` con la hora del último cambio.
Si `last_date_pushed` es anterior, **el canal sigue con el precio viejo**.

**e) Frescura general del dato**: `select * from v_freshness;`

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

| Piso | Fechas | Motivo | Fuente |
|---|---|---|---|
| Jacobine | 18–20/08/2026 | viaje de control de Stag a Sevilla | Stag, 03/08/2026 |
| Marechal | noches huérfanas sueltas | PriceLabs bloquea automáticamente los huecos de 1 noche; **Stag decidió mantenerlo solo en Marechal** (09/08/2026) | Stag |
| Nicasio / Alexander | — | min-stay 1 **autorizado** en huecos huérfanos desde el 09/08/2026 | Stag |

---

## 5. Compromisos con fecha

| Cuándo | Qué |
|---|---|
| 01/09/2026 | Recalcular foto forward y decidir promos de Airbnb vivas antes de octubre |
| 01/10/2026 | Subida estructural de mínimos vía Custom Seasonal Profile (PLAYBOOK §6). **No antes.** |
| A las 2 semanas de aplicarla | Revisar y, si el pickup no responde, apagar el perfil |
