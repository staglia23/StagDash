# Relevamiento de terminología del dashboard — 05/08/2026

Barrido de las 4 zonas del dashboard (portada, ficha, simulador/cuadre, tira de 30 días)
buscando texto que un CEO no técnico no entiende a la primera. Lo pidió Stag el 05/08:
«buscá en todo el dashboard palabras que sean más simples de reconocer y entender, más
propias de finanzas».

**ESTADO: PROPUESTO, NO APLICADO.** Stag lo revisa y decide qué entra.

40 términos consolidados, ordenados por prioridad. Los 6 primeros son los que él
señaló explícitamente como confusos.

---

## 1. Margen neto YTD (KPI) / "Margen neto 25.005 € (25,8 %)" (titular)

- **Gravedad:** alta
- **Dónde:** web/app/page.tsx:138 (primer KPI de la portada) y web/lib/headline.ts:107 (titular, caso 3 de la cascada). El mismo número es la fila "Resultado Samavi" de web/components/YtdPropiedadTable.tsx:78.
- **Qué significa de verdad:** El resultado final de Samavi: margen operativo de los 4 pisos MENOS los gastos de la sociedad (verificado en 025_estructura_tres_capas.sql, v_kpis: sum(margen_neto) − corporativos). Antes de impuestos.
- **Por qué confunde:** "Margen neto" nombra TRES capas distintas en la misma pantalla: este KPI (tras gastos de la sociedad), la columna "Operativo" de la tabla (antes de ellos) y el bloque "Margen neto asegurado" (también antes). Imposible ordenarlas sin conocer el motor. Es la raíz de la confusión que reportó Stag.
- **Propuesta:** "Resultado 2026" (14 caracteres, entra igual que hoy). Titular: "Resultado 25.005 € (25,8 % del ingreso) — las 4 cubren su punto de equilibrio" (78 chars, dentro del límite de 90; el "(25,8 %)" a secas no decía porcentaje de qué). La fila de la tabla sigue "Resultado Samavi": mismo nombre para el mismo número.

## 2. Margen neto asegurado · hasta diciembre

- **Gravedad:** alta
- **Dónde:** web/app/page.tsx:286 (título de sección) y web/components/AseguradoTable.tsx:48-49 (caption accesible "Margen neto ya asegurado…").
- **Qué significa de verdad:** Mes a mes hasta diciembre, con las reservas YA confirmadas: lo que queda de cada piso tras sus gastos propios Y su parte de la estructura. NO descuenta los gastos de la sociedad (verificado en 025, v_margen_asegurado: resta gastos directos + cuota de overhead no corporativo, nada más). Es un mínimo que sube con cada reserva, no un pronóstico.
- **Por qué confunde:** Es el bloque que Stag señaló: (1) este "margen neto" NO es el del KPI de arriba; (2) "asegurado" suena a garantizado y puede bajar por cancelación; (3) no dice que sale de lo ya reservado.
- **Propuesta:** "Ya reservado · lo que queda cada mes" (36 chars, entra en una línea a 390 px; con "hasta diciembre" parte en dos, aceptable). "Ya reservado" es la etiqueta que la propia doctrina del prompt CEO manda usar, y "lo que queda" ata con la columna "Queda" de la tabla de abajo: misma capa, una hacia adelante y otra hacia atrás.

## 3. por aporte | por ingreso (botones del toggle)

- **Gravedad:** alta
- **Dónde:** web/app/page.tsx:288-289, dentro del título del bloque asegurado. Verificado: solo reordena filas y ordena LAS DOS tablas a la vez (page.tsx:212-227, rowsYtd comparte orden con construirTabla).
- **Qué significa de verdad:** No cambia ningún número: solo el orden de las filas de la tabla asegurado Y de la tabla "Por propiedad". "aporte" = contribución (ingreso − gastos directos del piso); "ingreso" = ingreso de Samavi.
- **Por qué confunde:** Parece un interruptor que cambia lo que se mide (¿veo aporte o veo ingreso?) cuando solo reordena. "Aporte" no dice aporte a qué, y no se ve que también mueve la tabla de abajo.
- **Propuesta:** Etiqueta "Ordenar por:" + botones "lo que deja" / "lo que entra", en su propia línea debajo del título (junto al título no entra a 390 px). Coherente con las columnas nuevas "Deja" e "Ingreso".

## 4. Es lo ya reservado: un piso que sube con cada reserva. / verde = el mes cubre sus costes · gris ↗ = todavía no vendió ni su ocupación de equilibrio, así que sube solo · rojo = ya la superó y aun así pierde.

- **Gravedad:** alta
- **Dónde:** web/components/AseguradoTable.tsx:99 y 105-107 (leyenda bajo la tabla) + los tooltips de celda en AseguradoTable.tsx:30-34, que usan las mismas construcciones.
- **Qué significa de verdad:** La cifra es un mínimo que solo sube con cada reserva nueva. Verde: el mes ya paga sus gastos con lo reservado. Gris ↗: mes a medio vender, el negativo mejora solo. Rojo: ya vendió las noches que necesitaba y aun así pierde (lib/asegurado.ts:35-43) — lo único preocupante de verdad.
- **Por qué confunde:** En este producto "piso" = apartamento: "un piso que sube" se lee literal, la peor colisión de vocabulario de la portada, justo en la frase que debía explicar el bloque que Stag no entiende. Y "no vendió ni su ocupación de equilibrio" / "ya la superó" son construcciones retorcidas con antecedentes perdidos.
- **Propuesta:** "Es lo que ya está reservado: un mínimo que sube con cada reserva nueva y solo baja si se cancela una. verde = con lo reservado, el mes ya paga todos sus gastos · gris ↗ = mes a medio vender: aún no llegó a las noches que necesita para cubrirlos, la cifra sube con cada reserva · rojo = ya vendió las noches que necesitaba y aun así pierde: esto sí hay que mirarlo." (evitar "piso" y "suelo" como metáfora en todo el dashboard). Tooltips con la misma redacción.

