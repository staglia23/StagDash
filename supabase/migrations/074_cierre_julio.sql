-- 074_cierre_julio.sql — cierre de julio 2026: banco + airbnb_tx + events (10/08/2026).
--
-- Fuentes: extractos de julio (Revolut CSV, BBVA CSV, tarjeta XLS) y CSV de transacciones
-- de Airbnb subidos por Stag a Drive; análisis del 05/08 (workflow de 4 fases, veredicto
-- APROBADO_CON_RESERVAS) + respuestas de Stag del 10/08. Verificado al céntimo:
--   · 26 depósitos Airbnb = 14.644,88 (Revolut 15 × 7.872,07 + BBVA 11 × 6.772,81).
--   · Guesty julio por fecha de pago = 13.184,13 = PDF de earnings de Airbnb EXACTO.
--     La diferencia banco−Guesty (+1.460,75) es timing: colas de junio entrando el 01/07.
--     El abono BBVA de 876,07 del 01/07 CIERRA el artefacto de junio (−876,07).
--   · airbnb_tx julio: 54 filas (25 Payout con IBAN + 29 Reserva), primer mes cargado.
--     El CSV NO trae la fila de Resolución (~98 de daños) — no existe en este export.
--   · Los 2 events de julio preexistentes (35 Modesto +11,14 y 54 Forjado −382,50)
--     quedaron verificados contra extracto: NO se duplican acá.
--
-- Decisiones de Stag (10/08/2026) aplicadas:
--   · DIA de Madrid se reparte entre los 3 pisos de Madrid (regla NUEVA; hasta junio iba
--     100% a NICA — pendiente decidir si se corrige junio, event 72, Dia Madrid 39,71).
--     Tienda 16110 confirmada Madrid (pagada con tarjeta Metal de Stag; las de Sevilla
--     las paga José con la Standard).
--   · Webel 28,75 = limpieza puntual por app en Sevilla (prueba de suplente para las
--     vacaciones de José). NO es el arreglo de los daños de junio. Coste de Samavi.
--   · Toallas 140,00 (Fc SM 87) = 8 toallas de lavabo + 8 de ducha chocolate, Jacobine,
--     partida COMPLETA de toallas/ropa de cama 2025+julio. Las asume Samavi.
--   · Box2box: plan anual julio (5 cuotas a 34,90/4 sem con −50%, después 65,90). La
--     provisión listings.extras (30) NO se toca — cambiarla movería meses ya auditados;
--     el desvío va por event en cada cierre. Aviso cargado para dic-2026.
--   · Reserva directa JACO 24–27/07 (520) cobrada en EFECTIVO → no toca bancos ni
--     events (el ingreso ya está devengado en el motor); el efectivo queda en cuenta
--     con el socio (carril Confisic).
-- Queda FUERA a propósito (pendiente): AEAT modelo 111 2T −1.103,53 (retenciones de
-- nóminas y profesionales; sin precedente en events y falta el desglose para repartir
-- Stag/José/profesionales), TotalEnergies 429,55 (facturas con CUPS), Ecocleans/BMR
-- 1.205,35 (reparto por factura), intereses del préstamo (falta el recibo; junio 158,45),
-- BLT 1.391,50 va cargado pero con factura por identificar.

