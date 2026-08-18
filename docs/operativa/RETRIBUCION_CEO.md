# Retribución del CEO — qué cobra hoy, qué costaría 3.500 € netos

> Relevamiento del **18/08/2026**, a pedido de Stag ("el sueldo de julio fueron 3.500 € netos y a
> partir de ahora ese va a ser mi sueldo"). Verificado contra extractos bancarios, contra el
> modelo 111 del 2T y contra el motor. **Resuelto**: julio fueron 3.000 (§1) y la subida se aplicó
> desde agosto (§4, migración 082). **Las cifras caducan**: las consultas que las regeneran están
> al pie.

---

## 1. Lo que cobra hoy — verificado, no supuesto

Hasta hoy el `3.333,33 €/mes` de `general_expenses` era una **provisión heredada del Excel**: nunca
se había contrastado contra un movimiento bancario. Ahora sí.

| Concepto | Importe/mes | Dónde se verificó |
|---|---|---|
| Retribución **bruta** | 3.333,33 € | Modelo 111 2T/2026: base trimestral 10.000,00 €, retención 1.000,00 € (10 %) |
| − Retención IRPF (10 %) | −333,33 € | Va a la AEAT, no a Stag. Dentro del cargo de −1.103,53 € del 20/07 |
| = **Neto a la cuenta personal** | **3.000,00 €** | Revolut …7165 → "Retribución administrador": 03/05, 01/06 y **01/07**, los tres de 3.000,00 € |
| + **RETA** (lo paga la sociedad) | 370,75 € | BBVA …8920, cargo TGSS "005 R.E.AUTÓNOMOS": 29/05, 30/06 y 31/07, clavado en 370,75 € |
| **= Coste real para Samavi** | **3.704,08 €** | **44.449 €/año** |

**El modelo estaba bien.** Los 3.333,33 € × 0,90 = 3.000,00 € exactos que salen del banco. La
cadena de saldos de los extractos cierra entre meses, así que la lectura es por partida doble.

> ⚠ **En julio Stag cobró 3.000 €, no 3.500.** No existe ninguna salida de 3.500 € hacia él en
> julio, ni en junio, ni en mayo, en ninguna de las dos cuentas de la sociedad. El único 3.500,00 €
> del período es un **traspaso interno** del 11/06 entre dos cuentas Revolut de la propia Samavi
> (MAD&SEV_SAMAVI → Samavi Invest). Punto ciego honesto: **no hay extracto de la cuenta "Samavi
> Invest" en Drive** y la carpeta BANCOS EXTRACTOS de agosto está vacía — si la subida arrancó en
> agosto, hoy no hay con qué verificarla.

**Regla de método que dejó este relevamiento**: una transferencia bancaria muestra el **neto**;
nunca puede probar el **bruto**. El coste de la sociedad no se lee del extracto — se lee de la
nómina o del 111.

---

## 2. Cuánto cuesta pagarle 3.500 € netos

El bruto necesario depende del **tipo de retención**, y ahí hay un problema previo (§3). Con el
RETA fuera de la nómina (el autónomo societario no tiene cuota obrera), `bruto = neto / (1 − tipo)`:

| Hipótesis de retención | Bruto/mes | Bruto/año | Coste Samavi/año | Δ vs hoy | **Resultado Samavi a 12 meses** |
|---|---|---|---|---|---|
| *(hoy: 3.000 netos, 10 %)* | 3.333,33 € | 40.000 € | 44.449 € | — | **11.996 €** |
| 10 % (el que aplican hoy) | 3.888,89 € | 46.667 € | 51.116 € | +6.667 € | 5.329 € |
| **19 % administrador** (INCN < 100 k) | **4.320,99 €** | **51.852 €** | **56.301 €** | **+11.852 €** | **144 €** |
| 35 % administrador (INCN ≥ 100 k) | 5.384,62 € | 64.615 € | 69.064 € | +24.615 € | −12.620 € |
| Para que le queden 3.500 € **limpios tras la declaración** | 4.531,86 € | 54.382 € | 58.831 € | +14.382 € | −2.387 € |

Esa última columna es el **run-rate de 12 meses**: qué queda si el sueldo nuevo corre el año
entero. En 2026 el golpe es menor porque sólo aplica de agosto a diciembre (§4).

**El número que manda**: el resultado Samavi proyectado para 2026 (año completo, con lo reservado
hoy) era **11.996 €**. Subir el neto de 3.000 a 3.500 con la retención correcta del 19 % cuesta
**11.852 €/año**. O sea:

> **El aumento consume, casi al euro, el beneficio anual entero de la sociedad.**
> El techo teórico —el sueldo que deja el resultado en cero— es un neto de **3.510 €/mes**.
> 3.500 € netos no es "un poco más": es exactamente la línea de flotación.

Y con el 10 % actual, los 3.500 € **no son 3.500 € de verdad**: la retención está tan por debajo
del impuesto real que le saldría a pagar ~4.300 € en la declaración de junio. El neto efectivo
sería ~3.142 €/mes. Para que le queden 3.500 € limpios de verdad hace falta un bruto de
4.531,86 €/mes, y ahí Samavi entra en pérdidas.

### Efecto sobre el punto de equilibrio de cada piso

El sueldo es **el 84 % del pool de overhead** YTD (30.620 € de 36.311 €) y **el 88 % del pool
desde agosto** (4.691,74 de 5.324,84), y el overhead se prorratea por días bajo gestión: cada piso
absorbe un cuarto. Escenario 19 %, a run-rate de año completo (cada piso carga 2.963 €/año más):

| | Nicasio | Alexander | Marechal | Jacobine |
|---|---|---|---|---|
| Ocupación de equilibrio hoy | 41,5 % | 78,1 % | 75,1 % | 61,0 % |
| …con el sueldo a 3.500 | 46,4 % | 84,2 % | 82,1 % | 73,4 % |
| Colchón hoy | +36,05 pp | −0,58 pp | +1,58 pp | +9,99 pp |
| **Colchón con 3.500** | **+31,11 pp** | **−6,68 pp** | **−5,40 pp** | **−2,42 pp** |

**Tres de los cuatro pisos quedarían por debajo de su punto de equilibrio.** Solo Nicasio aguanta.

*Cautela honesta con esta tabla*: es la proyección de **año completo** con las noches reservadas a
día de hoy, así que la ocupación real de sept–dic está subestimada (todavía falta vender). La foto
YTD (a 18/08) es más benévola: ahí los cuatro pisos siguen en positivo y el aumento, aplicado desde
agosto, resta menos de 1 punto a cada colchón. La conclusión de fondo no cambia: **el problema no
es el mes que viene, es el run-rate.**

---

## 3. El problema fiscal que apareció por el camino

Relevar el sueldo destapó tres cosas que valen más que el propio aumento. **Ninguna se resuelve en
este repo**: van al proyecto Admin & Fiscal y a Confisic.

### 3.1 La retención del 10 % no es defendible

El art. **101.2 LIRPF** fija un tipo **fijo** para la retribución de administradores: **35 %**, o
**19 %** si el importe neto de la cifra de negocios del ejercicio anterior es inferior a 100.000 €.
No es un procedimiento de cálculo: no admite ajuste por circunstancias personales. Y si se
sostuviera que es una relación laboral común (procedimiento general de los arts. 82 y ss. RIRPF),
el tipo estándar para 40.000 € brutos, soltero sin hijos, sería **17,94 %** — tampoco 10 %.

Exposición: con 40.000 € brutos, la diferencia entre el 10 % y el 19 % son **3.600 €/año** de
retención no ingresada. **La sociedad responde como retenedora** (art. 99 LIRPF), más intereses de
demora y sanción del 50 al 150 % (art. 191 LGT). Atenuante: si Stag ya autoliquidó su IRPF, la
doctrina del enriquecimiento injusto impide exigir la cuota — pero intereses y sanción siguen.

**El dato que decide 19 % o 35 % es uno solo: el INCN de las cuentas 2025 depositadas.** Ojo —
el INCN contable **no** es la cifra de ingresos del dashboard (el motor registra Jacobine por el
25 % neto de comisión y excluye el IVA repercutido). Hay que mirar la cuenta de pérdidas y
ganancias, no el dashboard.

### 3.2 El RETA que paga la sociedad es retribución en especie

La cuota del RETA es una **obligación personal de Stag**, no de la sociedad. Cuando Samavi la paga,
según criterio de la DGT es **retribución del trabajo en especie** (art. 43.2 y 99.2 LIRPF), con
ingreso a cuenta, y debe declararse en la casilla correspondiente del 111. Deducible en el IS, sí
— pero contabilizada en la 640/641 (retribuciones al personal), **no** en la 642 (Seguridad Social
a cargo de la empresa). Si está en la 642 y no se declara, la AEAT tiene servido el argumento de
liberalidad no deducible (art. 15.e LIS).

Efecto real: que la sociedad pague el RETA equivale exactamente a subirle el sueldo **4.449 €
brutos**. Ni más barato ni más caro — pero hay que declararlo.

### 3.3 La cuota de RETA va a subir sola en 2026

La base mínima del **autónomo societario** sube a **1.424,40 €/mes** en 2026 (verificado). La cuota
actual de 370,75 € corresponde a una base de ~1.180 €, **por debajo del mínimo**. En la
regularización anual la TGSS reclamará la diferencia: **~770–935 € de golpe**, y la cuota pasa a
~435–449 €/mes de forma permanente (~5.200–5.400 €/año). Hay que provisionarlo, no descubrirlo
cuando llegue el cargo.

### 3.4 Otros hilos abiertos (para Confisic, no para acá)

- **Deducibilidad en el IS**: el cargo de administrador es gratuito salvo previsión estatutaria
  (art. 217 LSC). El TS ha desactivado casi todas las armas de la AEAT — **STS 875/2023**
  (rec. 6442/2021) y **STS 546/2025** de 09/05/2025 (rec. 6392/2022, "no cabe aplicar en el ámbito
  fiscal la teoría del vínculo") — pero la deducibilidad no es automática. Conviene mirar qué dicen
  los estatutos.
- **Clave del 190**: declararlo como clave A (rendimientos del trabajo) siendo administrador único
  y socio es un cruce que la AEAT detecta sola. La clave E es la de consejeros y administradores.
- **Residencia fiscal**: jul–nov en Argentina y nov–ene en Brasil supera los 183 días fuera. Las
  ausencias esporádicas **computan como permanencia en España** salvo certificado de residencia
  fiscal del otro país (art. 9.1.a LIRPF), y además el art. 9.1.b (núcleo de intereses económicos)
  es criterio autónomo: la SL, los 4 pisos y toda la renta están en España. **Sigue siendo
  residente español** — y perder la residencia saldría *más caro*, no más barato (IRNR al 24 %
  sobre el íntegro, sin gastos ni mínimo personal, art. 25.1.a TRLIRNR). Lo que hay que hacer es
  documentarlo bien.
- **Vía de salida del dinero**: a igualdad de neto, la nómina gana claramente al dividendo
  (fricción ~29 % vs ~36 %). Y el dividendo puede estar **directamente prohibido** por el art. 273
  LSC mientras haya pérdidas acumuladas sin compensar. La cuenta con el socio no es una alternativa:
  es el indicio más citado en actas de inspección de sociedades unipersonales.

---

## 4. Qué se hizo y qué queda

**Decisión de Stag del 18/08/2026, tomada con esta tabla delante: sí, 3.500 € netos, desde
agosto, con el bruto del escenario 19 %.** Aplicado en la migración `082_sueldo_ceo.sql`:
`Sueldo Stag bruto` queda partido en dos vigencias — 3.333,33 hasta el 31/07 y **4.320,99 desde
el 01/08**. Julio no se tocó.

Efecto medido en el motor tras aplicar:

| | Antes | Después |
|---|---|---|
| Pool de overhead (ago–dic) | 4.337,18 €/mes | **5.324,84 €/mes** |
| Cuota por piso | 1.084,30 €/mes | **1.331,21 €/mes** |
| Resultado Samavi YTD | 11.400,42 € | **10.412,75 €** |
| Resultado Samavi 2026 (año completo) | 11.995,62 € | **7.057,32 €** |
| Colchón Marechal (YTD) | +6,06 pp | **+5,11 pp** |
| Colchón Alexander (YTD) | +6,39 pp | **+5,57 pp** |

En 2026 el golpe es parcial (5 meses). **A run-rate de 12 meses son 11.852 €/año** — el beneficio
anual entero. Es una decisión legítima: el CEO puede decidir que el resultado de la sociedad sea
su sueldo. Pero está tomada sabiendo eso.

**Lo que queda abierto:**

1. **El INCN 2025, a Confisic.** Es el único dato que decide si el bruto correcto es 4.320,99 €
   (retención 19 %) o 5.384,62 € (35 %). Entre uno y otro hay **12.763 €/año** para el mismo neto.
   Si sale 35 %, hay que rehacer la 082 y Samavi entra en pérdidas.
2. **La retención del 10 % sigue mal** hasta que Confisic la corrija (§3.1). El bruto de 4.320,99
   ya asume el 19 %: si el 3T se presenta al 10 %, a Stag le llegarían **3.888,89 € netos** en vez
   de 3.500 y el desfase se lo comería la declaración de junio.
3. **Verificar agosto contra banco** cuando Stag suba el extracto: debe aparecer una salida de
   3.500,00 € con el concepto "Retribución administrador".
4. **Provisionar la subida del RETA** (§3.3) cuando Confisic confirme el importe.

---

## 5. Cómo se toca esto en el sistema

**El sueldo no está cableado en ningún cálculo.** El motor lo lee entero de `general_expenses`
(filas `Sueldo Stag bruto` y `TGSS RETA Stag`), que `f_samavi_gen_mensual` suma filtrando por
`es_corporativo = false` y por vigencia `desde`/`hasta`. No hay constantes en SQL ni en TypeScript:
`web/lib/simulador.ts` recibe el overhead como dato, y los tests de `web/tests/` usan fixtures como
**entrada** con aserciones estructurales — **no hay que tocar ningún test**.

Cambiar el sueldo son dos filas: `update` con `hasta` en la vieja, `insert` con `desde` en la nueva.
Lo que **sí** hay que actualizar después son `supabase/apply_all.sql` y `supabase/seed/seed.sql`
(secciones "SYNC"), más el pool base citado en `prompts/02_Prompt_Dashboard_CEO.md` §5 (hoy
"4.337,18 €/mes desde jun-2026").

### Consultas que regeneran las cifras de este documento

```sql
-- coste-CEO y pool de overhead
select concepto, importe_mes, desde, hasta from general_expenses where not es_corporativo order by importe_mes desc;
select * from f_samavi_gen_mensual('2026-01-01','2026-12-31') order by anio, mes;

-- resultado Samavi: YTD (lo que ve el dashboard) y año completo proyectado
select * from v_resultado_samavi;
with p as (select sum(margen_directo) md from f_pnl_mensual_propiedad('2026-01-01','2026-12-31')),
     g as (select sum(overhead) oh, sum(corporativo) co from f_samavi_gen_mensual('2026-01-01','2026-12-31'))
select round(p.md-g.oh-g.co,2) as resultado_samavi_anio from p, g;

-- punto de equilibrio por piso
select * from v_breakeven_ytd order by codigo;                    -- YTD, lo que ve Stag
select * from f_breakeven('2026-01-01','2026-12-31') order by codigo;  -- año completo proyectado
```