## 5. … 1 en negativo con la ocupación ya superada.

- **Gravedad:** media
- **Dónde:** web/lib/asegurado.ts:125 (función resumenAsegurado, frase bajo la tabla del bloque ya-reservado). Actualizar también su test en web/tests/.
- **Qué significa de verdad:** Meses que ya vendieron más noches de las que necesitaban para cubrir gastos y aun así pierden: los únicos realmente graves.
- **Por qué confunde:** "En negativo con la ocupación ya superada" no tiene sujeto: ¿superada por quién, respecto de qué? Es el caso más grave de los tres y el peor redactado. Los otros dos tramos de la frase están bien.
- **Propuesta:** "1 en pérdida aunque ya vendió las noches que necesitaba".

## 6. Aporte / Operativo (cabeceras de la tabla Por propiedad)

- **Gravedad:** alta
- **Dónde:** web/components/YtdPropiedadTable.tsx:45 y 46 (cabeceras) y 37-40 (caption 'contribución ("aporte") y margen operativo').
- **Qué significa de verdad:** Aporte = contribución: ingreso − gastos directos del piso (renta, limpieza, suministros, comunidad, otros). Operativo = eso menos su parte de la estructura. Verificado en 025 (v_ranking: contribucion = margen_directo; margen_neto resta la cuota de overhead).
- **Por qué confunde:** "Aporte" no dice aporte a qué; "Operativo" es jerga contable y convive con dos "margen neto" distintos en la misma pantalla. Nadie no técnico ordena esa cascada.
- **Propuesta:** "Deja" (4 chars) y "Queda" (5 chars) — entran mejor que hoy — + una leyenda bajo la tabla que cierra todo el sistema: "Ingreso = lo que cobra Samavi tras la comisión del canal · Deja = lo que sobra tras los gastos propios del piso · Queda = tras su parte de la estructura (tu sueldo, gestoría, software) · Resultado Samavi = antes de impuestos". La leyenda absorbe también el aviso "antes de impuestos" que faltaba en la portada.

## 7. Overhead / cuota de overhead / overhead común / sin overhead

- **Gravedad:** alta
- **Dónde:** web/app/p/[id]/page.tsx:223 (titular "antes del overhead común"), 301 ("· sin overhead"), 313-315 ("sin la cuota de overhead"), 330-331 (sub del KPI "Contribución antes del overhead común"), 332-333 (KPI "Cuota de overhead"), 353-358 (nota de las mini-barras), 375-377 (cabecera de Detalle mensual); web/components/RankingTable.tsx:44; web/components/CostesTable.tsx:34; web/lib/waterfall.ts:69 (escalón); web/components/DelMargenALaCaja.tsx:28 ("Overhead de gestión").
- **Qué significa de verdad:** Los gastos generales de gestionar los pisos —sueldo de Stag, gestoría, software— repartidos entre los 4 por días bajo gestión (con los 4 activos, un cuarto cada uno). Es el mayor coste del negocio.
- **Por qué confunde:** Palabra inglesa para el mayor coste del negocio, sin decir nunca qué gastos son ni por qué le tocan a ese piso. Un relevador propuso "gastos comunes", pero en España colisiona con la comunidad de propietarios (que es un gasto directo de estos mismos pisos): descartado.
- **Propuesta:** "Estructura" en cabeceras de tabla y escalón del gráfico (mismo ancho); "gastos de estructura (tu sueldo, gestoría, software)" en texto corrido; KPI de la ficha: "Su parte de la estructura" con sub "Tu sueldo, gestoría y software repartidos por días de gestión". OBLIGATORIO aplicarlo en el mismo commit que el renombre de la fila "Estructura" de la portada (siguiente hallazgo): si no, convivirían dos "Estructura" con significados distintos.

## 8. Estructura [no asignable] / Costes corporativos [no asignables]

- **Gravedad:** alta
- **Dónde:** web/components/YtdPropiedadTable.tsx:70-72 (penúltima fila de la tabla de portada) y web/components/DelMargenALaCaja.tsx:38 (/analisis).
- **Qué significa de verdad:** Gastos de la sociedad que NO son de gestionar pisos y no se reparten: intereses y notaría del préstamo, el litigio heredado (BLT Law), formación, marketing de crecimiento (verificado en 025 y en la nota de DelMargenALaCaja:61-64, que ya lo explica bien).
- **Por qué confunde:** "Estructura" y "no asignable" son contabilidad analítica: suena a gasto de oficina y son intereses, hipoteca y abogados. Y se confunde con el overhead, que SÍ está repartido en la columna de al lado. Además el nombre "Estructura" lo necesita el overhead (hallazgo anterior).
- **Propuesta:** "Gastos de la sociedad" + etiqueta "no son de los pisos" (versión corta si la fila no entra: "Gastos sociedad"). En DelMargenALaCaja: "Gastos de la sociedad [no son de ningún piso]". Mismo commit que el renombre de Overhead→Estructura.

