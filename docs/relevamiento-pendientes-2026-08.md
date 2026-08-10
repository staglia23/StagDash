# Relevamiento de pendientes — 05/08/2026

Barrido completo de cuatro fuentes: memoria del proyecto, spec del CEO contra lo
construido, anotaciones dentro del repo y estado real de los datos en producción
(Supabase, verificado hoy). 71 hallazgos crudos → ~40 pendientes reales tras fusionar
duplicados y verificar cierres.

**ESTADO: LISTA VIVA.** Tachar o borrar cada item al cerrarlo. Complementa
`docs/relevamiento-terminologia-2026-08.md` (que es, a su vez, el item B1 de esta lista).

---

## Resumen — por dónde seguir

- **Esta semana**: cierre de julio (A1, te toca subir extractos) + evaluar el pickup de
  los suelos nuevos el 09–10/08 (A4), verificando antes que Airbnb sirva los precios.
- **Antes del 01/09**: adenda de Alexander (A2, la fecha más cara del trimestre) y motor
  de comisiones de Booking (A3, antes del cierre de agosto).
- **Para nutrir el dashboard ya, sin esperar a nadie** (carril Claude, en este orden):
  selector de período (C1) → drill-down a mes con lista de reservas (C2) → heatmap (C3)
  → diseño del pace (C4, fecha natural 02/09 cuando la foto diaria cumpla 30 días).
- **Decisiones tuyas que destraban trabajo**: terminología (B1), reservas «reserved»
  (B2), conciliación Airbnb (B3), criterio de overhead (B4), vistas por horizonte (B5).

---

## A. Con fecha — se vencen solos

1. **Cierre de julio 2026 — YA VENCIDO (ritual de principios de agosto).** El banco está
   cargado hasta junio (`cierre_hasta = 2026-06-01`); julio tiene 2 events contra los
   11–16 de un mes cerrado. Stag sube los extractos (Revolut/BBVA/tarjeta) a Drive y se
   concilia. Arrastra en cascada: IBI julio 354,96 €; cuota 2/3 de los auriculares
   145,80 € (overhead — y la 3/3 cae en el extracto de agosto); recibo de agua nº 765
   (falta el importe); toallas/ropa de cama de 2025 y julio; el importe real del arreglo
   de los daños de junio en Jacobine (se cobraron 98 € por Resolution Center y el motor
   los comisionó — exposición ~73,50 €); y limpieza/suministros de julio de los 3 pisos
   de Madrid cuando lleguen las facturas. **CARGADO el 10/08 (migración 074)**: 26
   depósitos + `airbnb_tx` julio + 19 events con las respuestas de Stag; `cierre_hasta`
   = julio. Quedan: AEAT 111 (falta desglose), BLT (identificar factura), daños de
   junio JACO (aclarar), bolsillo julio, y las facturas externas (TotalEnergies,
   Ecocleans, intereses del préstamo).

2. **Adenda de Alexander — abrir la negociación ANTES del 01/09** (contrato vence 30/09;
   al abrirse la ventana Alberto puede preavisar la no-prórroga, Samavi no puede irse).
   El pacto de renta es VERBAL: sin adenda el contrato permite facturar 1.647,10 €/mes.
   Contenido: fijar por escrito transferencia/base/IVA/retención (vale 460–852 €/año),
   resolver la discrepancia 1.614,80 (contrato) vs 1.641,80 (hoja de trabajo), pedir
   sacar comunidad+seguro de la renta (2.021 €/año; ni contrato ni ley los cargan a
   Samavi), decidir si se compensan los ~598 € pagados de más del prorrateo del
   amoblamiento, y de paso reclamar la luz del 01–23/01 (~149 €, período a nombre de
   Alberto). El dossier vive en el proyecto Admin & Fiscal. Recordatorio ya cargado en
   `avisos`: actualizar `listings.renta_base` en enero 2027. *Bloquea: Stag.*

3. **Motor: comisión de Booking — antes del cierre de agosto.** Booking es «payment by
   the property»: el motor ve el bruto y no la comisión. Hay 2 reservas de NICA en
   agosto con 466,95 € de comisión que se cargan al llegar la factura (como junio), y
   Booking factura por fecha de SALIDA (mes equivocado en reservas a caballo): hay que
   prorratear por noche en el motor y decidir si se netea del ingreso o va como coste
   separado. Es prerequisito para decidir abrir Booking a Marechal (B6). *Bloquea:
   Claude (diseño) + decisión de Stag.*

