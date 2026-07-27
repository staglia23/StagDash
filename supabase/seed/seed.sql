-- seed.sql — generado por scripts/excel_to_seed.py (NO editar a mano)
-- Fuente: STAG SAMAVI — Dashboard 2026.xlsx · hoja '⚙️ Parámetros'
begin;
truncate table events, general_expenses, listings restart identity cascade;

insert into listings (codigo, listing_nickname, ciudad, banco, modelo, fecha_inicio,
  renta_base, comision_pct, iva_pct, irpf_pct, limpieza_por_reserva, suministros_mes,
  comunidad_ibi_mes, minut, akiles, amenities, pricelabs, guesty_fee, extras,
  mobiliario_fin, propietario, nif, iban, pasivo_base) values
  ('1A_NICA', 'MAD_NICASIO', 'Madrid', 'Revolut', 'titular', '2024-06-01', 0.0, 0.0, 0.0, 0.0, 53.72, 215.0, 402.78, 7.81, 6.05, 80.0, 13.91, 33.0, 0.0, 0.0, '—', 'n/a', 'n/a', 0.0),
  ('4B_ALEX', 'MAD_ALEXANDER', 'Madrid', 'BBVA', 'subarriendo', '2025-10-01', 1414.22, 0.0, 0.21, 0.19, 43.8, 145.0, 0.0, 7.81, 6.05, 80.0, 13.91, 30.0, 0.0, 162.77, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 0.0),
  ('3G_MARE', 'MAD_MARECHAL', 'Madrid', 'BBVA', 'subarriendo', '2025-12-01', 1100.0, 0.0, 0.21, 0.19, 43.8, 125.0, 0.0, 7.81, 6.05, 80.0, 13.91, 30.0, 0.0, 0.0, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 0.0),
  ('1A_JACO', 'SEV_JACOBINE', 'Sevilla', 'Revolut', 'comision', '2025-06-01', 0.0, 0.3025, 0.0, 0.0, 0.0, 10.79, 0.0, 7.81, 0.0, 0.0, 13.91, 30.0, 12.55, 0.0, 'PENDIENTE', 'PENDIENTE', 'PENDIENTE', 20985.83);

insert into general_expenses (concepto, importe_mes) values
  ('Asesor Confisic', 181.5),
  ('Seguro RC', 18.25),
  ('Hostinger', 12.74),
  ('Google Workspace', 15.94),
  ('Revolut Business cuota', 43.0),
  ('Sueldo Stag bruto', 3333.33),
  ('TGSS RETA Stag', 370.75),
  ('Claude.ai', 200.0),
  ('Comisión Revolut', 43.0),
  ('Viajes corporativos', 50.0),
  ('Otros AEAT/admin', 50.0);