## 9. Margen neto | Margen directo (toggle de la ficha; en /analisis "neto" | "directo") + la nota que los explica

- **Gravedad:** alta
- **Dónde:** web/app/p/[id]/page.tsx:252-259 (toggle), 221-226 (titular "Deja X € de margen neto YTD"), 330-331 (KPI "Margen directo YTD"), 348-350 (título "Margen directo/neto por mes"), 353-358 (nota: "contribución antes del overhead común… la cuota del overhead común…"); web/app/analisis/page.tsx:72-77 y 81 (toggle y TrendChart); web/lib/waterfall.ts:67 y 70 (escalones "Margen directo"/"Margen neto"); web/app/p/[id]/page.tsx:375-377 (cabeceras del Detalle mensual).
- **Qué significa de verdad:** Directo = solo con los gastos propios del piso. Neto = además su parte de la estructura. Es el interruptor que decide si Alexander "deja 2.292 €" o "9.988 €".
- **Por qué confunde:** Ninguna de las dos palabras dice qué cambia; "directo" suena a "el de verdad" siendo el más generoso. Y la nota que debía explicarlo usa las tres palabras que hay que explicar (contribución, overhead, cuota).
- **Propuesta:** Texto fijo "Margen" + botones "sin estructura" / "con estructura" (14 chars c/u, entran a 390 px). Nota: "Sin estructura = lo que deja el piso con sus propios gastos. Si lo soltás, los gastos de estructura no desaparecen: se reparten entre los otros tres. / Con estructura = ya le descontamos su parte (tu sueldo, gestoría, software), repartida por días de gestión: con los 4 activos, un cuarto cada uno." Titular ficha: "Queda(n) X € este año después de estructura (Y % del ingreso)" / directo: "antes de estructura". KPI: "Margen antes de estructura · 2026". Cabeceras de tablas anchas (Ranking, Detalle mensual): "Margen sin estructura" | "Estructura" | "Margen con estructura" — la columna del medio hace legible el par; esas tablas ya scrollean. Escalones del waterfall: "Sin estructura" / "Con estructura".

## 10. Vital signs · YTD 2026

- **Gravedad:** alta
- **Dónde:** web/app/page.tsx:264 (título de la tira de KPIs de la portada).
- **Qué significa de verdad:** Los 4 números clave del año en curso: resultado, ingreso, ocupación, precio medio por noche.
- **Por qué confunde:** Inglés + jerga médica de dashboards, y "YTD" encima. No dice nada de lo que hay debajo.
- **Propuesta:** "Cómo va el año · 2026 hasta hoy" (31 chars, entra en una línea).

## 11. YTD (en todas sus apariciones)

- **Gravedad:** alta
- **Dónde:** web/app/page.tsx:138, 143, 149, 154 (etiquetas de KPI), 264 y 296 (títulos); web/app/p/[id]/page.tsx:212, 223, 301, 321, 324, 330, 336, 397, 406; web/app/analisis/page.tsx:63, 89.
- **Qué significa de verdad:** Year To Date: del 1 de enero a hoy (y en este motor, siempre el año en curso — migración 060).
- **Por qué confunde:** Sigla inglesa que aparece más de 15 veces entre portada, ficha y análisis. Sin ella no se distingue lo que mira hacia atrás de lo que mira hacia adelante. A diferencia de ADR/RevPAR (idioma del sector, sin sinónimo corto), YTD es un atajo de escritorio con equivalente castellano exacto.
- **Propuesta:** "2026 hasta hoy" en títulos de sección ("Por propiedad · 2026 hasta hoy", "Punto de equilibrio · 2026 hasta hoy") y solo "· 2026" en etiquetas de KPI, donde manda el ancho ("Ingreso Samavi · 2026").

## 12. Quedan 48 días para avisar a Alexander — hoy consume el 94,5 % de lo que ingresa

- **Gravedad:** alta
- **Dónde:** web/lib/headline.ts:48 (VERBO_POR_TIPO: contrato → "avisar a") y 64-67 (armado del titular, caso 1). Actualizar el test de headline.
- **Qué significa de verdad:** Quedan 48 días para comunicar al casero que no se prorroga el contrato del piso Alexander (si no, renueva 12 meses).
- **Por qué confunde:** Los pisos llevan nombre de persona: "avisar a Alexander" se lee como avisar a un señor. Es el titular del caso de uso más importante del dashboard con la gramática apuntando al lado equivocado.
- **Propuesta:** VERBO_POR_TIPO contrato → "decidir el contrato de". La frase larga con la causa completa pasa de 90 chars y cae sola a la compacta: "Quedan 48 días para decidir el contrato de Alexander — consume el 94,5 % del ingreso" (85 chars, dentro del límite).

## 13. 13 libres · RevPAR 128 € / eq. 140 € (portada) y "RevPAR 30d vs eq." (tarjetas)

