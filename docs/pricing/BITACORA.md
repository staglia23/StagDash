# Bitácora de pricing — qué se probó y qué pasó

Registro cronológico, **append-only**: nunca se reescribe una entrada pasada, se añade la
corrección abajo. Cada experimento se cierra con su resultado medido; un experimento sin
resultado medido es una anécdota, no un aprendizaje.

Las reglas que salen de acá suben al [PLAYBOOK](PLAYBOOK.md). El estado vigente vive en
[ESTADO.md](ESTADO.md).

**Formato de entrada**

```
## AAAA-MM-DD · Título
**Hipótesis** · qué creíamos y por qué
**Aplicado** · qué se tocó exactamente (piso, fechas, valores)
**Resultado** · medido, con fecha de medición. "Sin medir" también es un estado válido.
**Aprendizaje** · qué regla nace o se corrige (→ PLAYBOOK §x)
```

---

## 2026-08-02/03 · Primer análisis de mínimos y rebaja de agosto

**Hipótesis** · Agosto tiene demasiadas noches libres; rebajar las noches concretas que quedan
vacías compite contra 0 €, no contra el ADR.
**Aplicado** · Suelos por fecha en las 26 noches libres (MARE 95, ALEX 115, NICA 130, JACO 135)
conservando los overrides porcentuales −15/−20 % que ya tenía puestos Stag; min-stay 3→2 donde
correspondía. Publicado y verificado el 03/08 09:12 UTC.
**Resultado** · El pickup no se midió de forma aislada: dos días después se descubrió que la
configuración estaba mal montada (ver 05/08), así que el experimento quedó **contaminado**.
**Aprendizaje** · (1) Recalcular no es publicar → PLAYBOOK §2.4. Stag detectó que Airbnb seguía
con precios viejos porque veía precio_viejo × promo. (2) Un experimento cuya configuración no se
verificó al último eslabón no se puede leer.

---

## 2026-08-05 · Corrección: el doble descuento y los suelos rebajados

**Hipótesis** · (Descubrimiento, no hipótesis.) Los overrides porcentuales de PriceLabs se suman
al descuento nativo de Airbnb, y además los suelos por fecha del 03/08 estaban **por debajo** del
`min` propio de cada anuncio.
**Aplicado** · Borrados todos los overrides de precio; conservados solo los de `min_stay`.
Precios restaurados: NICA 150–155, JACO 155, ALEX 129, MARE 99.
**Resultado** · Quedó un experimento abierto: "si en 4–5 días el pickup no responde, bajar los
suelos". Se superseded el 07/08 antes de completarse.
**Aprendizaje** · Regla madre del proyecto: **el descuento va en Airbnb, el suelo en PriceLabs**
→ PLAYBOOK §2.1. Y: vender al mínimo el 67–100 % de las noches mientras se le gana al mercado por
20–40 puntos es síntoma de suelo mal calibrado, no de precio alto → §2.5.

---

## 2026-08-06 · Marco de decisión por noche y calibrado quirúrgico

**Hipótesis** · No todas las noches vacías están vacías por lo mismo. Solo hay que bajar donde el
mercado va por detrás de su propio ritmo del año pasado.
**Aplicado** · ALEX 11/08 →119, 12/08 →115, 13/08 →123; MARE 17 y 18/08 →105. El resto sin tocar.
**Resultado** · **El dato que mató la tesis de "bajar para llenar"**: Marechal en percentil 22–30
de precio hace 77 % de ocupación; Nicasio en p70–76 hace 77 % también. Mismo edificio, mismo comp
set, cuartil opuesto → elasticidad ~0 en ese rango. Además las 12 noches libres caían **todas** de
domingo a jueves, ninguna en viernes/sábado: si fuera precio, los findes también estarían vacíos.
**Aprendizaje** · El percentil se calcula sobre el precio que ve el huésped → PLAYBOOK §4.2.
La elasticidad en p22–p76 es ~0 → §4.3.

---

## 2026-08-07 · Test de bajada agresiva (48 h), pedido por Stag

**Hipótesis** · (De Stag) bajar el precio final que ve el huésped hace caer reservas ya.
Objeción registrada: el mercado va por delante del año pasado y la elasticidad medida es ~0.
Se probó igual — es un test legítimo y el coste máximo estimado era ~190 €.
**Aplicado** · Precio final objetivo: MARE 79 € · ALEX 90 € · NICA 119 €, vía precios fijos
93 / 106 / 140 (× 0,85 del descuento nativo). Push de Stag a la 01:49–01:56.
**Resultado (medido 07–09/08)** ·
- NICA vendió 11→14/08 a las 8 h del push, ADR alojamiento 144 €/noche. **⚠️ Esta reserva se
  canceló el 12/08** (ver entrada del 13/08): el resultado que se comunicó como éxito no se
  sostuvo.