-- Brand Partners: 500 €/mes desde may-2026 hasta nuevo aviso (sin setup; fix 16/07/2026).
-- Requiere las columnas de vigencia de la migración 010 (desde/hasta).
insert into general_expenses (concepto, importe_mes, desde) values
  ('Brand Partners (marketing)', 500.0, date '2026-05-01');

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, 'ene-mar 2026'),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 5, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'crédito termo Alberto mayo'),
  (2026, 6, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'crédito termo Alberto junio'),
  (2026, 5, '3G_MARE', 'RENTA', 'Plan AA mayo (renta total descontada)', 1100.0, 'renta efectiva 0'),
  (2026, 6, '3G_MARE', 'RENTA', 'Plan AA junio (prorrata)', 500.0, 'renta efectiva 600'),
  (2026, 11, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, '1.614,80 - 1.414,22'),
  (2026, 12, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, NULL),
  (2026, 1, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, 'financiación ene-oct 2026'),
  (2026, 2, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 3, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 4, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 5, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 6, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 7, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 8, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 9, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 10, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 1, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 2, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 3, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 4, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 5, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 6, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 7, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 8, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 9, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 10, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 12, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi');

commit;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SYNC PRODUCCIÓN 17/07/2026 — estado CONCILIADO contra Revolut + BBVA + tarjeta
-- (ene–jun 2026). Sustituye los valores de arriba; fuente de verdad = producción.
-- ═══════════════════════════════════════════════════════════════════════════════

update listings set suministros_mes = 150, comunidad_ibi_mes = 331.12, amenities = 30,
  guesty_fee = 30, extras = 30 where codigo = '1A_NICA';           -- extras = trastero Box2box
update listings set suministros_mes = 150, amenities = 30 where codigo = '4B_ALEX';
update listings set amenities = 30 where codigo = '3G_MARE';
update listings set suministros_mes = 0, amenities = 34.58, extras = 0 where codigo = '1A_JACO';

delete from general_expenses;
insert into general_expenses (concepto, importe_mes, desde, hasta) values
  ('Sueldo Stag bruto', 3333.33, NULL, NULL),
  ('Brand Partners (marketing)', 500.00, date '2026-05-01', NULL),   -- efectivo/Argentina: no sale en bancos
  ('TGSS RETA Stag', 370.75, NULL, NULL),
  ('Orange (fibra pisos + dispositivos)', 329.80, NULL, NULL),       -- promedio real ene–jun
  -- 'Viajes corporativos (transporte)' eliminado 25/07: fantasma; los viajes reales entran como eventos
  ('Asesor Confisic', 181.50, NULL, NULL),
  ('Claude.ai (plan 90)', 90.00, date '2026-06-01', NULL),
  -- 'Otros AEAT/admin' eliminado 25/07: fantasma; los gastos reales entran como eventos conciliados
  ('Revolut Business cuota', 43.00, NULL, NULL),
  ('Seguro vida préstamo (Allianz 499,51/año)', 41.63, date '2026-05-01', NULL),
  ('Seguro RC', 18.25, NULL, NULL),
  ('Google Workspace', 15.94, NULL, NULL),
  ('Hostinger', 12.74, NULL, NULL);                                  -- pago anual 152,87 (feb) devengado

delete from events;
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 1, '1A_NICA', 'OTROS', 'Comunidad extra + Ayuntamiento (IBI plazos)', -385.09, '32,32+243,94+108,83'),
  (2026, 1, '1A_NICA', 'OTROS', 'Mobiliario aplazado (Paypal 3 plazos)', -105.82, NULL),
  (2026, 1, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, 'financiación ene-oct 2026'),
  (2026, 1, '4B_ALEX', 'OTROS', 'Termo eléctrico (J.E. Cabrera)', -450.00, 'confirmado Stag 17/07: es de Alexander (compra enero, distinta del Ariston/Obramat de abril compensado por Alberto)'),
  (2026, 1, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, 'ene-mar 2026'),
  (2026, 2, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 2, '1A_NICA', 'OTROS', 'Derrama forjado 50% (Segovia 8)', -765.00, 'recibo 25/02'),
  (2026, 2, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'BLT Law — 6ª y última cuota gestores anteriores', -584.89, 'deuda saldada, no se repite'),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viajes tarjeta (ITA/Booking/Iberia)', -1447.64, 'tarjeta 0084, adeudo 05/03'),
  (2026, 3, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 3, '1A_NICA', 'OTROS', 'Comunidad extra', -34.25, NULL),
  (2026, 3, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -20.00, 'barrido 17/07'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Orange amortización equipos (tarjeta)', -460.78, 'payoff dispositivos, no está en la línea mensual'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Sequra', -304.34, NULL),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Servicio digital web (N. Casale)', -159.60, 'puntual'),
  (2026, 3, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viaje por carretera (Hertz/hotel/gasolina/peajes)', -600.73, 'tarjeta 0084, adeudo 06/04'),
  (2026, 4, '1A_JACO', 'OTROS', 'Mantenimiento termo Ariston (Concesionario)', -258.94, 'cuota mantenimiento'),
  (2026, 4, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 4, '1A_NICA', 'OTROS', 'IBI/tributos NRC + Ayuntamiento', -1141.60, '1.031,67+109,93'),
  (2026, 4, '3G_MARE', 'OTROS', 'Aire acondicionado (Nico Chaban, Fc 235)', -1754.50, 'compensado vía descuentos de renta may/jun'),
  (2026, 4, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 4, '4B_ALEX', 'OTROS', 'Termo Ariston 4B (Obramat + instalación, neto IVA)', -383.06, 'compensado 383,06 por Alberto vía facturas may/jun (mail 18/05)'),
  (2026, 4, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -219.22, '38,25+82,29+98,68'),
  (2026, 5, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 5, '1A_NICA', 'OTROS', 'Comunidad extra', -30.25, NULL),
  (2026, 5, '3G_MARE', 'RENTA', 'Plan AA mayo (renta total descontada)', 1100.00, 'renta efectiva 0'),
  (2026, 5, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 5, '4B_ALEX', 'RENTA', 'Termo descuento renta', 191.53, 'termo 1/2: crédito base 191,53 (efecto caja 195,36 con IVA/IRPF); pagado 1.222,69'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Asesoría laboral (J.A. Mateos)', -159.00, 'consulta puntual'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Claude/Anthropic (real bancos)', -110.59, '20,59+90,00'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Curso fiscalidad (Hotmart)', -747.04, 'formación empresa'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Notaría escritura préstamo (Herrand)', -379.26, 'gasto del préstamo prefabricada'),
  (2026, 6, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 6, '1A_NICA', 'OTROS', 'Forjado pago 1/2', -382.50, 'recibo 24/06'),
  (2026, 6, '3G_MARE', 'RENTA', 'Plan AA + compensación aire acondicionado (renta pagada: 365,50)', 734.50, 'renta efectiva 600'),
  (2026, 6, '3G_MARE', 'OTROS', 'Refacturación 50% inscripción registral', -218.22, 'a J.L. De La Torre 19/06'),
  (2026, 6, '4B_ALEX', 'OTROS', 'Klarna-Sklum cancelación anticipada mobiliario', -472.28, 'salda jul–oct (4×162,77=651,08) con descuento; confirmado Stag 17/07'),
  (2026, 6, '4B_ALEX', 'OTROS', 'Mobiliario Klarna-Sklum', -162.77, NULL),
  (2026, 6, '4B_ALEX', 'RENTA', 'Termo descuento renta', 199.19, 'termo 2/2 + ajuste técnico -3,83 regularizado; pagado 1.215,03'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Intereses préstamo BBVA (prefabricada)', -158.45, 'amortización 923,78 excluida: devolución de deuda'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Viajes tarjeta (Enjoy Travel)', -66.04, 'adeudo esperado jul'),
  (2026, 7, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 7, '1A_NICA', 'OTROS', 'Forjado pago 2/2', -382.50, 'confirmado Stag; verificar en extracto jul'),
  (2026, 8, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 9, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 10, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 11, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, '1.614,80 - 1.414,22; desde nov queda 1.614,80 hasta nuevo aviso'),
  (2026, 12, '1A_JACO', 'OTROS', 'Modesto neto (sueldo+TGSS-refactura)', 11.67, '484+204,33-700, a favor Samavi'),
  (2026, 12, '4B_ALEX', 'RENTA', 'Renta sube Q4', -200.58, NULL);
-- ═══ AJUSTES 21/07/2026 — clasificación del bucket de compras (decisión Stag) ═══
-- 1) Compras hogar/reposición de los pisos → TODO a Nicasio (eventos reales por mes).
--    Amazon + Día Madrid + Ideal Home + ferretería + Zara Home + El Corte Inglés + etc.
--    Barrido 23/07/2026: cargos <20€ ene–may incorporados (ene nuevo; mar/abr ampliados).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -50.01, 'Día Madrid 17,23 + Mp Día 16,89 + Ikea 15,89; barrido 23/07'),
  (2026, 2, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -226.05, 'Amazon 75,80 + Ideal Home 20,45 + Ferretería 46,30 + flores 83,50'),
  (2026, 3, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -162.33, 'Amazon 129,98 + Día Madrid 21,64 + Día Madrid 10,71 (barrido 23/07)'),
  (2026, 4, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -374.41, 'Amazon 34,41 + Zara Home 178,05 + Rituals 50,90 + Velas 33,90 + Mm 26,90 + barrido 23/07: Día Madrid 16,92 + Home Ideal 13,95 + Casa Soria 10,04 + Ferretería Hoyos 9,34'),
  (2026, 5, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -424.46, 'Amazon 160,93 + El Corte Inglés 128,90 + Día Madrid 76,90 + H&M 29,98 + Ideal Home 27,75'),
  (2026, 6, '1A_NICA', 'OTROS', 'Compras hogar/reposición pisos (real bancos)', -813.15, 'Amazon 731,00 + Día Madrid 39,71 + Ideal Home 15,95 + Bricochayta 16,50 + Hiperhogar 9,99');