- **Gravedad:** alta
- **Dónde:** web/components/SaludFila.tsx:29-33 (4 veces en la portada); web/components/HealthCard.tsx:43; web/app/p/[id]/page.tsx:280 ("RevPAR 30d vs equilibrio"); definición para la leyenda en web/app/page.tsx:276-279.
- **Qué significa de verdad:** Lo que entra por cada noche del calendario de los próximos 30 días (vendida o vacía, en bruto ÷ 30) contra lo que tendría que entrar para cubrir todos los costes del piso (lib/salud.ts:53-69). Es la única comparación forward contra el punto de equilibrio.
- **Por qué confunde:** "eq." es indescifrable y la sigla + abreviatura a cuerpo chico hacen ilegible justo la señal más importante de la tira de salud. Se repite 4 veces en la pantalla principal.
- **Propuesta:** Fila de portada: "13 libres · 128 €/noche (necesita 140)" — mismo ancho o menor. Tarjeta: "Rinde/noche vs equilibrio". Ficha (hay sitio): "€/noche del calendario (RevPAR) · 30 días vs equilibrio". Y añadir a la leyenda de la tira: "€/noche = lo que entra por cada noche del mes, esté vendida o vacía".

## 14. ADR YTD / "RevPAR 175 € · 755 noches" / "ADR / RevPAR" con sub "RevPAR 175 € · ADR portfolio 196 €"

- **Gravedad:** media
- **Dónde:** web/app/page.tsx:154 (KPI) y 158-160 (sub); web/app/p/[id]/page.tsx:326-327 (KPI de la ficha).
- **Qué significa de verdad:** ADR = precio medio de una noche VENDIDA (bruto ÷ noches vendidas). RevPAR = el mismo bruto repartido entre TODAS las noches disponibles, llenas o vacías. "Portfolio" = la media de los 4 pisos.
- **Por qué confunde:** Dos siglas del sector hotelero juntas y un solo número grande: no se sabe cuál es cuál ni por qué difieren. VEREDICTO consolidado (hubo relevadores en desacuerdo): las siglas SE MANTIENEN — son el idioma real del sector y PriceLabs se las muestra a Stag todos los días — pero con su traducción al lado la primera vez por pantalla; después pueden ir solas en cabeceras de tabla.
- **Propuesta:** KPI portada: "Precio/noche (ADR) · 2026"; sub: "175 €/noche contando las vacías (RevPAR) · 755 noches vendidas". KPI ficha: "Precio medio/noche (ADR)" con sub "Por noche disponible, llena o vacía: 175 € (RevPAR) · media de los 4 pisos: 196 €" (fuera "portfolio").

## 15. real devengado / devengado real / badge "real · devengado"

- **Gravedad:** media
- **Dónde:** web/app/page.tsx:145 (sub del KPI de ingreso); web/app/p/[id]/page.tsx:214 (sello de la ficha); web/app/analisis/page.tsx:60; web/components/CuentaDuena.tsx:44 (badge); web/app/cuadre/page.tsx (línea "real (devengado…)"); caption de web/components/YtdPropiedadTable.tsx:38.
- **Qué significa de verdad:** Importes reales (no proyección) imputados a la noche en que se durmió, estén cobrados o no. Es LA garantía de honestidad del dato.
- **Por qué confunde:** "Devengado" es la palabra contable exacta y por eso no comunica: la duda real de Stag es "¿esto ya lo cobré?". No se puede simplificar a "real" a secas (devengado ≠ cobrado), así que la traducción tiene que conservar la precisión.
- **Propuesta:** Unificar en "por noche dormida": badge "real · por noche dormida"; sub del KPI "real 2026 · contado por noche dormida"; y una línea de leyenda una sola vez por pantalla: "Cuenta las noches ya dormidas, no lo que entró al banco."

## 16. Sync 4 ago 2026, 7:12 · … (después: costes estimados)

- **Gravedad:** media
- **Dónde:** web/app/page.tsx:242 (sello de la portada) y web/app/p/[id]/page.tsx:213-218 (sello de la ficha, con "devengado real" en medio).
- **Qué significa de verdad:** Última descarga de datos de Guesty y hasta qué mes el banco está conciliado.
- **Por qué confunde:** "Sync" es inglés técnico. "Banco conciliado hasta" está BIEN y no se toca: conciliar es la palabra que el propio Stag usa en el ritual de cierre.
- **Propuesta:** Portada: "Datos al 4 ago 2026, 7:12 · banco conciliado hasta jun 2026". Ficha: "Datos al 4 ago 2026, 20:31 · importes por noche dormida · banco conciliado hasta jun 2026 (después: costes estimados)".

## 17. Colchón ajustado: solo 5,6 pp por encima del equilibrio (85,9 % necesario) / "2 mes(es) con margen neto negativo este año"

- **Gravedad:** media
- **Dónde:** supabase/migrations/045_avisos_fechados.sql:69-71 y 80 (textos de v_alertas) → se ven en "Requiere atención" (web/components/AlertStack.tsx:59) en portada y ficha.
- **Qué significa de verdad:** (1) El piso llena solo 5,6 puntos por encima del mínimo que necesita (85,9 % de las noches). (2) Cerró 2 meses del año en pérdida, contada ya su parte de estructura.
- **Por qué confunde:** "pp" sin explicar, "colchón" sin decir de qué, "mes(es)" es texto de programador y "margen neto negativo" arrastra la ambigüedad de "margen neto". Son alertas: si no se entienden de un vistazo, no cumplen.
- **Propuesta:** "Va justo: necesita llenar el 85,9 % de las noches del año y solo va 5,6 puntos por encima." / "2 meses cerraron en pérdida este año" (singular/plural resuelto en el SQL). OJO: viven en SQL → exige una migración nueva que redefina v_alertas (GRANT a authenticated SOLO, patrón del repo), y actualizar apply_all.sql.

