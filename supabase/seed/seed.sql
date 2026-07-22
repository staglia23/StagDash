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
  ('Viajes corporativos', 200.00, NULL, NULL),                       -- cubre el día a día Revolut; viajes grandes = eventos
  ('Asesor Confisic', 181.50, NULL, NULL),
  ('Claude.ai (plan 90)', 90.00, date '2026-06-01', NULL),
  ('Otros AEAT/admin', 50.00, NULL, NULL),
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

-- 4) Comidas de negocio (Uber Eats/Glovo/restaurantes) → gasto general.
--    Serie ene–jun completa (barrido 23/07); ene/mar/abr sin cargos ("Licencia 431" es taxi, MCC 4121).
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas) values
  (2026, 2, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -37.69, 'Uber Eats 16,74 + Café Bistro Nuncio 4,35 + Mina Coffee 16,60; barrido 23/07'),
  (2026, 5, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -15.38, 'Uber Eats 15,38; barrido 23/07'),
  (2026, 6, 'SAMAVI_GEN', 'SAMAVI_GEN', 'Comidas de negocio (real bancos)', -167.26, 'Uber Eats 45,22 + Glovo 13,54 + Irish Rover 25 + Pavlov 13,50 + Campo Simbólico 70; serie ene–jun completa (ene/mar/abr sin cargos, Licencia 431 es taxi)');