-- 2) La provisión de amenities de los pisos de Madrid se reemplaza por lo real (arriba):
--    a 0 para no contar dos veces. Jacobine mantiene su 34,58 (Día SEVILLA, ya separado).
update listings set amenities = 0 where codigo in ('1A_NICA', '4B_ALEX', '3G_MARE');

-- 3) Lavandería My Laundry = secadas de José Modesto para Jacobine.
--    Serie ene–jun completa (barrido 23/07); enero sin cargos.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 2, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -4.50, '4,50; barrido 23/07'),
  (2026, 3, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -9.00, '4,50+4,50; barrido 23/07'),
  (2026, 4, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -8.00, '4,50+3,50; barrido 23/07'),
  (2026, 5, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -13.00, '4,50+3,50+5,00; barrido 23/07'),
  (2026, 6, '1A_JACO', 'OTROS', 'Lavandería My Laundry (José Modesto)', -16.00, '6+6+4; serie ene–jun completa (ene sin cargos)');

-- 3b) Dudas del barrido resueltas por Stag 23/07: ambas a Jacobine.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 1, '1A_JACO', 'OTROS', 'Papelería carteles instructivos (Folder)', -4.00, 'material carteles del piso, impreso por Stag con tarjeta de José; confirmado Stag 23/07'),
  (2026, 2, '1A_JACO', 'OTROS', 'Amenities Natura Sevilla Sierpes', -33.80, 'compra puntual amenities; confirmado Stag 23/07');