## 18. señal (chip gris en las alertas sin fecha)

- **Gravedad:** media
- **Dónde:** web/components/AlertStack.tsx:57 (tag-senal), portada y ficha.
- **Qué significa de verdad:** Aviso SIN fecha límite: una condición que se arrastra, a diferencia de las alertas con cuenta atrás.
- **Por qué confunde:** La palabra sola no comunica "esto no vence, es crónico".
- **Propuesta:** "sin fecha" (mismo espacio; el ⚠️ ya lo distingue del ⏰ de las que tienen plazo).

## 19. Cuadre — "integridad del modelo y banco" (tile) y el sello negativo "cuadre ⚠ 2"

- **Gravedad:** media
- **Dónde:** web/app/page.tsx:323-324 (tile "Ir a") y web/lib/cuadre.ts:45 (stampCuadre, rama negativa).
- **Qué significa de verdad:** 8 chequeos automáticos de coherencia interna del motor + cuadre contra banco. "cuadre ⚠ 2" = 2 chequeos NO cuadran.
- **Por qué confunde:** "Integridad del modelo" es ingeniería de datos. Y "cuadre ⚠ 2" puede leerse como "2 cuadran bien" — al revés de la verdad. El positivo "cuadre ✓ 8/8" y los textos de resumenCuadre ya están bien (cuadrar es vocabulario de Stag): no tocarlos.
- **Propuesta:** Tile: "¿cuadran las cuentas entre sí y con el banco?". Sello negativo: "cuadre ⚠ 2 de 8".

## 20. a favor 1.234 € · Jacobine (tile de portada) / "A favor 1.234 €" (atajo de la ficha)

- **Gravedad:** media
- **Dónde:** web/app/page.tsx:336-339 (tile "Cuenta de la dueña") y web/app/p/[id]/page.tsx:243-247 (cta-cuenta). El recibo interno ("A favor de la dueña", CuentaDuena.tsx:49 y 88) está bien: ahí sí dice de quién.
- **Qué significa de verdad:** Saldo que Samavi le debe a la dueña de Jacobine por los meses cerrados.
- **Por qué confunde:** "A favor" sin decir de quién: puede leerse como dinero a favor de Samavi — el sentido contrario.
- **Propuesta:** "le debemos 1.234 € · Jacobine" (y si el saldo se invierte alguna vez, "nos debe X €" según el signo).

## 21. lo vendido a 30 días rinde por debajo del equilibrio / los próximos 30 días aún no cubren la ocupación de equilibrio

- **Gravedad:** media
- **Dónde:** web/lib/salud.ts:40 y 48 (motivos de estado, se ven bajo cada propiedad en la tira de salud de portada y en las tarjetas). Actualizar tests.
- **Qué significa de verdad:** (1) Al precio actual, los próximos 30 días no dan para cubrir los gastos del piso. (2) Aún faltan noches por vender para cubrirlos.
- **Por qué confunde:** Repiten el sustantivo abstracto "el equilibrio" en vez de la consecuencia. Los otros motivos del mismo archivo están bien escritos y el contraste se nota.
- **Propuesta:** "a este precio, los próximos 30 días no cubren sus gastos" / "todavía faltan noches por vender para cubrir los gastos del mes".

## 22. pp ("+8,6 pp", "peor colchón: Alexander +8,6 pp", "opera a 8,6 pp de su punto de equilibrio", "colchón ▲ +8,6 pp holgado")

- **Gravedad:** media
- **Dónde:** web/lib/format.ts (función pp, la origina); web/app/page.tsx:151 (sub del KPI de ocupación); web/lib/headline.ts:73; web/app/p/[id]/page.tsx:224; web/components/BulletBreakeven.tsx:36; web/components/BreakevenTable.tsx (columna Colchón, vía pp()); web/components/Simulador.tsx (línea "colchón").
- **Qué significa de verdad:** Puntos porcentuales entre ocupación real y necesaria (91,5 % − 82,9 % = 8,6). "Opera a 8,6 pp de" significa POR ENCIMA — pero no lo dice.
- **Por qué confunde:** "pp" no se lee fuera de un informe de analista, y "a 8,6 pp de su equilibrio" puede leerse como que le FALTAN 8,6 puntos: el contrario de la verdad. Aclaración deliberada: la palabra "colchón" SE MANTIENE (castellano llano, ya viene con holgado/ajustado/en pérdida) — un relevador propuso quitarla y se descarta.
- **Propuesta:** "puntos" en texto corrido y "pts" donde aprieta el ancho (cambiar el formateador pp() a "pts"). Headline: "llena 8,6 puntos por encima de su punto de equilibrio" (dirección explícita). Sub del KPI: "menos colchón: Alexander, +8,6 pts sobre lo que necesita".

## 23. Waterfall del margen · YTD 2026 · real / escalón "Bruto" / sub "Bruto 34.500 € · 21 reservas"