4. **Pickup tras la restauración de suelos — evaluar el 09–10/08.** Suelos restaurados el
   05/08 (JACO 155, NICA 150, ALEX 129, MARE 99) con push a canales 09:28–09:55. Si en
   4–5 días el pickup no responde, bajarlos (reversible, ya aceptado). ANTES de evaluar:
   verificar el último eslabón — que Airbnb esté sirviendo los precios nuevos
   (antecedente del 03/08: Marechal sirvió el precio viejo horas después del cambio).
   Señal: `min_prices_next_30` y pickup 30d de `pricelabs_prices`. *Bloquea: nadie.*

5. **01/09 — triple cita.** (a) Repricing de octubre: foto forward + qué promos nativas
   de Airbnb siguen vivas + revisar las personalizaciones por defecto de PriceLabs
   (último minuto −40 %, huérfanos −20 %, recencia −5/−15 %: hoy los suelos las
   neutralizan, pero muerden si los recomendados suben en temporada alta). (b) La subida
   de mínimos del 01/10 vía Custom Seasonal Profile está **pendiente de aplicar** (no
   programada en PriceLabs). (c) Hacia el 02/09 `pricelabs_fotos` cumple ~30 días: primera
   fecha viable para las vistas de pace (C4). NO repriciar octubre antes de septiembre.
   *Bloquea: calendario.*

## B. Decisiones de Stag — destraban trabajo ya listo

1. **Terminología: 40 términos propuestos** en `docs/relevamiento-terminologia-2026-08.md`.
   Los 6 primeros son los que vos señalaste como confusos. Acoplamientos que el propio
   doc marca: los renombres #7 y #8 van en el mismo commit, los #5 y #12 exigen
   actualizar tests, y 2 de los 40 viven en `v_alertas` (SQL) → migración (E3).
   **Decisión de Stag 05/08: el glosario se lleva DENTRO del dashboard (pantalla
   `/glosario`, ver C8) con los términos propuestos tal cual; él los repasa después.**
2. **Reservas en estado «reserved»**: 3 futuras por 3.206 € que el motor ignora y hoy no
   se muestran en ningún lado (cifra verificada vigente al céntimo). La spec pide
   mostrarlas separadas y etiquetadas — ¿entran al on-the-books con descuento por riesgo,
   se muestran aparte, o se siguen ignorando? Requiere SQL nuevo si se muestran.
3. ~~`airbnb_tx` vacía~~ **RESUELTO (074+078, 10–11/08)**: cargada dic-2025→jul-2026
   (464 transacciones de los CSV que pasó Stag). La conciliación Airbnb↔banco ene–jul
   cierra al céntimo en los dos IBANs y los artefactos acumulados (BBVA −876,07 y
   Revolut +2.328,86) quedaron explicados como timing puro y CERRADOS.
4. **Criterio de overhead por defecto (spec §8.3)**: de facto todo abre en margen neto
   con toggle a directo. Falta ratificarlo para cerrar la cuestión abierta en la spec —
   afecta directamente cómo se lee Alexander.
5. **Vistas KPI por horizonte** (propuesta Fede 30/07): Morning Check ya es la portada;
   faltan semanal / mensual / anual. ¿4 páginas, pestañas o una portada que progresa?
   Nota técnica: semanal y diario NO pueden salir de las `f_*` actuales (el prorrateo del
   overhead es mensual).
6. **Marechal flojo (63–70 %, único sin Booking)**: la hipótesis abierta es
   visibilidad/canal, no precio. ¿Se abre Booking? Decidir DESPUÉS de resolver A3.
7. **YoY like-for-like (v2.1)**: las `f_*` ya aceptan rangos 2025, pero faltan los costes
   2025 (la 071 incorporó 2025 solo a la cuenta de la dueña). Sin ellos, el YoY de margen
   sigue vetado. Hace falta que aportes/valides esos costes.
8. **Refactoring UI estético**: lo pediste «para más adelante» — falta definir alcance.
9. **Fondo (v2+, nunca retomados formalmente)**: chat agéntico dentro del dashboard,
   tesorería/Caja Libre, forecast anual estilo Excel.