-- 4) Comidas de negocio (Uber Eats/Glovo/restaurantes) → gasto general.
--    Serie ene–jun completa (barrido 23/07); ene/mar/abr sin cargos ("Licencia 431" es taxi, MCC 4121).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -37.69, 'Uber Eats 16,74 + Café Bistro Nuncio 4,35 + Mina Coffee 16,60; barrido 23/07'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -15.38, 'Uber Eats 15,38; barrido 23/07'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -167.26, 'Uber Eats 45,22 + Glovo 13,54 + Irish Rover 25 + Pavlov 13,50 + Campo Simbólico 70; serie ene–jun completa (ene/mar/abr sin cargos, Licencia 431 es taxi)');


-- 048 — amenities reales de Jacobine. Era la última línea estimada del semestre: 34,58 €/mes de
-- provisión fija heredados del modelo pre-auditoría (a las otras tres, la 031 les puso el dato
-- real de Ecocleans y les dejó la línea en cero; Jacobine quedó fuera porque la limpia José
-- Modesto, que compra los amenities él mismo). Relevamiento de los 6 extractos de Revolut
-- ene–jun filtrando DIA Sevilla 2271 y Mp**dia 22144: 175,44 € reales contra 207,48 € de
-- provisión. El total sobra 32,04 € pero el mes a mes estaba muy mal — enero y febrero no
-- tuvieron ni una compra y cargaban 34,58 cada uno; marzo gastó casi el doble. Además febrero
-- contaba dos veces: la compra real (Natura Sierpes, 33,80) ya era un evento y la provisión iba
-- encima. Mismo criterio que 031 y 034: provisión a cero, gasto real como evento mensual.
update listings set amenities = 0 where codigo = '1A_JACO';

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, '1A_JACO', 'OTROS', 'Amenities/consumibles Sevilla (DIA, real)', v.importe, v.notas
from (values
  (2026, 3, -67.53, 'Dia Sevilla 2271 45,94 del 02/03 (tarjeta Metal) + Mp**dia 22144 5,54 del 10/03 y 16,05 del 28/03 (tarjeta Standard de Jose Modesto). Extracto Revolut marzo 2026.'),
  (2026, 4, -28.92, 'Mp**dia 22144 10,19 del 12/04 + Dia Sevilla 2271 18,73 del 20/04, tarjeta Standard de Jose Modesto. Extracto Revolut abril 2026.'),
  (2026, 5, -34.82, 'Mp**dia 22144 4,54 del 01/05 + Dia Sevilla 2271 30,28 del 11/05, tarjeta Standard de Jose Modesto. Extracto Revolut mayo 2026.'),
  (2026, 6, -44.17, 'Dia Sevilla 2271 9,68 y 5,79 del 31/05 + 28,70 del 25/06, tarjeta Standard de Jose Modesto. Extracto Revolut junio 2026 (los cargos del 31/05 aparecen en el extracto de junio).')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Amenities/consumibles Sevilla (DIA, real)');

update events
   set notas = 'Natura Sevilla Sierpes 33,80 del 27/02, tarjeta Metal. Confirmado Stag 23/07. Es el UNICO gasto de amenities de febrero: hasta la migracion 048 convivia con la provision fija de 34,58, o sea que el mes contaba 68,38 habiendo gastado 33,80.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Amenities Natura Sevilla Sierpes';


-- 049 — recobros a la dueña de Jacobine y gastos de bolsillo fuera de banco (26/07/2026).
-- 1) El mini UPS y la copia de llaves salen de las compras de hogar de Nicasio de febrero.
--    Quedan los 18,81 de la pasta de dientes + Ideal Home 20,45 + flores 83,50 = 122,76.
update events
   set importe = -122.76,
       notas   = 'Amazon 18,81 (pasta de dientes, 15/02) + Ideal Home 20,45 + Mon Parnasse flores 83,50. Salieron dos cosas que no eran de Nicasio: los 56,99 del Amazon del 12/02 eran el mini UPS de JACOBINE (56,99 + 20,00 de instalacion de Agustin = 77,00 que se le descontaron a la duena en su cuenta corriente, o sea coste neutro para Samavi), y los 46,30 de Ferreteria Diego de Leon eran la copia de llaves de JACOBINE segun la lista de gastos de bolsillo de Stag. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 2
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -226.05;