- **Gravedad:** alta
- **Dónde:** web/app/p/[id]/page.tsx:336 (título) y 321-323 (sub del KPI Ingreso Samavi); web/lib/waterfall.ts:52 (escalón).
- **Qué significa de verdad:** El gráfico que muestra cómo de la venta bruta se llega al margen. Bruto = alojamiento post-promoción + limpieza, ANTES de la comisión del canal — verificado en 060; NO incluye la tasa de servicio que Airbnb cobra aparte al huésped, así que NO puede llamarse "lo que paga el huésped".
- **Por qué confunde:** "Waterfall" es el nombre de la FORMA del gráfico, en inglés. Y "Bruto" a secas se puede leer como lo que pagó el huésped (es más) o como facturación de Samavi (es menos): si el primer número se lee mal, toda la cascada se lee mal.
- **Propuesta:** Título: "De la venta al margen, paso a paso · 2026 · real" (corta: "De la venta al margen · 2026"). Escalón: "Venta bruta". Sub del KPI: "De 34.500 € de venta bruta (alojamiento + limpieza); el resto se lo lleva el canal · 21 reservas" — así también queda anclado "Ingreso Samavi", cuyo nombre se mantiene.

## 24. Comisión + Pasivo Madre (escalón) y la nota "…incluye la comisión de canal y el Pasivo Madre"

- **Gravedad:** alta
- **Dónde:** web/lib/waterfall.ts:56 (escalón, ficha de Jacobine) y web/app/p/[id]/page.tsx:339-345 (nota del gráfico).
- **Qué significa de verdad:** Verificado en 033_comision_canal.sql: pasivo_madre = host_payout − comisión de Samavi = la parte del cobro que pertenece a la dueña del piso.
- **Por qué confunde:** Nombre interno del motor que no existe fuera del código. Y en la MISMA ficha esa plata se llama —bien— "Cuenta de la dueña": dos nombres para lo mismo en una pantalla.
- **Propuesta:** Escalón: "Canal + dueña" (entra en el eje del gráfico). Nota: "Caso aparte: de lo que paga el huésped, Samavi se queda su comisión del 25 % (factura 30,25 %; los 5,25 puntos son IVA de Hacienda); el resto es de la dueña — por eso el primer escalón es tan grande."

## 25. Baseline real precargado · cálculo al instante (y "· fecha límite 01/09/2026")

- **Gravedad:** alta
- **Dónde:** web/app/p/[id]/page.tsx:231-234 (sub del botón "Simular renegociación →", above the fold de la ficha).
- **Qué significa de verdad:** El simulador se abre cargado con los números reales del piso, no con valores de ejemplo.
- **Por qué confunde:** "Baseline" es inglés técnico en el botón más importante de la pantalla (el caso rey: renegociar Alexander).
- **Propuesta:** "Arranca con tus números reales · resultado al instante" / con contrato: "Arranca con tus números reales · fecha límite 01/09/2026".

## 26. fuera del P&L (badge)

- **Gravedad:** alta
- **Dónde:** web/components/RecobrosCard.tsx:63 (junto a "Recobros — plata adelantada", ficha de Jacobine).
- **Qué significa de verdad:** Esa plata no es ingreso ni gasto: es un adelanto recuperable, no mueve el margen (migración 065).
- **Por qué confunde:** "P&L" es sigla contable inglesa. El resto de la tarjeta está en castellano llano ("plata adelantada", "sin recuperar") y el badge —justo el que evita el susto— es lo único que no se entiende.
- **Propuesta:** "no toca el margen" (16 chars; corta si no entra: "no es gasto").

## 27. …en el coste del P&L (con IVA y retención) son 1.915,60 €/mes… / "El slider opera en coste P&L"

- **Gravedad:** alta
- **Dónde:** web/components/Simulador.tsx:21-26 (aviso ⚠ de Alexander, GOTCHA_2027) y 227-231 (nota de renta contractual).
- **Qué significa de verdad:** La renta que se transfiere (1.614,80) no es lo que le cuesta a la empresa: con IVA y retención el coste real es 1.915,60, y la palanca trabaja con ese coste.
- **Por qué confunde:** Tres jergas en una frase ("P&L", "slider", "coste P&L") en el aviso más importante del simulador — el caso Alexander — que hoy se lee como nota técnica.
- **Propuesta:** Aviso: "La renta sube desde oct-2026: transferís 1.614,80 €/mes, pero a Samavi le cuesta 1.915,60 €/mes con IVA y retención. Esta proyección va al ritmo de lo que llevás del año y no incluye la subida: si tu decisión cruza octubre, poné la palanca de renta en 1.915,60 para ver el escenario real." Nota: "La palanca de renta trabaja con el coste real para Samavi (con IVA y retención), no con lo que transferís." Y "slider" → "palanca" en todos los textos del simulador.

## 28. …mientras queden BINs el importe real es menor y puede ser cero

- **Gravedad:** alta
- **Dónde:** web/components/DelMargenALaCaja.tsx:68-72 (/analisis, nota de la provisión).
- **Qué significa de verdad:** Bases imponibles negativas: pérdidas de años anteriores que se descuentan del beneficio antes de calcular el impuesto.
- **Por qué confunde:** Sigla de gestoría sin desarrollar, dentro de la nota cuyo único trabajo es tranquilizar.
- **Propuesta:** "…mientras queden pérdidas de años anteriores por compensar, el importe real es menor y puede ser cero".

## 29. Provisión Impuesto de Sociedades (20 %) [estimado]