- ALEX vendió 09→11/08 a 90,10 €/noche = el precio exacto del test. **Válido.**
- MARE: **cero** reservas de agosto en 48 h estando en percentil ~10 del barrio, mientras vendía
  septiembre (228,60 €/noche) y octubre (184 €/noche) sin ningún descuento.
**Aprendizaje** · (1) La cadencia la marca la perecibilidad, no el ritual → PLAYBOOK §5.2.
(2) Se infirió un −20 % de descuento nativo en Marechal a partir de UNA observación y se publicó
99 € en vez de 93 €; Stag lo corrigió el mismo día → §3.1 y §5.1.
(3) La tesis "el problema de Marechal no es precio" queda **reforzada**, no probada: falta
descartar disponibilidad y visibilidad.

---

## 2026-08-09 · Plan de 5 movimientos (aprobado: "activa todo")

**Hipótesis** · Subir donde no es perecedero, mantener donde sí, y atacar Marechal por
visibilidad en vez de por precio.
**Aplicado** · NICA 14–15 →150 fijo y noche 28 liberada con min-stay 1; MARE 22 →115 y 23–25 →105
(con escalón T−7 a 93); ALEX 11–13 quedan a 106; JACO 11–13 suelo 155→135 (borrando un −20 %
porcentual heredado que el merge había conservado). Monitor diario reconfigurado como guardián
del plan, con los escalones y la regla de plan B.
**Resultado (medido 13/08)** ·
- **JACO 11–13: VENDIÓ** a 109,23 €/noche. Aflojar el suelo funcionó: el año pasado esas noches
  se habían vendido a 107–119 €.
- **NICA finde 14–15: VENDIÓ**, pero a 109,15 €/noche de alojamiento, no a los 150 publicados
  (~127 esperados con el −15 %). **Sin explicar** — hay que revisar si el push llegó, si actuó la
  curva de último minuto de PriceLabs, o si el precio se pisó el 12/08.
- **NICA 28** (la noche huérfana liberada con min-stay 1): **sigue libre** a 13/08.
- **MARE 22–25 y 16–18: cero reservas.**
**Aprendizaje** · Pendiente de cerrar. El plan dejó de estar vigente el 12/08 sin que el sistema
lo detectara (ver entrada siguiente).

---

## 2026-08-12 · Edición manual no registrada (hallazgo, no experimento)

**Hipótesis** · Ninguna: se descubrió el 13/08 al leer el estado real antes de analizar.
**Aplicado** · Alguien (edición manual desde la UI: campo `reason` vacío, `updated_at`
2026-08-12 08:15 UTC) reemplazó el plan del 09/08 en Marechal: 16–18 pasaron de 93 a **84 €**, y
22–25 perdieron el precio fijo quedando con `min_price` 119 + `min_stay` 2 → publican **119 €**.
**Resultado** · Durante 24 h el análisis y el monitor estuvieron razonando sobre un estado que ya
no existía. Ninguna de las dos configuraciones vendió.
**Aprendizaje** · El `reason` es la firma forense → PLAYBOOK §2.6. Y: **nunca afirmar qué está
publicado sin haberlo leído en la misma sesión** → §1.1. El monitor diario debe comparar estado
vivo contra estado intencionado y gritar cuando difieren.

---

## 2026-08-13 · Corrección del resultado del test + diagnóstico de Marechal

**Corrección importante** · La reserva de Nicasio 11–14/08 a 144 €/noche, comunicada el 09/08 como
la prueba de que el test funcionaba, **se canceló el 12/08**. Las noches 11–12 se revendieron a
93,50 €/noche. El balance real del test cambia: de las dos ventas que lo sostenían, solo la de
Alexander (90,10 €/noche) sigue en pie.
→ PLAYBOOK §5.4: una reserva no es dinero hasta pasar su ventana de cancelación.

**Estado de agosto al 13/08** · Libres: NICA 13 y 28 · ALEX 13 · MARE 13, 16, 17, 18, 22, 23, 24,
25, 30 · JACO 13, 18–20 (bloqueo de viaje) y 28.

**Novedad estructural** · Marechal **ya tiene Booking.com conectado** (listing 17046956); no lo
tenía el 09/08. Su ocupación a 30 días subió de 67 % a 80 % (mercado 53 %) y el pickup de los
últimos 15 días es de 4 reservas — pero ninguna de agosto.

**En curso** · Diagnóstico multi-ángulo de Marechal (salud del anuncio, disponibilidad real del
bloque 22–25, histórico propio, mercado). Anomalía a resolver: las noches 22–25 figuran con
`reservado=false` y `no_vendible=false` pero `demanda='Unavailable'`, lo que sugiere que podrían
no ser reservables en el canal — si se confirma, explicaría el cero absoluto sin importar el precio.