## C. Construcción — listo para arrancar sin decisión previa

1. **Selector de período (`?m=`) y de propiedad (`?p=`) en el UI.** El backend está listo
   desde la 060 (`f_ranking`/`f_costes`/`f_breakeven`/`f_canal` por RPC), pero el front no
   invoca ningún RPC: todo sigue clavado al año en curso. La mayor palanca inmediata.
2. **Drill-down a mes + lista de reservas** (`/p/[id]/[mes]` + `?r=`): portfolio →
   propiedad → mes → reservas del mes, con fila expandible y breadcrumb. Al diseñarlo,
   decidir a propósito la exposición por reserva (contexto de la 033; con login el
   contexto cambió).
3. **Heatmap de ocupación del mes** (calendario con letra de canal por celda). Depende
   de C2.
4. **Diseño del pace (`v_pace`)**: dos aproximaciones posibles (por `created_at` de
   reservas vs `pricelabs_fotos`) y ninguna elegida. La foto diaria es insert-only y no
   se reconstruye hacia atrás: decidir pronto maximiza la historia. Vigilar mientras
   tanto que el cron diario no falle (cada caída es historia perdida).
5. **Tabla `bloqueos_deliberados`**: hoy los bloqueos a propósito (p. ej. JACO 18–20/08)
   viven solo en memoria y `/precios` los lee como pérdida.
6. **Pantalla de edición de costes/events sin SQL**: declarada «proyecto aparte», el
   cierre mensual sigue dependiendo de SQL. Estructural, no urgente mientras el flujo
   actual funcione.
7. **Automatizar la carga de la conciliación** (agente mensual que lea Drive y cargue
   solo — anotado como opcional en `scripts/RUNBOOK_conciliacion.md`).
8. **Glosario en el dashboard (`/glosario`)** — pedido por Stag el 05/08: los términos
   del dashboard con su definición, a mano por si no recuerda alguno. Arranca con los
   propuestos en B1 tal cual están; él los repasa después. Quick win.

## D. Flecos de datos — mayormente info que tiene que pasar Stag

1. **Bizums por arreglos de Jacobine — CARGADOS el 05/08 (migración 073)**: entraron los
   3 retro de 2025 (25 + 53 + 30 €) como pendientes; el 4º de la lista (20 € del
   01/03/26, mini UPS) ya estaba dentro del recobro liquidado de 77 € de feb-2026 (solo
   se corrigió la nota). Queda: (a) **confirmar con Stag que 53 + 30 = 83 € NO sea el
   mismo descuento de nov-2025** («lavadora y puerta corredera» — concepto distinto,
   suma exacta) antes de liquidar esos dos; (b) liquidar los 5 pendientes (208 €); (c)
   las patas de los muebles, que generarán otro recobro al comprarse.
2. **Diferencia de 248,97 € de 2025** en la cuenta de la dueña (200,00 agosto + 48,97
   septiembre): ajustes de tu planilla sin respaldo en Guesty — quedaste en revisarlos.
3. **Derrama IEE de Nicasio**: falta la fecha de la última cuota (preguntar a la
   administradora). Modelada como perpetua, infla el equilibrio 1.798 €/año.
4. **Promo Movistar de Alexander (línea …89)**: fecha de fin solo visible en Mi Movistar;
   al vencer, el cargo salta de 25 a 36 €/mes y el forward no lo ve. (La de Marechal ya
   está en `avisos`: 27/10/2026.)
5. **Confisic**: (a) IVA de las rentas de Madrid — URGENTE desde abril, ~6.200 €/año en
   juego, decide el caso Alexander: llevarla ANTES del 01/09; (b) alta en ROI/VIES —
   Booking repercute IVA español del 21 % a una sociedad con NIF-IVA; (c) IRPF 1.031,67 €
   y la liquidación de mayo contabilizada como «retiro de socio»: ambos viven en Admin &
   Fiscal, acá solo se vigila que cierren.
6. **Suministros a nombre de Samavi**: papernest (Marechal) y TotalEnergies (Alexander)
   siguen a nombre personal de Stag; pedir refacturación (en Alexander es además
   incumplimiento menor de la cláusula 6.3).