- **Gravedad:** media
- **Dónde:** web/components/DelMargenALaCaja.tsx:48 (/analisis).
- **Qué significa de verdad:** El impuesto que tocaría pagar, calculado como techo prudente y todavía NO pagado (se compensa con pérdidas anteriores).
- **Por qué confunde:** "Provisión" es exactamente la palabra que un no contable no distingue de "pago hecho".
- **Propuesta:** "Impuesto de Sociedades (20 %) [estimado, aún no pagado]".

## 30. Del margen a la caja · YTD 2026 / "Contribución de los 4 pisos [real devengado]" y "Overhead de gestión [por días bajo gestión]"

- **Gravedad:** media
- **Dónde:** web/app/analisis/page.tsx:63 (título) y web/components/DelMargenALaCaja.tsx:22 y 28 (primeras dos líneas de la cascada).
- **Qué significa de verdad:** La cascada del margen de los pisos al resultado de la empresa, antes y después del impuesto estimado. La última línea NO es plata disponible en el banco.
- **Por qué confunde:** El título promete "caja" (dinero disponible) y entrega resultado contable — el único título de la zona que dice algo que el contenido no cumple. Y arranca con dos términos de manual, uno en inglés.
- **Propuesta:** Título: "De los pisos al resultado de la empresa · 2026 hasta hoy". Líneas: "Lo que dejan los 4 pisos [sin estructura]" y "Gastos de estructura [tu sueldo, gestoría, software]".

## 31. €/noche neto (Ranking y KPI de ficha) frente a "Aporta / noche" (tabla Equilibrio) y "aporta 154 €/noche" (ficha)

- **Gravedad:** media
- **Dónde:** web/components/RankingTable.tsx:47 y web/app/p/[id]/page.tsx:328-329 (€/noche neto); web/components/BreakevenTable.tsx:37 y web/app/p/[id]/page.tsx:312-316 (aporta/noche).
- **Qué significa de verdad:** Dos números distintos con nombres casi iguales: €/noche neto = margen con estructura ÷ noches vendidas (lo que sobra al final). Aporta/noche = contribucion_noche = (ingreso − limpieza) ÷ noche (lo que cada noche deja para IR cubriendo los fijos, antes de cubrirlos). En un mismo piso pueden ser 30 € y 154 €.
- **Por qué confunde:** Los dos se leen como "lo que deja una noche": si Stag compara el 154 € con el 30 €, la conclusión sale al revés.
- **Propuesta:** €/noche neto → "Queda/noche" (cabecera) y KPI "Queda por noche vendida" (su sub actual ya está bien) — coherente con la columna "Queda". Aporta/noche → "Para cubrir fijos/noche" (NO "deja para fijos": colisionaría con la columna "Deja", que es otra capa); pie del bullet: "Costes fijos 17.190 € (sin su parte de estructura, 7.696 €) · cada noche vendida deja 154 € para ir cubriéndolos".

## 32. TOTAL comprometido

- **Gravedad:** media
- **Dónde:** web/components/OnTheBooksTable.tsx:52 (fila total de "Ya reservado", en la ficha y en /analisis).
- **Qué significa de verdad:** Suma del ingreso de todas las noches futuras ya reservadas.
- **Por qué confunde:** "Comprometido" suena a plata que Samavi DEBE, no a plata que va a entrar; contradice la cabecera de su propia sección, que está bien ("Ya reservado · futuro confirmado").
- **Propuesta:** "TOTAL ya reservado".

## 33. % s/ Ingreso / "Noches p/ cubrir"

- **Gravedad:** media
- **Dónde:** web/components/CostesTable.tsx:36 (Desglose de costes, ficha y /analisis) y web/components/BreakevenTable.tsx:38 (pestaña Equilibrio).
- **Qué significa de verdad:** Qué % del ingreso de Samavi se llevan los costes del piso; y cuántas noches hay que vender para cubrir los fijos.
- **Por qué confunde:** "s/" y "p/" son abreviaturas de gestoría/telegráficas: en pantalla chica se leen como fracción o errata.
- **Propuesta:** "% del ingreso" (mismo ancho) y "Noches necesarias".

## 34. 1A_NICA · 4B_ALEX · 3G_MARE · 1A_JACO (primera columna) y "JACO: 100 % Airbnb…"

- **Gravedad:** media
- **Dónde:** web/components/CostesTable.tsx:44 y web/components/BreakevenTable.tsx:49 (pestañas Costes y Equilibrio de /analisis y ficha) y web/app/analisis/page.tsx:128 (aviso de Canales).
- **Qué significa de verdad:** Códigos internos piso+puerta de cada propiedad.
- **Por qué confunde:** El resto del dashboard las llama Nicasio, Alexander, Marechal, Jacobine: dos vocabularios para las mismas 4 propiedades en pestañas contiguas.
- **Propuesta:** Usar nombreCorto() también acá: "Nicasio", "Alexander", "Marechal", "Jacobine" y "Jacobine: 100 % Airbnb y cero Booking…". Entran igual o mejor que los códigos.

## 35. Mix por canal · YTD 2026

- **Gravedad:** media
- **Dónde:** web/app/p/[id]/page.tsx:397 (ficha). La pestaña "Canales" de /analisis está bien y no se toca.
- **Qué significa de verdad:** De qué plataforma vienen las reservas y cuánto ingreso trae cada una.
- **Por qué confunde:** "Mix" es anglicismo de marketing y no dice qué se compara.
- **Propuesta:** "De dónde vienen las reservas · 2026".

