# DIRECTAS.md — Reservas directas a exhuéspedes y conocidos

Creado el 31/08/2026 a pedido de Stag ("tenemos que armar una plantilla para siempre decir en
el mismo tono, establecer el pago y todo lo demás"). Las reglas de precio y la operativa salen
de precedentes ya aplicados; **los términos de pago (§3) son propuesta de Claude del 31/08/2026
— pendiente del OK explícito de Stag**. Cuando lo dé, borrar esta línea.

---

## 1. Cuándo aplica este manual

Exhuéspedes, familia, amigos o colegas que quieren volver a reservar y el canal no los deja
(min-stay, fechas sueltas) o no conviene (comisión). El carril directo **no se publicita**: es
uno a uno, por WhatsApp, con gente conocida. La web (stag-properties.com) sirve solo para que
miren fotos — su buscador comparte el min-stay del calendario y no tiene pasarela de cobro
(historial: 6 intentos por la web, 0 cobrados; verificado 30/08/2026).

## 2. El precio — fórmula de paridad

```
precio_directo = (precio publicado de la noche en PriceLabs + limpieza) × 0,8124
                 redondeado HACIA ARRIBA al múltiplo de 5
```

- 0,8124 = payout de Airbnb medido en nuestras reservas 2026 (comisión host-only 18,76 % —
  15,5 % + IVA — sobre alojamiento + limpieza). El descuento "es la comisión de Airbnb": por
  eso es defendible y por eso **la paridad es el suelo** — cada euro por debajo sale del margen,
  no de la comisión (PLAYBOOK §4.6: en temporada media-alta no se regala).
- **La limpieza ya va descontada adentro de la fórmula.** No descontarla otra vez aparte: es
  doble descuento (cicatriz 31/08/2026: se estuvo a punto de hacerlo con la directa del 31/10).
  Truco comercial válido, mismo total: desglosar como "noche −18 % + limpieza 50 € en vez
  de 60 €" para que el huésped vea dos concesiones.
- El comparador es **el precio que VE el huésped en el canal hoy** (checklist PLAYBOOK §1): si
  la fecha cae en ventana de última hora (≤14 días), el publicado ya lleva −15 % y la paridad
  se calcula sobre eso.
- Refuerzos de venta si el dato del día los respalda (consultar, no recitar): comps de zona
  (`get_listing_neighborhood_market`), demanda/ocupación del mercado, hoteles. Precedente
  31/10/2026: directo = precio de mediana de zona por pisos del cuartil p75–p90, y −8/−21 %
  vs habitación de hotel 4★ del centro.

## 3. Términos de pago — PROPUESTA 31/08/2026 (pendiente de OK de Stag)

**Principio: la fecha se bloquea cuando entra plata, nunca antes.** Cicatriz: GY-6gVkY373
(Alexander 07–09/09/2026, directa F&F, 275 € "a cobrar" — nunca se cobró, se canceló el 29/08
con el calendario tomado dos semanas; ver PLAYBOOK §4.8 y BITACORA 29–30/08).

| Tamaño | Al confirmar | Resto |
|---|---|---|
| ≤2 noches o ≤300 € | **100 % por transferencia** | — |
| 3+ noches o >300 € | **50 % por transferencia (señal)** | a 7 días de la llegada, o en efectivo a la llegada si hay quien reciba |

- El argumento para el huésped (usarlo si chista): **en Airbnb paga el 100 % al reservar** —
  pedirle lo mismo con un 18 % de descuento es mejor trato del que ya acepta. Pedir 30 % sería
  regalar cobertura que ninguna plataforma regala.
- La señal SIEMPRE por transferencia (Revolut Business). El efectivo solo vale para el saldo,
  nunca para bloquear — un "te pago al llegar" pelado es la cicatriz Magnoli otra vez.
- Si el huésped prefiere efectivo (vale también en ≤2 noches): **señal del 50 % por
  transferencia + saldo en efectivo a la llegada**. El principio no se negocia: sin
  transferencia no hay bloqueo.
- **Oferta con validez 48 h.** Sin señal la fecha sigue a la venta; con demanda alta el tiempo
  juega para nosotros (31/10: mercado 6,5 pp adelantado, cierre histórico 96 %).
- Cancelación: **no reembolsable** (es el trato que compra el descuento); se permite UN cambio
  de fecha avisando ≥7 días antes, sujeto a disponibilidad.
- Una noche suelta que se libera por no-show/cancelación directa a corto plazo es casi
  invendible (huecos de 1 noche: 1,4 % de venta) — por eso el 100 % adelantado en estancias
  cortas no es dureza, es el precio del riesgo.

## 4. Plantilla del mensaje (WhatsApp)

Tono: directo, precios finales, todo por escrito, cero relleno. Siete bloques; los que no
tengan dato del día se omiten, no se inventan:

1. **Fechas y horarios** — noche(s) exacta(s), flexibilidad real de entrada/salida.
2. **Precio final desglosado** — total con limpieza incluida, "sin ningún cargo extra".
3. **Descuento explícito** — "te descuento la comisión de Airbnb (18 %)" + precio de canal
   como comparación en euros.
4. **Gancho de demanda** — solo con dato real (festivo, ocupación, "los calendarios se están
   llenando").
5. **Comparador externo** (opcional) — hotel/zona, si refuerza.
6. **Condiciones de pago** — según §3, sin ambigüedad: cuánto, cuándo, adónde.
7. **CTA con validez** — "te mantengo el precio 48 h; con la transferencia te lo dejo
   bloqueado al momento".

### 4.1 La plantilla literal (ajustar tú/vos/ustedes según el huésped; sin PII acá)

> ¡Hola, [nombre]! Les paso los precios para [la noche del sábado DD/MM | las N noches del
> DD–DD/MM] — [flexibilidad de horarios que hayan pedido, p.ej. "la salida a las 6:00 la
> dejamos anotada, sin problema"].
>
> Son **precios finales, con la limpieza incluida** — no hay ningún cargo extra:
>
> 🏠 **[Piso] — [total] €** [(donde se alojaron la última vez)]
> 🏠 **[Piso] — [total] €**
>
> Al reservar directo conmigo **les descuento la comisión de Airbnb, un 18 %**: [esa misma
> noche | esas noches] por la plataforma les costaría[n] [X] € ([piso]) o [Y] € ([piso]).
> [Comparador externo si refuerza: "un hotel 4★ del centro esa noche ronda los X € solo la
> habitación."]
>
> [Gancho de demanda con dato real del día: festivo, finde largo, ocupación.] **Les mantengo
> precio y disponibilidad durante 48 horas** — pasado eso, [la noche vuelve | las noches
> vuelven] a la venta.
>
> Los pisos están en [dirección]; pueden ver las fotos en www.stag-properties.com
>
> Para confirmar y dejarles [la noche bloqueada | las noches bloqueadas]:
> ✅ [≤2 noches: **Transferencia del total** (les paso la cuenta) y les confirmo al momento.
>    | 3+: **Señal del 50 % por transferencia** y el resto [a 7 días de la llegada | en
>    efectivo a la llegada].]
> 💶 [≤2 noches, si prefieren efectivo: **señal del 50 % por transferencia** y el resto en
>    efectivo a la llegada.]
>
> La tarifa es no reembolsable, pero [si les cambia el plan] **les muevo la fecha sin coste**
> avisándome con 7 días. ¡Cualquier duda me dicen! 😊

Primer uso real (directa 31/10/2026, exhuésped de Nicasio): ver BITACORA 30–31/08/2026.
Reglas de la plantilla: nada de ganchos inventados (si no hay dato de demanda, se omite el
bloque); el desglose noche+limpieza se usa solo si el huésped pregunta o regatea (§2).

## 5. Operativa al confirmar (el circuito de siempre)

1. Entra la señal → **reserva manual en Guesty en `confirmed`** (una reserva en `reserved` NO
   devenga — pendiente B2). Eso ocupa la noche en todos los canales; no se bloquea a mano.
2. **Record a payment por cada cobro, con NOTA** de dónde cayó la plata ("Transferencia
   Revolut", "Efectivo — <quién recibió>"…) — COBROS.md §4bis. Cicatriz: dos cobros históricos
   sin nota quedaron ilegibles para siempre.
3. Efectivo → queda registrado en Guesty y va a la cuenta con el socio (carril Confisic,
   CASUISTICAS §1.4.4). Gastos pagados con ese efectivo → `event` negativo por migración.
4. Verificar el último eslabón: la noche ocupada en el multicalendario/Airbnb antes de dar
   nada por hecho (protocolo §5.3).

## 6. Qué NO hacer

- Bloquear la fecha "de palabra", sin plata (Magnoli).
- Bajar de la paridad, o descontar la limpieza dos veces.
- Mandar al huésped a reservar por la web (§1).
- Abrir min-stay 1 al público para esquivar el problema: la directa no lo necesita (la reserva
  manual ignora el min-stay) y en Marechal está prohibido por Stag (PLAYBOOK §4.7).
- Nombres de huéspedes en este repo: nunca (PII).