-- 2) La aspiradora sale de las compras de hogar de Nicasio de marzo.
--    Quedan los dos Día de Madrid: 21,64 + 10,71 = 32,35.
update events
   set importe = -32.35,
       notas   = 'Dia Madrid 21,64 + Dia Madrid 10,71. Los 129,98 del Amazon del 28/02 (liquidado el 01/03) eran la ASPIRADORA de JACOBINE: figura en la cuenta corriente de la duena como GASTOS 130,00 de marzo con la nota "aspiradora reposicion", o sea que Samavi ya se la cobro. Coste neutro: sale del P&L. Auditoria 26/07/2026.'
 where propiedad_codigo = '1A_NICA' and anio = 2026 and mes = 3
   and concepto = 'Compras hogar/reposición pisos (real bancos)'
   and importe = -162.33;

-- 3) La copia de llaves entra en Jacobine, que es donde se usó.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, '1A_JACO', 'OTROS', 'Copia de llaves (Ferretería Diego de León)', -46.30,
       'Cargo de 46,30 del 17/02 en el Revolut, tarjeta Metal. Estaba imputado a Nicasio por el barrido bancario del 23/07 (ferreteria de Madrid = compra de hogar de Madrid); la lista de gastos de bolsillo de Stag lo tiene en la columna de JACOBINE, "19/02/2026 copia de llaves". No se le descontó a la duena.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'Copia de llaves (Ferretería Diego de León)');

-- 4) Lo pagado en efectivo, que nunca pasó por el banco.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, 'OTROS', v.concepto, v.importe, v.notas
from (values
  (2026, 1, '3G_MARE', 'Cristales (Claudio, efectivo)', -60.00,
   'Lista de gastos de bolsillo de Stag, "02/01/2026 cristales claudio". Claudio es el portero de Segovia 8. Pagado en efectivo, no pasa por el extracto: por eso el motor no lo veia. Tercer pago en efectivo a Claudio que aparece tarde (los otros 80,00 entraron por la migracion 044).'),
  (2026, 3, '3G_MARE', 'Arreglo de bañera (Claudio, efectivo)', -150.00,
   'Lista de gastos de bolsillo de Stag, "03/03/2026 arreglo banera claudio". Pagado en efectivo, sin factura, fuera del extracto.'),
  (2026, 2, '1A_NICA', 'NRUA — registro único de alojamiento', -32.73,
   'Lista de gastos de bolsillo de Stag, "24/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 2, '4B_ALEX', 'NRUA — registro único de alojamiento', -28.67,
   'Lista de gastos de bolsillo de Stag, "25/02/2026 NRUA registro". No aparece en el Revolut de febrero.'),
  (2026, 1, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -28.57,
   'Lista de gastos de bolsillo de Stag: "09/01/2026 amenities 28,57". Fuera del extracto. NO duplica la migracion 048, que solo cargo los cargos de DIA Sevilla del Revolut y enero no tenia ninguno. En la misma fecha hay 9,00 de "secadas diciembre" que NO se cargan: el devengo es de diciembre de 2025 y el motor esta fijado al ano en curso.'),
  (2026, 2, '1A_JACO', 'Gastos de bolsillo (fuera de banco)', -53.65,
   'Lista de gastos de bolsillo de Stag: ILSA 30,65 (menaje, 27/02) + amenities 10,00 (27/02) + secadas 8,50 (27/02) + secadas de enero 4,50 (pagadas el 05/02). Ninguno pasa por el extracto. La secada de 4,50 del 27/02 SI esta en el banco y ya estaba cargada aparte, no se repite aca.')
) as v(anio, mes, cod, concepto, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = v.cod
     and e.concepto = v.concepto);


-- 050 — dos respuestas de Stag rompen la 049: las secadas de su lista de bolsillo son la MISMA
-- plata que los cargos My Laundry del Revolut (estaban duplicadas, 13,00 €), e "ILSA" no era
-- menaje sino la operadora de los trenes iryo, o sea transporte → overhead corporativo.
-- 1) El evento de bolsillo de febrero se queda sólo con los amenities.
update events
   set importe  = -10.00,
       notas    = 'Amenities 10,00 del 27/02, de la lista de gastos de bolsillo de Stag; fuera del extracto. Salieron dos cosas que la 049 habia metido mal: las secadas (8,50 + 4,50) son la MISMA plata que los cargos My Laundry del Revolut que ya estaban cargados aparte —confirmado por Stag el 26/07, estaban duplicadas— y los 30,65 de "ILSA" no eran menaje sino un billete de tren de iryo (ILSA = Intermodalidad del Levante SA), que va al overhead corporativo, no a la propiedad.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 2
   and concepto = 'Gastos de bolsillo (fuera de banco)'
   and importe = -53.65;