7. **IBI restante de 2026**: octubre 112,13 € y cuota final del PAC el 15/12 — cargar
   como events en sus cierres.
8. **Gastos de planilla sin respaldo**: documentar el TGSS parcial y confirmar que la
   copia de llaves reimputada a Jacobine era del piso de Sevilla.
9. **Termo de Alexander**: verificar contra el PDF del extracto BBVA de mayo (1.222,69
   según nota vs 1.218,86 esperado; hasta 3,83 € por explicar). La nota de la 023 sigue
   «pendiente de verificación bancaria».
10. **ADR de febrero de Jacobine inflado** (214,86 vs 205,72 real por un reembolso del
    Resolution Center que `bruto` no ve): el ingreso está bien, miente solo el precio de
    referencia. ¿Se acepta documentado o se corrige con ajuste puntual?
11. **Marechal, luz**: fleco de febrero (1–7 €, cambio de comercializadora a mitad de
    mes) y hueco de abril (~15,60 € si TotalEnergies regulariza — vigilar facturas).
12. **PDFs de luz/gas de julio de Nicasio** sin archivar en la carpeta Confisic de Drive
    (los importes ya están cargados).

## E. Deuda técnica e higiene

1. **README desactualizado — enseña reglas viejas**: overhead «por ingreso» (hoy: días
   bajo gestión) y JACO «30,25 % del bruto» (hoy: 25 % neto). Con Fede entrando al repo
   tiene costo real. Actualizar también la estructura (llega a la 059; van 72).
2. **Criterio §10 de la spec**: verificar por CDP (390×844 emulado) si la portada sigue
   respondiendo las preguntas 1–4 sin scroll tras el reorden del 05/08; si no, decidir si
   el criterio se reformula.
3. **Textos de `v_alertas` viven en SQL** (045): cambiarlos exige migración + sync de
   `apply_all.sql`. Se activa si aprobás los 2 términos afectados de B1.
4. **Seed**: regenerar desde producción para drift fino (ya se pescó un drift real; y la
   071 dejó sin replicar en el seed los recobros liquidados 2025 y `duena_limpieza` —
   detectado el 05/08 al cargar la 073).
5. **Comentario obsoleto en `cron_setup.sql:47-48`**: dice que la key de PriceLabs está
   pendiente; está viva desde el 05/08.
6. **Secretos**: rotar el client_secret de Guesty compartido por chat en julio (nunca
   confirmado) y, opcional, la key de PriceLabs; en el carril de Fede, los Apps Script
   llevan el secret de Guesty HARDCODEADO — rotar y mover a Propiedades del script.
7. **Fix de los chequeos tautológicos de Ecocleans**: escrito en
   `integrations/apps-script/FIX_chequeos_tautologicos.md`, se aplica en el proyecto de
   Cowork — sin evidencia de que esté aplicado.

## F. Fuera del repo, con fecha dura

1. **Automatización de respuestas a huéspedes** (carril Fede, N8N): operativa antes de
   noviembre (Stag en Río nov–ene). Problema conocido: la IA no siempre identifica la
   propiedad antes de la reserva.
2. **Compensación de Fede**: sin definir desde el 22/07.
3. **Automatizaciones pedidas por Stag el 05/08** (→ proyecto Automatizaciones, carril
   Fede/N8N — NO son de este repo, anotadas para que no se pierdan): (a) facturas que
   llegan por mail (Movistar, Orange, TotalEnergies…) → subida automática a Drive a la
   carpeta del mes que corresponda; (b) subida automática de los extractos bancarios y
   del reporte de Airbnb que alimentan el cierre mensual.

---

## Verificado CERRADO en este relevamiento (no volver a listar)

- **Backfill de `confirmation_code`**: hecho — 649/733 reservas con código; las 84 sin
  código son inquiries, que no tienen.
- **Auditoría de Jacobine**: cerrada (las cuatro propiedades, migraciones 038–048). El
  índice de memoria decía lo contrario; corregido el 05/08.
- **Seguridad post-065-072**: verificada limpia hoy — cero funciones ejecutables por
  anon, cero grants de anon, RLS activo, ambos syncs frescos y sin error.
- Los «PENDIENTE» de los seeds son placeholders de PII por diseño, no pendientes.