## 36. Vendido 7d · 14d · 30d (ficha) / "Vendido 7d · 30d" (tarjetas)

- **Gravedad:** media
- **Dónde:** web/app/p/[id]/page.tsx:276-277 y web/components/HealthCard.tsx:39.
- **Qué significa de verdad:** % de las noches de los próximos 7/14/30 días ya vendido.
- **Por qué confunde:** No dice vendido de qué (¿noches?, ¿ingreso?) y "7d" obliga a traducir.
- **Propuesta:** Ficha: "Noches ya vendidas · 7, 14 y 30 días". Tarjeta (poco ancho): "Noches vendidas 7 · 30 d".

## 37. Alquiler devengado / Gastos repercutidos / Por repercutir a la dueña / comisión — "ingreso = 25 % del bruto (se factura 30,25 %; el IVA no es ingreso)"

- **Gravedad:** media
- **Dónde:** web/components/CuentaDuena.tsx:68 y 82 (recibo de la Cuenta de la dueña); web/components/RecobrosCard.tsx:66; web/app/p/[id]/page.tsx:66 (MODELO_LABEL de comisión, visto en el subtítulo de la ficha de Jacobine).
- **Qué significa de verdad:** Lo que le corresponde a la dueña por las noches dormidas del año CON la comisión de Samavi ya descontada (066: pasivo_madre prorrateado); los gastos que Samavi adelantó y le descuenta; lo que falta descontarle. Y el modelo: Samavi cobra el 25 % de la venta, factura 30,25 % porque encima va el IVA de Hacienda.
- **Por qué confunde:** "Devengado" y "repercutir" son de gestoría y desentonan en una pantalla que ya está bien escrita como recibo. La línea del alquiler además no dice que la comisión YA está descontada. Y la ecuación con "=" del subtítulo se lee como nota de programador.
- **Propuesta:** "Alquiler de las noches ya dormidas" + nota chica (estilo .recibo-nota existente): "con tu comisión ya descontada" · "Gastos que le descontás [reparaciones y reposiciones]" · "Por descontarle a la dueña" · subtítulo: "comisión — cobrás el 25 % de la venta (facturás 30,25 %: el resto es IVA de Hacienda)".

## 38. Margen jul (vendido) / "3 en 7d · 5 en 15d · última hace 2 días"

- **Gravedad:** baja
- **Dónde:** web/components/HealthCard.tsx:50 y web/app/p/[id]/page.tsx:287-293 (Velocidad de venta — la etiqueta en sí está bien, no tocarla).
- **Qué significa de verdad:** El margen con el que cerraría julio contando solo lo ya vendido; y reservas nuevas creadas en 7/15 días + días desde la última.
- **Por qué confunde:** "(vendido)" parece un estado del margen, no una condición de cálculo; y los números de velocidad no dicen de qué son.
- **Propuesta:** "Margen jul con lo vendido" y "3 reservas nuevas en 7 días · 5 en 15 · la última, hace 2 días".

## 39. Cifras mezcladas "+677" junto a "+3,0k" en la tabla de ya-reservado

- **Gravedad:** baja
- **Dónde:** web/components/AseguradoTable.tsx:22-26 (formato compacto) y cabecera "Propiedad · €" (línea 53).
- **Qué significa de verdad:** Formato compacto deliberado para que los 6 meses entren a 390 px sin scroll — un mes fuera de cuadro es un mes que nadie mira.
- **Por qué confunde:** Dos escalas de lectura en la misma columna y la "k" es notación anglosajona. PERO la razón del formato está bien argumentada y el ancho manda: NO se cambia el formato.
- **Propuesta:** MANTENER el formato; solo añadir la unidad a la cabecera: "Propiedad · € (k = miles)".

## 40. MANTENER SIN CAMBIOS: "Punto de equilibrio", "colchón" (con holgado/ajustado/en pérdida), "Ingreso Samavi", "Cuenta de la dueña", "Resultado Samavi", "Ya reservado · futuro confirmado", "Velocidad de venta", "banco conciliado", los nombres Nicasio/Alexander/Marechal/Jacobine

- **Gravedad:** baja
- **Dónde:** Todo el dashboard.
- **Qué significa de verdad:** Son los términos que ya cumplen la doctrina: castellano llano, precisos, y varios son vocabulario del propio Stag (conciliar, cuadrar) o del Excel original (Ingreso Samavi).
- **Por qué confunde:** Algunos relevadores propusieron tocarlos ("colchón" → "el más justo"; explicar "Ingreso Samavi" renombrándolo). Renombrar por renombrar tiene costo: Stag ya los usa, y los tests y el SQL los nombran. La confusión de "Ingreso Samavi" no está en la palabra sino en su par con "Bruto" — se resuelve en el sub del KPI (ver hallazgo de Venta bruta), no renombrando.
- **Propuesta:** No cambiar ninguno. También DESCARTADO: retocar los mensajes de configuración de Supabase (page.tsx:117 y 254-256) — solo aparecen en local sin variables de entorno, nunca en producción (las NEXT_PUBLIC_* van horneadas en el build); no vale una línea de diff en la pantalla que Stag sí ve.
