-- 043_comision_booking.sql — la comisión de Booking no llegaba al P&L (Stag, 26/07/2026).
--
-- ── EL AGUJERO ──────────────────────────────────────────────────────────────────
-- Airbnb y Booking cobran su comisión de forma estructuralmente distinta, y el motor solo
-- entendía la de Airbnb:
--
--   AIRBNB   cobra al huésped, se queda la comisión y transfiere el NETO.
--            → host_payout ya viene neteado, y `bruto − ingreso_samavi` da la comisión.
--   BOOKING  (modelo "payment by the property") el huésped paga al alojamiento el BRUTO y
--            Booking factura su comisión aparte, a mes vencido.
--            → host_payout = bruto. `bruto − ingreso_samavi` da CERO. La comisión no existe
--              para el motor, ni como menor ingreso ni como coste.
--
-- Resultado: la reserva BC-qpY7JQDO7 (1A_NICA, 25–28/06, 882,48 €) entró al P&L de junio por
-- su bruto entero. Junio de Nicasio estaba sobrestimado.
--
-- ── EL IMPORTE ES 181,52, NO 150,02 ─────────────────────────────────────────────
-- Factura Booking.com 1657524585 del 03/07/2026, período 01/06–30/06:
--
--   Room sales                882,48 €
--   Commission                150,02 €   ← esto es lo que Guesty guarda en host_service_fee
--   21 % VAT on 150,02         31,50 €
--   Total amount due          181,52 €
--
-- Se carga el TOTAL con IVA, mismo criterio de peor caso que renta (022), limpieza (031) y
-- suministros (034). Por eso el evento (181,52) no coincide con `v_canales_mensual.comision_canal`
-- (150,02): la vista muestra la comisión del canal, el evento carga el coste real.
-- No hay doble conteo: para Booking el escalón de comisión del waterfall vale cero.
--
-- ── CÓMO SE COBRA ───────────────────────────────────────────────────────────────
-- La factura menciona el neteo contra el payout, pero acá no aplica: la huésped transfirió los
-- 882,48 € directamente a Revolut el 16/06, así que Booking no tiene payout que netear. Va por
-- domiciliación SEPA contra la cuenta ...7165 (Revolut · Nicasio + Jacobine), vencimiento
-- 16/07/2026, acreedor NL36ZZZ310473440000. Se verifica en el extracto de julio.
--
-- ── ESTO ES UN PARCHE, Y HAY QUE ARREGLAR EL MOTOR ANTES DE AGOSTO ──────────────
-- No es una reserva suelta: ya hay dos más confirmadas en la cartera, las dos de Nicasio.
--
--   BC-68wENnWVl   16–23/08   1.054,52 €   comisión 179,27 € (+IVA = 216,92 €)
--   BC-jg7mnkyGW   29/08–03/09 1.215,52 €   comisión 206,64 € (+IVA = 250,03 €)
--
-- Son 466,95 € más de coste invisible en agosto y septiembre. Cargarlos a mano reserva por
-- reserva no escala, y menos si se abre el canal en serio: la comisión de Booking (17 %) es un
-- coste directo como el de Airbnb y tiene que salir del mismo sitio del motor.
--
-- Además la factura avisa de algo que rompe el devengo: "OUR INVOICES ARE BASED ON DEPARTURE
-- DATE AND NOT ON ARRIVAL DATE". La BC-jg7mnkyGW entra el 29/08 y sale el 03/09, así que
-- Booking la factura en SEPTIEMBRE mientras el motor devenga 3 de sus 5 noches en AGOSTO.
-- Imputar por la fecha de la factura desplazaría el coste de mes; hay que prorratear por noche,
-- igual que el resto del motor.
--
-- ── UNA PARA CONFISIC, NO PARA ESTE REPO ────────────────────────────────────────
-- Booking (holandesa) está repercutiendo IVA español del 21 % a una sociedad con NIF-IVA
-- B87532867. En un servicio intracomunitario B2B lo habitual es la inversión del sujeto pasivo
-- y factura sin IVA, si el cliente está dado de alta en el ROI/VIES. Que Booking lo cobre
-- apunta a que Samavi no figura ahí. Puede ser irrelevante (si la actividad está exenta el IVA
-- es coste igual) o no serlo — lo decide la misma consulta de régimen de IVA que sigue abierta.
-- Va al proyecto de Admin & Fiscal con el resto.

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 6, '1A_NICA', 'OTROS', 'Comisión Booking.com (factura 1657524585)', -181.52,
       'Reserva BC-qpY7JQDO7, 25-28/06. Comision 150,02 + 21% IVA 31,50. Booking cobra aparte porque la huesped pago el bruto directo (882,48 el 16/06): host_payout = bruto y el motor no descontaba nada. Domiciliado en Revolut ...7165, vencimiento 16/07. PARCHE: quedan BC-68wENnWVl (agosto, 216,92) y BC-jg7mnkyGW (agosto-septiembre, 250,03) sin cubrir.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 6 and e.propiedad_codigo = '1A_NICA'
     and e.concepto = 'Comisión Booking.com (factura 1657524585)');