-- 2) El billete de iryo entra al overhead corporativo, que es donde Stag quiere el transporte.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 2, 'SAMAVI_GEN', 'CORPORATIVO', 'Tren iryo a Sevilla (ILSA, fuera de banco)', -30.65,
       'Lista de gastos de bolsillo de Stag, "27/02/2026 ILSA 30,65". ILSA = Intermodalidad del Levante SA, la operadora de iryo: es un billete de tren, confirmado por Stag el 26/07. No aparece en el extracto de febrero, o sea que se pago por fuera de la cuenta. Estaba imputado a Jacobine por la migracion 049 leyendo ILSA como marca de menaje.'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 2 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Tren iryo a Sevilla (ILSA, fuera de banco)');


-- 051 — el transporte del día a día entra uno a uno. La migración 024 borró la provisión de
-- 200 €/mes creyendo que era un fantasma, pero el barrido del 23/07 no había cargado los taxis
-- precisamente PORQUE esa línea los cubría: quedaron sin provisión y sin evento (1.389,84 € en el
-- semestre, más que los 1.200 que habría provisionado). Stag confirma que son todos de empresa y
-- que no se vuelve a provisionar. Van a CORPORATIVO, así que no mueven la rentabilidad por piso.
-- Segunda parte: marca de procedencia en los seis apuntes que descansan solo en la planilla manual.
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, 'SAMAVI_GEN', 'CORPORATIVO', 'Transporte (real bancos)', v.importe, v.notas
from (values
  (2026, 2, -332.34,
   'Iryo 83,77 (09/02) + SBB Suiza 86,59 y 106,33 (25/02) + Renfe 38,75 (26/02) + Uber 8,96 y 7,94 (27/02). Extracto Revolut febrero 2026. Todos confirmados como gasto de empresa por Stag el 26/07.'),
  (2026, 3, -786.29,
   'Cabify 6,96 (02/03) + Uber 20,95 (08/03) + Licencia 431 (taxi) 12,30 (16/03) + Uber 9,93, 20,91 y 13,90 (17/03) + iryo 87,63 y Uber 14,96 (19/03) + iryo 103,96 y Vueling 135,66 (23/03) + iryo 54,26 (25/03) + Vueling 311,09, FreeNow 8,00 y Uber 23,95 (26/03) + Uber 14,95 (27/03) = 839,41 brutos, MENOS el reembolso de iryo de 53,12 liquidado el 01/03. Extracto Revolut marzo 2026.'),
  (2026, 4, -201.37,
   'Iryo 149,59 y Uber 8,96 (liquidados el 01-02/04, iniciados el 31/03) + Uber 6,94 (01/04) + Uber 10,93 y 8,00 (04/04) + Uber 16,95 (13/04). Extracto Revolut abril 2026.'),
  (2026, 5, -16.93,
   'Uber 16,93 (29/05). Unico cargo de transporte del mes. Extracto Revolut mayo 2026.'),
  (2026, 6, -52.91,
   'Cabify 22,99 (10/06) + Uber 13,93 (24/06) + Cabify 15,99 (28/06). Extracto Revolut junio 2026.')
) as v(anio, mes, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Transporte (real bancos)');

-- ── Y UNA MARCA DE PROCEDENCIA ──────────────────────────────────────────────────────
-- Stag avisó el 26/07 de que la planilla manual que pasó es como se manejaba ANTES del dashboard y
-- puede tener errores: hay que contrastar contra documentación real o contra su confirmación, no
-- asumir. Revisadas las cargas de la migración 049 una por una, seis apuntes descansan SÓLO en esa
-- planilla — no hay cargo bancario ni factura detrás, porque se pagaron en efectivo o por fuera:
--
--   3G_MARE  ene   60,00   cristales (Claudio)
--   3G_MARE  mar  150,00   arreglo de bañera (Claudio)
--   1A_NICA  feb   32,73   NRUA registro
--   4B_ALEX  feb   28,67   NRUA registro
--   1A_JACO  ene   28,57   amenities
--   1A_JACO  feb   10,00   amenities
--
-- Se quedan cargados —es el criterio de peor caso que el repo ya usa (022, 031, 034, 044)— pero la
-- nota lo dice, para que nadie los lea como conciliados. La reimputación de la copia de llaves
-- (46,30, de Nicasio a Jacobine) también sale de la planilla, aunque el cargo bancario sí existe.

update events
   set notas = notas || ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.'
 where anio = 2026
   and concepto in ('Cristales (Claudio, efectivo)', 'Arreglo de bañera (Claudio, efectivo)',
                    'NRUA — registro único de alojamiento', 'Gastos de bolsillo (fuera de banco)')
   and notas not like '%FUENTE: solo la planilla manual%';

update events
   set notas = notas || ' ⚑ La REIMPUTACION a Jacobine sale solo de la planilla manual de Stag; el cargo bancario si existe. Pendiente de confirmar que la copia de llaves era del piso de Sevilla y no de uno de Madrid.'
 where anio = 2026 and mes = 2 and propiedad_codigo = '1A_JACO'
   and concepto = 'Copia de llaves (Ferretería Diego de León)'
   and notas not like '%REIMPUTACION a Jacobine sale solo%';


-- 052 — la nómina de José verificada contra el BBVA. El TGSS no aparecía en el Revolut porque se
-- paga desde el BBVA: 204,33 en enero y 204,86 de febrero a junio, cargo por cargo. El modelo era
-- correcto — la refactura de limpieza de Jacobine gana, poco pero gana. Se afina a 11,23 (ene) y
-- 11,14 (feb-dic). Y se corrige la marca de la 051 sobre los dos NRUA: sí tienen respaldo bancario,
-- están en el BBVA.
update events
   set importe = 11.23,
       notas   = 'Nomina de enero 484,44 (pagada el 02/02 desde Revolut) + TGSS regimen general 204,33 (cargada el 30/01 en el BBVA) = 688,77, contra los 700 que se le descuentan a la duena. VERIFICADO contra banco el 26/07/2026, ya no es una suposicion.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes = 1
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set importe = 11.14,
       notas   = 'Nomina 484,00 + TGSS regimen general 204,86 = 688,86, contra los 700 que se le descuentan a la duena. La cuota de TGSS subio de 204,33 a 204,86 en febrero y se mantuvo; verificada cargo por cargo en los extractos del BBVA (27/02, 31/03, 30/04, 29/05, 30/06). El cargo de 370,75 que aparece al lado es el RETA de Stag, no el de Jose. VERIFICADO contra banco el 26/07/2026.'
 where propiedad_codigo = '1A_JACO' and anio = 2026 and mes >= 2
   and concepto = 'Modesto neto (sueldo+TGSS-refactura)';

update events
   set notas = replace(notas,
        ' ⚑ FUENTE: solo la planilla manual de Stag, sin respaldo bancario ni factura (pagado en efectivo o por fuera de la cuenta). Cargado por criterio de peor caso; pendiente de documentar.',
        ' ⚑ CORREGIDO 26/07: si tiene respaldo bancario, esta en el BBVA (no en el Revolut, por eso no aparecia): transferencia del 24/02 "F4 510 - NRUA" 32,73 para Nicasio y del 26/02 "F4 - 7784 - NRUA" 28,67 para Alexander.')
 where anio = 2026 and concepto = 'NRUA — registro único de alojamiento';


-- 053 — la renta de Alexander sube el 01/10: se agota la devolución del amoblamiento (3.064 € a
-- 12 meses = 255,31/mes descontados de la base). El coste pasa de 1.677,65 a 1.986,58 €/mes,
-- +3.707 €/año = el 94% del margen anual del piso, y ocurre solo el día que se prorroga el
-- contrato. Va a `avisos` (el mecanismo de la 045). Y se corrige la nota del aviso de contrato:
-- el preaviso de no prórroga es facultad de Alberto (cláusula 2.2), no de Samavi.
insert into avisos (codigo, fecha, tipo, mensaje, impacto_mes, nota)
select '4B_ALEX', date '2026-10-01', 'renta',
       'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.641,80 €/mes',
       -308.93,
       'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste en el modelo: 1.677,65 -> 1.986,58 EUR/mes (+308,93/mes, +3.707/ano), que es el 94% del margen anual de Alexander. OJO: el contrato dice 1.614,80 de renta (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 = 2 mensualidades lo confirma) pero la hoja de trabajo uso 1.641,80: 27 EUR/mes de diferencia que hay que aclarar con Alberto. La palanca es la clausula 4.3, que permite renegociar la contraprestacion cada 12 meses.'
where not exists (
  select 1 from avisos a where a.codigo = '4B_ALEX' and a.fecha = date '2026-10-01' and a.tipo = 'renta');

-- Y el aviso de contrato decía lo que no es: el preaviso NO lo da Samavi.
-- Cláusula 2.2: es LA PROPIEDAD quien puede cortar la prórroga, dentro de los 30 días anteriores
-- al vencimiento (01–30/09/2026). Cláusulas 3.2 y 3.8: Samavi no puede desistir, y las dificultades
-- económicas no son causa mayor. La única puerta de Samavi es la 4.3, renegociar.
-- El detalle vive en este comentario, no en la alerta: se lee en el móvil.
update listings
   set aviso_nota = 'Vence el contrato. Solo Alberto puede cortar la prórroga; la palanca de Samavi es renegociar (cláusula 4.3)'
 where codigo = '4B_ALEX';


-- 054 — la 053 se equivocó dos veces: (a) dijo que el motor no sabía de la subida de renta de
-- Alexander cuando la migración 022 ya la modelaba (events 92/8/9, oct-dic), y (b) usó los
-- 1.641,80 de la hoja de trabajo en vez de los 1.614,80 del contrato. El salto real en términos
-- de coste es +276,26/mes (+3.315/año), no +308,93. El aviso es la capa de ALERTA; el P&L ya lo
-- contaba. Sin doble conteo: `avisos` sólo alimenta v_alertas.
update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: la renta base pasa de 1.386,49 a 1.614,80 €/mes',
       impacto_mes = -276.26,
       nota = 'Samavi amueblo el piso (contrato nº 001/2025, expositivo III: se entrega vacio). El saldo a favor de 3.064,00 EUR se devuelve prorrateado a 12 meses = 255,31/mes descontados de la base imponible, y se agota con la renta de septiembre de 2026. Coste modelado: 1.677,65 -> 1.953,91 EUR/mes (+276,26/mes, +3.315/ano), un 84% del margen anual del piso. El P&L de oct-dic YA lo cuenta desde la migracion 022 (events 92/8/9, -232,88 en terminos de transferencia); este aviso es solo la capa de alerta. PENDIENTE: el contrato dice 1.614,80 (clausula 4.1, en letras y numeros, y la fianza de 3.229,60 lo confirma) pero la hoja de trabajo uso 1.641,80. Si Alberto factura 1.641,80, el salto es 308,93. Confirmarlo antes de renovar. La palanca es la clausula 4.3. Y en enero de 2027 hay que actualizar listings.renta_base: los events de la 022 solo llegan a diciembre.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';


-- 055 — la renta de octubre según el pacto VERBAL con Alberto (Stag, 27/07/2026): Alberto recibe
-- 1.614,80 EN CUENTA → base derivada 1.583,14. Los events del Q4 pasan de −232,88 (lectura literal
-- del contrato) a −200,58, y el aviso a +237,95/mes de coste (+2.855/año). Modela la lectura más
-- favorable por instrucción de Stag; la adenda de octubre debe fijar la cifra por escrito.
-- 1) Los events del Q4 pasan a la transferencia pactada: 1.614,80 − 1.414,22 = 200,58.
update events
   set importe = -200.58,
       notas   = 'Fin del prorrateo del amoblamiento: la transferencia pasa de 1.414,22 a 1.614,80 (pacto VERBAL confirmado por Stag el 27/07/2026: Alberto recibe 1.614,80 en cuenta; base derivada 1.583,14). La 022 habia cargado -232,88 con la lectura literal del contrato (base 1.614,80, transferencia 1.647,10). PENDIENTE la adenda que fije la cifra por escrito: sin ella el contrato permite a Alberto facturar 1.647,10.'
 where propiedad_codigo = '4B_ALEX' and anio = 2026 and mes in (10, 11, 12)
   and categoria = 'RENTA'
   and concepto = 'Renta sube Q4 (fin prorrateo mobiliario) — en transferencia'
   and importe = -232.88;

