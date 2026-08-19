# Cómo entra el dinero — canal, forma de cobro y dónde cae

> Relevamiento del **19/08/2026**, a pedido de Stag, antes de construir la torta de cobros en el
> dashboard. Verificado contra `reservations.money_raw` (el objeto `money` de Guesty entero) y
> contra la documentación de la Open API.

---

## 1. Son tres preguntas distintas, no una

La torta que pidió Stag mezclaba «Airbnb» con «efectivo». No son la misma pregunta, y confundirlas
cuenta reservas dos veces. Las dimensiones reales son tres:

| # | Pregunta | Dónde vive hoy | ¿Dato duro? |
|---|---|---|---|
| 1 | **¿De qué canal viene la reserva?** Airbnb / Booking.com / Directa | `reservations.source` | **Sí** |
| 2 | **¿Cómo se cobró?** Pasarela / efectivo / transferencia | `money.payments[].paymentMethodId` | **Sí**, pero sin nombre |
| 3 | **¿Dónde cayó la plata?** Revolut, BBVA, Galicia USD, bolsillo | la **nota** que escribe Stag | No — texto libre |

El caso que lo demuestra: la reserva de Booking `BC-68wENnWVl` (Nicasio, 16/08) es **canal
Booking.com** y **cobro en efectivo** a la vez. En una sola torta se contaría dos veces.

**La tercera es la que más importa para conciliar** y es la única que no tiene campo: un cobro en
efectivo o en una cuenta USD de Argentina **nunca va a aparecer en el extracto español**, así que
el cuadre mensual lo va a marcar como ingreso sin depósito. Hoy eso solo se sabe leyendo la nota.

## 2. Qué dice la API (verificado, no supuesto)

**Sí existe la variable**: cada pago trae `paymentMethodId`, y es un identificador estable. Lo que
**no** existe es un endpoint que lo traduzca a «Cash» o «Transferencia»: la Open API expone
`GET /payment-providers/{id}`, `/payment-providers/default` y `/guests/{id}/payment-methods`
(las tarjetas tokenizadas de un huésped), pero **ningún catálogo de métodos de la cuenta**.

Tampoco viene el nombre dentro de la reserva: el objeto `payment` trae `_id`, `amount`, `paidAt`,
`status`, `note`, `paymentMethodId` y `paymentMethodStatus` — y nada más.

→ **Conclusión: el mapeo ID → nombre hay que hacerlo UNA vez a mano y guardarlo.** A partir de ahí
la clasificación sale de un dato duro y estable, no de adivinar sobre el texto de la nota.

## 3. Los cinco métodos que usás (histórico completo)

| `paymentMethodId` | Pagos | Cobrados | Pend. | Canc. | Cobrado € | Canales | Qué parece ser |
|---|---|---|---|---|---|---|---|
| `58a48a4fea2a13ea9fda5873` | 622 | 621 | — | — | 339.828,88 | solo Airbnb | **Pasarela de Airbnb** (inequívoco) |
| `589894a91d756b9c47ce1e87` | 10 | **0** | 3 | 7 | — | Booking, Directa | **Nunca cobró nada** → cobro *previsto* |
| `58a1931c0000000000000e87` | 9 | 8 | 0 | 1 | **3.682,07** | Booking, Directa | Efectivo **y** Galicia mezclados |
| `5dee4ebd32acdf7051cd6ed6` | 3 | 3 | 0 | 0 | **1.467,48** | Booking, Directa | Revolut **y** Galicia |
| `58a48a4f0000000000000873` | 2 | **0** | 1 | 1 | — | solo Booking | **Nunca cobró nada** → cobro *previsto* |

**Dos hallazgos que cambian el problema:**

1. **Dos de los cinco métodos nunca cobraron un euro.** Los 12 pagos de `589894a9…` y
   `58a48a4f…0873` están todos en `PENDING` o `CANCELLED`. No son formas de cobro: son cobros
   programados que todavía no ocurrieron. En la torta no deben aparecer como categoría.
2. **Fuera de Airbnb solo hay 11 cobros reales, por 5.149,55 €** — repartidos en dos métodos que
   hoy se usan mezclados. Ése es todo el universo a ordenar. Es chico: se arregla de una sentada.

## 4. Lo que hay que sanear en Guesty

**Cobros hechos sin nota** — no hay forma de saber cómo entró la plata:

| Reserva | Piso | Check-in | Importe | Cobrado el | Método |
|---|---|---|---|---|---|
| `GY-ZBqRdqsg` | Marechal | 13/12/2025 | 440,00 € | 06/12/2025 | `58a1931c…e87` |
| `GY-pbc8LdUs` | Alexander | 19/06/2026 | 75,00 € | 10/06/2026 | `58a1931c…e87` |

**Cobros con nota, ya identificados** (no hay que tocarlos, solo re-etiquetarlos con la convención
del §5 si se adopta):

