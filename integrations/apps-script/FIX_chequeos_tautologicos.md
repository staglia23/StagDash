# Fix: los chequeos de la conciliación no pueden fallar

**Dónde**: `Ecocleans_Auto.js`, función `verificarMatematicaFactura_`.
**Impacto**: no afecta a lo que se paga (el importe siempre sale del PDF de la factura), sí al
desglose por propiedad, que es el dato que consume el motor.

## El problema

Las versiones v3.10 y v3.13 resolvieron discrepancias reales **sustituyendo la suma de filas por
el total del resumen**. Eso está bien para calcular, pero como efecto colateral deja el chequeo
comparándose consigo mismo:

```js
var kitsTotalResumen = parseFloat(totalesFactura.kits_eur) || 0;
var kitsCalculado    = kitsTotalResumen > 0 ? kitsTotalResumen : sumaKitsFilas;
// ...
kitsCuadra: Math.abs(kitsCalculado - (totalesFactura.kits_eur || 0)) <= TOLERANCIA
```

Cuando el resumen trae total de kits —o sea siempre—, `kitsCalculado` **es**
`totalesFactura.kits_eur`. La resta da 0. **El chequeo no puede fallar nunca.**

Lo mismo en renting:

```js
var rentingCalculado = sumaRentingFilas;
if (rentingResumenPDF > 0 && Math.abs(rentingResumenPDF - sumaRentingFilas) > 0.05) {
  rentingCalculado = rentingResumenPDF;      // ← justo cuando NO cuadra, lo pisa
}
// ...
rentingCuadra: Math.abs(rentingCalculado - (totalesFactura.renting_eur || 0)) <= TOLERANCIA
```

El chequeo pasa a ser tautológico **exactamente cuando hay discrepancia**. El aviso queda en el
log y la hoja muestra ✅.

## Qué se escapó por esto

**Mayo 2026** — la hoja se comió una fila entera (`SEGOVIA 8 4B, 10-may, CD 2, 0:00 h,
renting 20,24 €, kit 1,80 €`). Resultado: 24 servicios en vez de 25 y renting 309,36 € en vez de
329,60 €. Y la hoja muestra:

> ✅ Kits 45,00 € = 24 × 1,8 €

que es falso: 24 × 1,80 = 43,20 €. El ✅ salió porque comparó 45,00 contra 45,00.

## El fix

Comparar contra **la suma de filas**, que es la lectura independiente, no contra el sustituto.
Mantener el cálculo como está (el resumen sigue mandando para el importe); cambiar solo el
criterio del ✅.

```js
// Kits: la lectura fila-a-fila contra el total de la factura.
// Si no hay filas leídas no se afirma nada (no es lo mismo "cuadra" que "no pude comprobar").
kitsCuadra: sumaKitsFilas === 0
  ? null
  : Math.abs(sumaKitsFilas - kitsTotalResumen) <= TOLERANCIA,

// Renting: idem. rentingCalculado sigue usándose para calcular; el chequeo mira la suma cruda.
rentingCuadra: sumaRentingFilas === 0
  ? null
  : Math.abs(sumaRentingFilas - (totalesFactura.renting_eur || 0)) <= TOLERANCIA,
```

Y en `poblarDashboard_`, que `null` se pinte distinto de `true`/`false`:

```js
v.kitsCuadra === null ? '➖ sin datos' : (v.kitsCuadra ? '✅' : '⚠️')
```

Con esto, mayo habría saltado: 24 × 1,80 = 43,20 ≠ 45,00 → ⚠️.

## Un chequeo más que vale la pena

El desglose por propiedad no se verifica contra nada. Marzo lo demostró: la hoja asignó el
servicio SUR del 17-mar a Alexander cuando el resumen de Ecocleans dice `SEGOVIA 8, 3G`
(Marechal). El total de 25 servicios cuadraba por compensación, pero el reparto por piso estaba
mal — y el reparto es justo el dato que el dashboard necesita.

```js
// La suma por propiedad tiene que reconstruir las tres líneas de la factura.
var sumaHoras   = props.reduce(function (a, p) { return a + p.horas; }, 0);
var sumaRenting = props.reduce(function (a, p) { return a + p.renting; }, 0);
var sumaServ    = props.reduce(function (a, p) { return a + p.servicios; }, 0);

var repartoCuadra =
  Math.abs(sumaHoras   - horasResumen)             <= TOLERANCIA &&
  Math.abs(sumaRenting - totalesFactura.renting_eur) <= TOLERANCIA &&
  Math.abs(sumaServ * TARIFAS.kitCocina - kitsTotalResumen) <= TOLERANCIA;
```

Ojo con las horas: los servicios **SUR no facturan horas** (sí renting y kit). En marzo, la tabla
suma 41,17 h en 25 servicios pero la factura cobra 38,17 h — la diferencia son exactamente los
dos SUR de 1:30. Si el chequeo no descuenta los SUR, va a dar falso positivo todos los meses que
haya uno.

## Aparte: rotar los secrets de Guesty

`Ecocleans_Auto.js` y `Organizar_Ecocleans_Drive.js` traen el `GUESTY_CLIENT_SECRET` hardcodeado
(dos valores distintos). Cualquiera que reciba una copia del script tiene acceso a la API de
Guesty. Conviene rotarlos en Guesty y moverlos a Propiedades del script, igual que el token de
Supabase de `limpieza_supabase.gs`.
