-- 090_bizums_al_carril_familiar.sql — TODO el dinero del bolsillo de Stag pasa al carril
-- directo con su madre, incluido el histórico (20/08/2026).
--
-- Instrucción de Stag: "todos los bizums anteriores computalos como una deuda que voy a
-- arreglar con ella por fuera; las compras y lo demás se descuentan de la deuda con Viviana".
-- La 089 dejó el carril nuevo pero solo movió los tres PENDIENTES; acá se completa el
-- inventario, que tiene dos piezas más y una de ellas estaba escondida:
--
--   · 53,00 (10/10/2025) y 30,00 (15/10/2025) — figuraban LIQUIDADOS contra el descuento de
--     83,00 de nov-2025.
--   · 20,00 (01/03/2026) — un bizum suyo METIDO DENTRO del recobro de 77,00 del mini UPS
--     (56,99 de Amazon con tarjeta de Samavi + 20,00 de bizum personal a Agustín). Nunca
--     tuvo fila propia, así que ningún filtro por `pagado_por` lo habría encontrado.
--
-- ⚠ Y AL VERIFICARLO APARECIÓ UN ERROR REAL: a la dueña se le estaban descontando los 83,00
-- DOS VECES. Su cuenta de nov-2025 mostraba −166,00 cuando el descuento de la planilla fue
-- 83,00. Causa: la 077 marcó los dos bizums como LIQUIDADOS para dejar constancia de que
-- eran el mismo dinero que el descuento de la planilla (fila id 7), pero `f_cuenta_duena`
-- suma como descuento TODA fila liquidada — y contó el mismo dinero por los dos lados.
-- Sacarlos del carril CUENTA_DUENA lo corrige: 2025 vuelve a 8.477,68, que es exactamente
-- la cifra certificada contra Guesty en la 071, antes de que la 077 la torciera.
--
-- Qué significa esto en la vida real, que es lo que importa:
--   · Samavi nunca le pagó nada todavía, así que NO hay que devolverle plata a nadie: esto
--     es puro apunte. Su deuda con Samavi sube 103,00 (83 + 20) y ella le debe a Stag esos
--     mismos 103,00 directamente. Para ella, neto cero.
--   · Stag recupera los 83,00 que el 11/08 había dado por perdidos ("saldado"). Aquella
--     decisión cubría 83 (esto) + 50 (incentivo a José); los 50 siguen como estaban.
--   · Ninguna de las dos cosas toca el P&L: los recobros nunca entraron a `events`.

-- ── 1) Los dos bizums de octubre vuelven a ser deuda VIVA de la madre con Stag ─────
-- Vuelven a PENDIENTE a propósito: LIQUIDADO en el carril directo significaría "Stag ya
-- cobró", y no cobró — quien cobró los 83,00 fue Samavi, descontándoselos a ella.
update recobros
   set liquidacion    = 'DIRECTO_FAMILIA',
       estado         = 'PENDIENTE',
       resuelto_fecha = null,
       resuelto_nota  = null,
       notas = notas || ' || 090 (20/08/2026): pasa al carril DIRECTO_FAMILIA por decision de Stag'
               || ' (todo lo de su bolsillo lo arregla con su madre). Vuelve a PENDIENTE porque el'
               || ' dinero NO volvio a el: lo cobro Samavi descontandoselo a ella en nov-2025.'
               || ' Ese descuento sigue en la fila id 7 (83,00, "Reparacion lavadora y puerta'
               || ' corredera"), que es la de la planilla. De paso arregla un DOBLE DESCUENTO:'
               || ' la 077 dejo esta fila liquidada y f_cuenta_duena suma toda fila liquidada,'
               || ' asi que nov-2025 restaba 166,00 en vez de 83,00.'
 where propiedad_codigo = '1A_JACO'
   and pagado_por = 'STAG_PERSONAL'
   and liquidacion = 'CUENTA_DUENA'
   and ((fecha = date '2025-10-10' and importe = 53.00)
     or (fecha = date '2025-10-15' and importe = 30.00));

-- ── 2) El bizum de 20,00 sale de dentro del mini UPS ──────────────────────────────
-- El recobro de 77,00 mezclaba dos bolsillos. Se queda con la parte de Samavi (56,99 de
-- Amazon + 0,01 de redondeo que ella pagó de más) y el bizum se separa en su propia fila.
update recobros
   set importe = 57.00,
       notas = 'Amazon 56,99 con tarjeta Revolut de Samavi (12/02/2026) + 0,01 de redondeo que se'
               || ' le descontó de más. La 090 (20/08/2026) separó de acá los 20,00 que Stag le pagó'
               || ' a Agustin por BIZUM personal el 01/03/2026 por la instalacion: ese dinero no lo'
               || ' puso Samavi, asi que lo cobra el directamente a su madre (fila aparte,'
               || ' DIRECTO_FAMILIA). A ella se le descontaron 77,00 en feb-2026: al bajar esta fila'
               || ' a 57,00 su cuenta con Samavi sube 20,00, que es justo lo que ahora le debe a Stag.'
               || ' Estaba cargado por error como coste de Nicasio hasta la migracion 049.'
 where propiedad_codigo = '1A_JACO'
   and fecha = date '2026-02-12'
   and importe = 77.00;

insert into recobros (propiedad_codigo, fecha, concepto, importe, pagado_por, pagado_a,
                      medio, estado, liquidacion, resuelto_fecha, resuelto_nota, notas)
select '1A_JACO', date '2026-03-01',
       'Instalación del mini UPS — mano de obra',
       20.00, 'STAG_PERSONAL', 'Agustín (manitas Sevilla)', 'bizum',
       'PENDIENTE', 'DIRECTO_FAMILIA', null, null,
       'Bizum desde la cuenta personal de Stag, sin factura (lista retrospectiva del 05/08/2026;'
       || ' la 065 lo anoto como efectivo del 02/03 y la 073 lo corrigio). Hasta la 090 vivia DENTRO'
       || ' del recobro de 77,00 del mini UPS, mezclado con los 56,99 que puso Samavi: por eso ningun'
       || ' filtro por pagado_por lo encontraba. Se separa para que todo el dinero del bolsillo de'
       || ' Stag se cobre por el mismo carril. A ella se le habian descontado los 77,00 enteros en'
       || ' feb-2026, asi que este importe se le devuelve subiendo su cuenta con Samavi 20,00.'
where not exists (
  select 1 from recobros r
   where r.propiedad_codigo = '1A_JACO' and r.fecha = date '2026-03-01' and r.importe = 20.00
);
