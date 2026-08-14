# Mapa del conocimiento — Samavi

Todo lo que hay que saber para operar el negocio, ordenado por **cuándo se lee**, no por tema.

**La regla que gobierna esta carpeta**: la memoria de Claude es el **índice**; el repo es la
**biblioteca**. En memoria van fichas cortas que dicen dónde mirar y qué es lo urgente; acá van
los documentos largos, versionados en git, que sobreviven a cualquier limpieza de memoria y que
puede leer cualquiera. Si un archivo de memoria pasa de ~40 líneas o empieza a mezclar reglas con
histórico, se parte y su cuerpo se muda acá.

---

## Antes de tocar precios

| Archivo | Qué es |
|---|---|
| [pricing/PLAYBOOK.md](pricing/PLAYBOOK.md) | **Léelo primero.** Reglas permanentes, cada una con la **cicatriz** (fecha e incidente) que la produjo. Incluye el checklist obligatorio de cambio de precio y la guardia diaria (§5.7). |
| [pricing/ESTADO.md](pricing/ESTADO.md) | Cómo leer la verdad en 30 segundos. **No guarda precios a propósito** — los precios se leen, no se recuerdan. Identificadores de cada piso y bloqueos deliberados. |
| [pricing/BITACORA.md](pricing/BITACORA.md) | Append-only: un bloque por experimento con hipótesis, qué se aplicó y **resultado medido**. Un experimento sin resultado medido es una anécdota. |

## Para entender un piso

| Archivo | Modelo | Lo que lo hace distinto |
|---|---|---|
| [propiedades/NICASIO.md](propiedades/NICASIO.md) | titular | El más rentable y el único con colchón amplio. Vende de verdad por Booking.com. |
| [propiedades/ALEXANDER.md](propiedades/ALEXANDER.md) | subarriendo | Contrato que vence el 30/09/2026 con subida automática y adenda pendiente. |
| [propiedades/MARECHAL.md](propiedades/MARECHAL.md) | subarriendo | El más nuevo y el de colchón más fino. Noviembre-2026 es su problema abierto. |
| [propiedades/JACOBINE.md](propiedades/JACOBINE.md) | comisión | Sevilla. Economía distinta: a Samavi le entra el 25 % + IVA, no el margen. |

## Para resolver algo que ya pasó antes

| Archivo | Qué cubre |
|---|---|
| [operativa/CASUISTICAS.md](operativa/CASUISTICAS.md) | Cierre mensual y conciliación, facturas y proveedores, recobros, bloqueos de calendario, cancelaciones, frescura del dato, seguridad al crear objetos SQL, y el ritual de trabajo con Stag. |

## Relevamientos puntuales (foto de un momento, no se mantienen)

- [relevamiento-pendientes-2026-08.md](relevamiento-pendientes-2026-08.md) — ~40 pendientes categorizados (05/08/2026).
- [relevamiento-terminologia-2026-08.md](relevamiento-terminologia-2026-08.md) — 40 términos propuestos, pendientes de que Stag los revise.

---

## Las cuatro, de un vistazo

Datos del motor (`f_breakeven`) para el YTD 01/01 → 14/08/2026. **Estas cifras caducan**: la
consulta que las regenera está en [pricing/ESTADO.md](pricing/ESTADO.md).

| | Nicasio | Alexander | Marechal | Jacobine |
|---|---|---|---|---|
| Modelo | titular | subarriendo | subarriendo | comisión 25 % + IVA |
| Bajo gestión desde | jun-2024 | oct-2025 | dic-2025 | jun-2025 |
| Ciudad | Madrid | Madrid | Madrid | Sevilla |
| Contribución / noche | **153,94 €** | 124,12 € | 106,83 € | 64,66 € |
| Ocupación de equilibrio | 48,8 % | 84,1 % | 83,1 % | 64,0 % |
| Ocupación real | 90,1 % | 90,5 % | 88,5 % | 81,5 % |
| **Colchón** | **+41,35 pp** | +6,39 pp | **+5,37 pp** | +17,47 pp |
| Limpieza: cuesta | 53,72 € | 43,80 € | 43,80 € | — (la paga la dueña) |

**Cómo se lee esta tabla**: los tres de Madrid están en el mismo edificio y venden parecido, pero
su economía no tiene nada que ver. Nicasio aguanta caer 41 puntos de ocupación antes de perder
dinero; **Alexander y Marechal aguantan 6 y 5**. Por eso una bajada de precio que en Nicasio es
táctica, en los otros dos es estructural — y por eso los experimentos de precio arriesgados se
hacen en Nicasio, no en ellos.

---

## Cómo se mantiene esto

1. **Cada regla lleva su cicatriz.** Una regla sin el incidente que la produjo se descarta a la
   primera; con la cicatriz, no. Al añadir una regla al playbook, se cita la fecha y qué pasó.
2. **Cada experimento se cierra.** Se anota en la bitácora al aplicarlo, con la fecha en que se
   mide, y se vuelve a anotar el resultado. Si no se midió, se escribe "sin medir" — es un estado
   válido y honesto.
3. **Los números no se citan de memoria.** Si un dato se puede consultar, se consulta antes de
   afirmarlo. Los documentos que guardan cifras llevan la fecha del dato.
4. **PII nunca entra acá.** Ni NIF, ni IBAN, ni datos bancarios, ni nombres de huéspedes. Este
   repo se sincroniza con GitHub.