| Reserva | Piso | Check-in | Importe | Nota actual |
|---|---|---|---|---|
| `BC-68wENnWVl` | Nicasio | 16/08/2026 | 1.054,52 € | Cash Claudio |
| `GY-e5VSirJi` | Nicasio | 11/05/2026 | 665,00 € | Pago en efectivo |
| `GY-e5VSirJi` | Nicasio | 11/05/2026 | 285,00 € | 30% reserva banco galicia usd |
| `GY-yPcHaPx6` | Jacobine | 24/07/2026 | 520,00 € | Entregado a Jose en mano |
| `GY-dK3WtDdE` | Marechal | 28/04/2026 | 240,00 € | Entregado a Claudio en efectivo |
| `BC-qpY7JQDO7` | Nicasio | 25/06/2026 | 882,48 € | Revolut Business |
| `GY-xNgBUQwn` | Alexander | 06/10/2026 | 300,00 € | Bco Galicia USD = 400$ |
| `GY-xH7rHap5` | Alexander | 20/10/2026 | 358,25 € | CA USD Galicia |
| `GY-jtnC3pfA` | Marechal | 05/11/2026 | 329,30 € | CC USD Banco Galicia |

**Lo que NO hay que sanear** (verificado, para no perder tiempo):
- **Ninguna reserva ya terminada tiene saldo pendiente.** Cero cobros olvidados.
- Los `PENDING` que aparecen son de reservas **futuras** (29/08, 07/09, 16/11, y una de 07/2027):
  es correcto que no estén cobrados todavía.
- Que las reservas futuras de Airbnb tengan `balanceDue > 0` es normal: Airbnb paga después del
  check-in.

## 5. La convención propuesta

Dos decisiones, y con eso queda cerrado para siempre:

**(a) Nombrar los métodos de Guesty una sola vez.** Stag abre una reserva de ejemplo de cada uno
y dice qué modalidad eligió. Ese mapeo se guarda en el repo y el motor clasifica por `paymentMethodId`
— dato duro. Si además conviene, se separan en Guesty los dos que hoy están mezclados (uno para
efectivo, otro para transferencia).

**(b) Un prefijo fijo en la nota, para la dimensión que no tiene campo: dónde cayó la plata.**

```
DESTINO — detalle libre
```

| Prefijo | Cuándo | ¿Aparece en el extracto español? |
|---|---|---|
| `EFECTIVO` | billetes, los reciba quien los reciba | **No** → cuenta con el socio |
| `GALICIA-USD` | transferencia a la cuenta USD de Argentina | **No** → cuenta con el socio |
| `REVOLUT` | transferencia a Revolut Business | Sí |
| `BBVA` | transferencia al BBVA | Sí |

Ejemplos con las notas de hoy reescritas:
`EFECTIVO — José en mano` · `EFECTIVO — Claudio` · `GALICIA-USD — 400 USD` · `REVOLUT — transferencia`

**Por qué este prefijo y no otro**: la pregunta que el dashboard tiene que poder responder sola no
es «¿fue cash o tarjeta?», es **«¿este ingreso va a aparecer en el banco o no?»**. Eso decide si el
cuadre mensual lo marca como descuadre o lo da por bueno, y si el dinero termina en la cuenta con
el socio. El resto del detalle (quién recibió, cuántos dólares) queda libre después del guion.

## 6. El punto ciego que ninguna convención arregla

Stag: *«a veces tengo pagos fuera de la plataforma que no los registra Guesty»*. Si una reserva no
se crea en Guesty, **no existe** para el motor: no está en el P&L, no está en la ocupación, no está
en el ADR y no está en ninguna torta. No hay forma de detectarla desde acá — por definición, no hay
dato que mirar.

La única regla que lo cubre: **toda reserva se crea en Guesty, siempre**, aunque el cobro sea en
efectivo y aunque sea de un conocido. El cobro se registra con su modalidad y su nota. Es la
diferencia entre un dashboard que cuadra y uno que hay que creerle.

## 7. Consultas útiles

```sql
-- Todo lo cobrado fuera de la pasarela de Airbnb, con su nota
select r.codigo, r.confirmation_code, r.checkin_local, (p->>'amount')::numeric as importe,
       p->>'status' as estado, coalesce(nullif(p->>'note',''),'(SIN NOTA)') as nota,
       p->>'paymentMethodId' as metodo
  from reservations r, jsonb_array_elements(r.money_raw->'payments') p
 where p->>'paymentMethodId' <> '58a48a4fea2a13ea9fda5873'
 order by r.checkin_local;

-- Cobros hechos SIN nota (lo que hay que sanear)
select r.codigo, r.confirmation_code, r.checkin_local, (p->>'amount')::numeric
  from reservations r, jsonb_array_elements(r.money_raw->'payments') p
 where p->>'status'='SUCCEEDED' and coalesce(p->>'note','')=''
   and p->>'paymentMethodId' <> '58a48a4fea2a13ea9fda5873';

-- Reservas ya terminadas con saldo pendiente (hoy: ninguna)
select r.codigo, r.confirmation_code, (r.money_raw->>'balanceDue')::numeric
  from reservations r
 where r.status='confirmed' and r.checkout_local < current_date
   and coalesce((r.money_raw->>'balanceDue')::numeric,0) > 0.01;
```