-- 2) El aviso cuenta la misma historia con el mismo número.
update avisos
   set mensaje = 'Se agota el descuento del amoblamiento: Alberto pasa a recibir 1.614,80 €/mes (base 1.583,14)',
       impacto_mes = -237.95,
       nota = 'Pacto VERBAL (Stag, 27/07/2026): Alberto recibe 1.614,80 en cuenta -> base 1.583,14. Coste modelado 1.677,65 -> 1.915,60 (+237,95/mes, +2.855/ano, ~73% del margen anual del piso). Modela la lectura MAS FAVORABLE por instruccion de Stag, rompiendo el criterio de peor caso: el contrato literal daria coste 1.953,91 (+38,31/mes mas) y la planilla 1.986,58 (+70,98/mes mas). La adenda de octubre (clausulas 4.3 y 8.2) debe fijar por escrito "transferencia 1.614,80, base 1.583,14, IVA 21%, retencion 19%", formato del contrato de Marechal. Ademas, bajo el pacto verbal el descuento del prorrateo se aplico sobre base equivocada (1.641,80 en vez de 1.583,14): se transfirieron ~59,83/mes de mas desde oct-2025, ~598 en 10 meses — decidir en la adenda si se compensa. El P&L de oct-dic ya cuenta la subida via events (-200,58). En enero de 2027 actualizar listings.renta_base.'
 where codigo = '4B_ALEX' and fecha = date '2026-10-01' and tipo = 'renta';
