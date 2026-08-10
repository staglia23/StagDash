-- 075_dia_retro_y_retenciones_111.sql — DIA Madrid retroactivo + modelo 111 (11/08/2026).
--
-- 1) DIA MADRID EN TERCIOS, RETROACTIVO. Stag (10/08): "siempre repartí lo de Madrid
--    entre los 3 pisos. Cambialo y dejalo así la regla". La 074 ya lo aplicó a julio;
--    esta lo corrige ene–jun: los DIA de Madrid iban 100% a NICA dentro de "Compras
--    hogar". Total movido: 200,00 exactos (ene 34,12 / mar 32,35 / abr 16,92 /
--    may 76,90 / jun 39,71). Neutro para el P&L global: NICA +133,32, ALEX −66,66,
--    MARE −66,66. Guardas por id+importe → idempotente.
--
-- 2) MODELO 111 2T (PDF de la presentación, 15/07/2026; domiciliado 20/07 en Revolut,
--    el cargo AEAT −1.103,53 del extracto): retenciones trabajo 1.031,67 (2 perceptores,
--    base 11.583,99 = Stag 10.000,00 + José 1.583,99) + profesionales 71,86 (2
--    perceptores, base 479,02, 15%). Reparto inferido de las bases: Stag 1.000,00
--    (10%) — YA CUBIERTO por la provisión "Sueldo Stag bruto" 3.333,33/mes, no genera
--    event — y José 31,67 (2%), que SÍ falta porque su event mensual usa el neto (484).
--    Cuadre del cargo: 1.000,00 (provisión) + 31,67 (event José) + 71,86 (event
--    profesionales) = 1.103,53 exacto.
--
-- 3) HALLAZGO para Confisic (no se toca acá): el "IRPF personal" de 1.031,67 pagado en
--    abril y movido a cuenta con socio por la migración 042 es EXACTAMENTE la retención
--    de trabajo de un trimestre idéntico (1.000,00 + 31,67) → casi seguro era el 111 1T
--    de la SOCIEDAD, no IRPF personal de Stag. Si Confisic lo confirma, no es deuda de
--    Stag con la sociedad. Los events de José de ene–mar de abajo asumen que el 1T se
--    pagó (la retención de José existió todo el año).
--
-- 4) Verificado además (pregunta de Stag del 10/08): julio NO tiene reservas de
--    Booking.com confirmadas (solo 1 cancelada con payout 0, 24–27/07 — mismas fechas
--    que la directa de 520: el huésped canceló y reservó directo). Booking recién
--    afecta agosto.

-- ── 1) DIA Madrid retroactivo ────────────────────────────────────────────────────────
update events set importe = -15.89,
  notas = 'Ikea 15,89; barrido 23/07. Los DIA de enero (17,23 + Mp Dia 16,89 = 34,12) salieron a los events "DIA Madrid (reparto 1/3)" por la migracion 075.'
 where id = 83 and importe = -50.01;

delete from events where id = 69 and importe = -32.35;  -- marzo: el event era SOLO DIA (21,64 + 10,71)

update events set importe = -357.49,
  notas = 'Amazon 34,41 + Zara Home 178,05 + Rituals 50,90 + Velas 33,90 + Mm 26,90 + Home Ideal 13,95 + Casa Soria 10,04 + Ferreteria Hoyos 9,34; barrido 23/07. El Dia Madrid 16,92 salio al reparto 1/3 (075).'
 where id = 70 and importe = -374.41;

update events set importe = -347.56,
  notas = 'Amazon 160,93 + El Corte Ingles 128,90 + H&M 29,98 + Ideal Home 27,75. El Dia Madrid 76,90 salio al reparto 1/3 (075).'
 where id = 71 and importe = -424.46;

update events set importe = -627.64,
  notas = 'Amazon 585,20 (10 pedidos - 1 reembolso, sin los 145,80 de los auriculares) + Ideal Home 15,95 + Bricochayta 16,50 + Hiperhogar 9,99. El Dia Madrid 39,71 salio al reparto 1/3 (075).'
 where id = 72 and importe = -667.35;

insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, v.cod, 'OTROS', 'DIA Madrid (reparto 1/3 pisos Madrid)', v.importe, v.notas
from (values
  (2026, 1, '1A_NICA', -11.38, 'Dia Madrid 17,23 + Mp Dia 16,89 (sin numero de tienda, asumido Madrid como en el barrido original) = 34,12 en tercios; reparto retroactivo 075, regla de Stag 10/08/2026. NICA absorbe el redondeo.'),
  (2026, 1, '4B_ALEX', -11.37, 'Tercio del DIA Madrid de enero (34,12). Reparto retroactivo 075.'),
  (2026, 1, '3G_MARE', -11.37, 'Tercio del DIA Madrid de enero (34,12). Reparto retroactivo 075.'),
  (2026, 3, '1A_NICA', -10.79, 'Dia Madrid 21,64 + 10,71 = 32,35 en tercios (el event original 69 era solo DIA y se elimino); reparto retroactivo 075.'),
  (2026, 3, '4B_ALEX', -10.78, 'Tercio del DIA Madrid de marzo (32,35). Reparto retroactivo 075.'),
  (2026, 3, '3G_MARE', -10.78, 'Tercio del DIA Madrid de marzo (32,35). Reparto retroactivo 075.'),
  (2026, 4, '1A_NICA', -5.64, 'Dia Madrid 16,92 en tercios; reparto retroactivo 075.'),
  (2026, 4, '4B_ALEX', -5.64, 'Tercio del DIA Madrid de abril (16,92). Reparto retroactivo 075.'),
  (2026, 4, '3G_MARE', -5.64, 'Tercio del DIA Madrid de abril (16,92). Reparto retroactivo 075.'),
  (2026, 5, '1A_NICA', -25.64, 'Dia Madrid 76,90 en tercios; reparto retroactivo 075. NICA absorbe el redondeo.'),
  (2026, 5, '4B_ALEX', -25.63, 'Tercio del DIA Madrid de mayo (76,90). Reparto retroactivo 075.'),
  (2026, 5, '3G_MARE', -25.63, 'Tercio del DIA Madrid de mayo (76,90). Reparto retroactivo 075.'),
  (2026, 6, '1A_NICA', -13.23, 'Dia Madrid 39,71 en tercios; reparto retroactivo 075. NICA absorbe el redondeo.'),
  (2026, 6, '4B_ALEX', -13.24, 'Tercio del DIA Madrid de junio (39,71). Reparto retroactivo 075.'),
  (2026, 6, '3G_MARE', -13.24, 'Tercio del DIA Madrid de junio (39,71). Reparto retroactivo 075.')
) as v(anio, mes, cod, importe, notas)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = v.cod
     and e.concepto = 'DIA Madrid (reparto 1/3 pisos Madrid)'
);

-- ── 2) Retención IRPF de la nómina de José (modelo 111): 10,56/mes, 31,67/trimestre ──
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select v.anio, v.mes, '1A_JACO', 'OTROS', 'IRPF nómina José (modelo 111)', v.importe,
  'Retencion IRPF de la nomina de Jose: 31,67/trimestre = 2% de 1.583,99 de bruto trim. (528/mes; neto 484). El event mensual de Modesto usa el NETO, asi que esta linea completa el coste real. Del 111 2T (PDF 15/07/2026); la parte de Stag (1.000/trim) ya esta en la provision de sueldo bruto. 10,56/mes; 10,55 al cierre de trimestre para clavar 31,67.'
from (values
  (2026, 1, -10.56), (2026, 2, -10.56), (2026, 3, -10.55),
  (2026, 4, -10.56), (2026, 5, -10.56), (2026, 6, -10.55),
  (2026, 7, -10.56)
) as v(anio, mes, importe)
where not exists (
  select 1 from events e
   where e.anio = v.anio and e.mes = v.mes and e.propiedad_codigo = '1A_JACO'
     and e.concepto = 'IRPF nómina José (modelo 111)'
);

-- ── 3) Retenciones a profesionales (111 2T, casillas 07-09) ──────────────────────────
insert into events (anio, mes, propiedad_codigo, categoria, concepto, importe, notas)
select 2026, 7, 'SAMAVI_GEN', 'CORPORATIVO', 'Retenciones profesionales (modelo 111 2T)', -71.86,
  '2 perceptores de actividades economicas, base 479,02, retencion 15% = 71,86 (111 2T). Las facturas de profesionales se cargan por lo PAGADO por banco (neto de retencion): esta linea completa el coste real. PENDIENTE identificar los 2 perceptores con Confisic (Confisic mismo no lleva retencion: es SL y se le paga la factura completa).'
where not exists (
  select 1 from events e
   where e.anio = 2026 and e.mes = 7 and e.propiedad_codigo = 'SAMAVI_GEN'
     and e.concepto = 'Retenciones profesionales (modelo 111 2T)'
);