-- ── 1) Depósitos bancarios + transacciones Airbnb (idempotente: delete por archivo) ──
delete from bank_deposits where archivo='airbnb_julio.csv';
delete from airbnb_tx where archivo='airbnb_julio.csv';
delete from bank_deposits where archivo='bbva_julio.csv';
delete from airbnb_tx where archivo='bbva_julio.csv';
delete from bank_deposits where archivo='revolut_julio.csv';
delete from airbnb_tx where archivo='revolut_julio.csv';
insert into bank_deposits (banco,iban,fecha,importe,concepto,es_airbnb,archivo) values
  ('revolut','7165','2026-07-31',630.79,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-27',415.98,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-23',494.05,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-21',554.02,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-20',638.58,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-17',591.46,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-16',369.74,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-14',252.19,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-13',536.46,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-13',610.3,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-10',431.17,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-08',452.38,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-06',517.45,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-06',548.89,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('revolut','7165','2026-07-01',828.61,'AIRBNB PAYMENTS',true,'revolut_julio.csv'),
  ('bbva','8920','2026-07-31',311.75,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-27',677.92,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-23',744.44,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-20',351.38,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-20',533.93,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-14',772.97,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-10',1265.7,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-08',204.41,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-06',559.77,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-06',474.47,'ABONO TRANSFERENCIA',true,'bbva_julio.csv'),
  ('bbva','8920','2026-07-01',876.07,'ABONO TRANSFERENCIA',true,'bbva_julio.csv');
insert into airbnb_tx (tipo,fecha,fecha_llegada,confirmation_code,iban,alojamiento,inicio,fin,noches,cobrado,importe,comision_servicio,limpieza,bruto,anio_fiscal,archivo) values
  ('Payout','2026-07-31','2026-08-07',null,'8920',null,null,null,null,243.93,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-31',null,'HMHWDE4TJC',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-30','2026-08-01',2,null,243.93,56.31,50.0,300.24,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-30','2026-08-06',null,'7165',null,null,null,null,630.79,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-30',null,'HMXHRBB4CM',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-29','2026-08-02',4,null,630.79,145.61,60.0,776.4,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-30','2026-08-06',null,'8920',null,null,null,null,311.75,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-30',null,'HMNEP4NDAW',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-29','2026-08-01',3,null,311.75,71.97,50.0,383.72,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-26','2026-07-31',null,'7165',null,null,null,null,415.98,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-26',null,'HMNNSYWMKX',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-25','2026-07-28',3,null,415.98,96.02,60.0,512.0,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-26','2026-07-31',null,'8920',null,null,null,null,677.92,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-26',null,'HMJMQF5MM2',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-25','2026-07-30',5,null,508.6,117.41,50.0,626.0,2026,'airbnb_julio.csv'),
  ('Reserva','2026-07-26',null,'HMEQQRAQ25',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-25','2026-07-27',2,null,169.32,39.08,50.0,201.62,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-24','2026-07-29',null,'8920',null,null,null,null,744.44,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-24',null,'HMXJC53S34',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-21','2026-07-24',3,null,360.16,83.14,50.0,443.3,2026,'airbnb_julio.csv'),
  ('Reserva','2026-07-24',null,'HMWE8SZSD3',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-21','2026-07-25',4,null,384.28,88.72,50.0,473.0,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-24','2026-07-29',null,'7165',null,null,null,null,494.05,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-24',null,'HMMNAD9KDN',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-21','2026-07-25',4,null,494.05,114.05,60.0,608.1,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-21','2026-07-27',null,'7165',null,null,null,null,554.02,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-21',null,'HM4CHSCF9W',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-19','2026-07-23',4,null,554.02,127.88,60.0,681.9,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-18','2026-07-24',null,'8920',null,null,null,null,351.38,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-18',null,'HMS3NTPS8Z',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-17','2026-07-20',3,null,351.38,81.12,50.0,432.5,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-18','2026-07-24',null,'7165',null,null,null,null,638.58,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-18',null,'HM24P82FT3',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-17','2026-07-21',4,null,638.58,147.41,60.0,786.0,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-17','2026-07-24',null,'8920',null,null,null,null,533.93,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-17',null,'HMCY3W2X43',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-16','2026-07-20',4,null,533.93,123.26,50.0,657.2,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-16','2026-07-23',null,'7165',null,null,null,null,591.46,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-16',null,'HMJC4AZQCH',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-15','2026-07-18',3,null,591.46,136.54,60.0,728.0,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-15','2026-07-22',null,'7165',null,null,null,null,369.74,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-15',null,'HM29EYAJKZ',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-14','2026-07-17',3,null,369.74,85.35,60.0,455.1,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-13','2026-07-20',null,'8920',null,null,null,null,772.97,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-13',null,'HMQPRKB5ZW',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-12','2026-07-16',4,null,474.96,109.64,50.0,584.6,2026,'airbnb_julio.csv'),
  ('Reserva','2026-07-13',null,'HMPBJNJATP',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-12','2026-07-16',4,null,298.01,68.79,50.0,354.86,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-13','2026-07-20',null,'7165',null,null,null,null,252.19,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-13',null,'HMJDK2XM89',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-12','2026-07-14',2,null,252.19,58.21,60.0,300.3,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-12','2026-07-17',null,'7165',null,null,null,null,536.46,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-12',null,'HMQ2BQTACP',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-11','2026-07-15',4,null,536.46,123.84,60.0,660.3,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-10','2026-07-17',null,'7165',null,null,null,null,610.3,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-10',null,'HMEC9JWQMQ',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-09','2026-07-12',3,null,610.3,140.89,60.0,751.2,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-09','2026-07-16',null,'8920',null,null,null,null,1265.7,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-09',null,'HMKX3MFNQR',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-08','2026-07-12',4,null,657.76,151.84,50.0,809.6,2026,'airbnb_julio.csv'),
  ('Reserva','2026-07-09',null,'HM8WC4FKEN',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-08','2026-07-11',3,null,607.94,140.34,50.0,748.28,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-09','2026-07-16',null,'7165',null,null,null,null,431.17,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-09',null,'HMAR2NZZNZ',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-08','2026-07-11',3,null,431.17,99.53,60.0,530.7,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-07','2026-07-14',null,'7165',null,null,null,null,452.38,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-07',null,'HMNBCBJFTY',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-06','2026-07-09',3,null,452.38,104.42,60.0,556.8,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-07','2026-07-14',null,'8920',null,null,null,null,204.41,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-07',null,'HMKB48T4DZ',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-06','2026-07-08',2,null,204.41,47.19,50.0,251.6,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-05','2026-07-10',null,'7165',null,null,null,null,517.45,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-05',null,'HMHNMMW39Z',null,'Piscina & Diseño. Corazón Sevilla – Feria/Alameda','2026-07-04','2026-07-07',3,null,517.45,119.45,60.0,636.9,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-05','2026-07-10',null,'8920',null,null,null,null,474.47,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-05',null,'HMP3JAQS9W',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-04','2026-07-07',3,null,474.47,109.53,50.0,584.0,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-04','2026-07-10',null,'7165',null,null,null,null,548.89,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-04',null,'HMC3BSK4N3',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-03','2026-07-06',3,null,548.89,126.71,60.0,675.6,2026,'airbnb_julio.csv'),
  ('Payout','2026-07-03','2026-07-10',null,'8920',null,null,null,null,559.77,null,null,null,null,null,'airbnb_julio.csv'),
  ('Reserva','2026-07-03',null,'HMRHHKBB5Y',null,'Stag Properties Plaza Mayor/La Latina, Apartmen...','2026-07-02','2026-07-06',4,null,559.77,129.23,50.0,689.0,2026,'airbnb_julio.csv');

-- ── 2) Events de julio (19; suma −3.164,46; idempotente por anio/mes/propiedad/concepto) ──
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, v.cat, v.concepto, v.importe, v.notas
from (values
  (2026, 7, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -114.88,
   'Ideal Home 24,00 + Ferr. Diego Leon 9,50 + Ferr. Hoyos 42,60 + Amazon 8,99 + Amazon 29,79. Extracto Revolut julio. SIN los DIA de Madrid (desde julio se reparten entre los 3 pisos de Madrid, regla de Stag 10/08/2026). Los 2 Amazon pendientes de cruzar con la lista de bolsillo.'),
  (2026, 7, '1A_NICA', 'OTROS', 'DIA Madrid (reparto 1/3 pisos Madrid)', -25.17,
   'Dia Madrid 9838 37,94 + Mp Dia 16110 37,55 (03/07, tarjeta Metal de Stag; Stag confirmo Madrid el 10/08) = 75,49 en tercios — regla nueva de Stag 10/08/2026: el DIA de Madrid va a los 3 pisos de Madrid. NICA lleva el centimo del redondeo. OJO: en junio los 39,71 de Dia Madrid fueron 100% a NICA (event 72) — pendiente decidir si se corrige.'),
  (2026, 7, '4B_ALEX', 'OTROS', 'DIA Madrid (reparto 1/3 pisos Madrid)', -25.16,
   'Tercio del DIA Madrid de julio (75,49 = 37,94 + 37,55). Regla de Stag 10/08/2026. Ver nota del event gemelo de NICA.'),
  (2026, 7, '3G_MARE', 'OTROS', 'DIA Madrid (reparto 1/3 pisos Madrid)', -25.16,
   'Tercio del DIA Madrid de julio (75,49 = 37,94 + 37,55). Regla de Stag 10/08/2026. Ver nota del event gemelo de NICA.'),
  (2026, 7, '1A_NICA', 'OTROS', 'IBI (PAC 2026 + fraccionamiento 2025)', -354.96,
   'BBVA 06/07: Ayuntamiento de Madrid 243,93 (PAC 2026) + 111,03 (fraccionamiento 2025). Precedentes: events 45 (ene) y 48 (abr). Proximas cuotas: octubre 112,13 y PAC final 15/12.'),
  (2026, 7, '1A_NICA', 'OTROS', 'Comunidad extra', -31.25,
   'C.P. Segovia 8, recibo chico, BBVA 03/07 (precedentes: mar -34,25, may -30,25).'),
  (2026, 7, '1A_NICA', 'OTROS', 'Trastero Box2box — alta y desvío vs provisión', -58.80,
   'Julio real 88,80 (44,90 + 9,00 + 34,90; alta con gestion 30 y premium 3,90/cuota) vs 30,00 provisionados en listings.extras. Plan anual (Stag 10/08): 5 cuotas a 34,90/4 semanas (-50%), despues 65,90/4 semanas (~71/mes) — aviso cargado para dic-2026. La provision NO se toca (moveria meses ya auditados): el desvio va por event en cada cierre.'),
  (2026, 7, '4B_ALEX', 'SUMINISTROS', 'Agua (reembolso a Alberto, recibo 1-765)', -43.72,
   'Revolut 05/07. Cierra el item del relevamiento (el importe era desconocido). Precedentes: events 93 (ene) y 94 (mar).'),
  (2026, 7, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -5.00,
   'Revolut 18/07 (junio: -16,00, event 73).'),
  (2026, 7, '1A_JACO', 'OTROS', 'Amenities/consumibles Sevilla (DIA, real)', -26.84,
   'Dia Sevilla 2271, Revolut 18/07, tarjeta Standard de Jose (regla migracion 048; junio -44,17, event 102).'),
  (2026, 7, '1A_JACO', 'OTROS', 'Amenities Natura Sevilla Nervión', -20.05,
   'Natura Nervion 06/07, tarjeta Standard de Jose (precedente: feb Natura Sierpes -33,80, event 91).'),
  (2026, 7, '1A_JACO', 'OTROS', 'Toallas/ropa de cama (Fc SM 87)', -140.00,
   'Revolut 16/07 a Jesus Esteban Munoz Romera. Stag confirmo el 10/08: 8 toallas de lavabo + 8 de ducha color chocolate para Jacobine; partida COMPLETA de toallas/ropa de cama 2025+julio, no vienen mas pagos. Las asume Samavi (no refacturable a la duena).'),
  (2026, 7, '1A_JACO', 'OTROS', 'Limpieza puntual vía app (Webel, prueba de suplente)', -28.75,
   'Revolut 25/07. Stag 10/08: limpieza puntual contratada por app en Sevilla, probando reemplazo para las vacaciones de Jose. NO es el arreglo de los danos de junio. Fuera de la cuota fija de 700 refacturada a la duena: coste de Samavi.'),
  (2026, 7, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -55.14,
   'Mr Way 18,60 + Uber Eats 15,70 + 20,84. Extracto Revolut julio (junio: -167,26, event 74).'),
  (2026, 7, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Auriculares oficina (Amazon, plazo 2/3)', -145.80,
   'Amazon.es 24/07, identico al plazo 1/3 de junio (event 96). Herramienta de trabajo -> overhead operativo, NO compras hogar. La cuota 3/3 caera en el extracto de agosto.'),
  (2026, 7, 'SAMAVI_GEN', 'CORPORATIVO', 'Transporte (real bancos)', -136.34,
   'Iryo 30,18 + Iryo 49,87 + Renfe 37,35 + Uber 24,19 - reembolso 5,25. Regla del 26/07: el transporte del dia a dia nunca va a la propiedad (junio: event 115).'),
  (2026, 7, 'SAMAVI_GEN', 'CORPORATIVO', 'Viajes tarjeta (Enterprise + E.S. Alovera)', -470.06,
   'Tarjeta 0084: Enterprise 384,76 + E.S. Alovera 85,30. El adeudo de la tarjeta caera en el BBVA de AGOSTO y alli se IGNORA (mismo patron que el adeudo 66,04 del 03/07 = event 67 de junio).'),
  (2026, 7, 'SAMAVI_GEN', 'CORPORATIVO', 'BLT Law — honorarios (Fc 2025/386)', -1391.50,
   'Revolut julio. CORPORATIVO (migracion 025: BLT no se prorratea). FACTURA POR IDENTIFICAR con Stag: numeracion 2025 pagada en julio.'),
  (2026, 7, 'SAMAVI_GEN', 'CORPORATIVO', 'BLT Law — legalización libros 2024 (Fc 2026/364)', -65.88,
   'Revolut 06/07. Gasto societario.')
) as v(anio, mes, cod, cat, concepto, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes
     and e.propiedad_codigo = v.cod and e.concepto = v.concepto
);

-- ── 3) Aviso: fin del descuento de Box2box (dic-2026) ────────────────────────────────
insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '1A_NICA', date '2026-12-01', 'promocion',
       'Se agotan las 5 cuotas al −50 % del trastero Box2box: pasa de 34,90 a 65,90 €/4 semanas (~71 €/mes)',
       -33.58,
       'Plan anual contratado en julio 2026 (condiciones pasadas por Stag el 10/08): 5 cuotas a 31,00 + 3,90 de premium = 34,90 por 4 semanas; al agotarse, tarifa estandar 62,00 + 3,90 = 65,90/4 semanas = 71,39/mes prorrateado (hoy 37,81). Provision en listings.extras: 30/mes — el desvio se carga por event en cada cierre. Decidir si se mantiene el trastero (entrega final al terminar: 65). La fecha es estimada: confirmar con el cargo Revolut de la 5a cuota.'
where not exists (
  select 1 from avisos a
   where a.codigo = '1A_NICA' and a.tipo = 'promocion' and a.fecha = date '2026-12-01'
);
