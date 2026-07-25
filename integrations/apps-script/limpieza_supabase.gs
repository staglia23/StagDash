/**
 * limpieza_supabase.gs — el puente entre la conciliación de Ecocleans (Apps Script / Cowork)
 * y el motor del dashboard.
 *
 * QUÉ RESUELVE
 * Hasta ahora el resultado de conciliarMes() moría en un Sheet: el coste exacto de limpieza por
 * propiedad estaba calculado y verificado, pero el motor seguía estimándolo como
 * 43,80 € × reservas. En ene–jun eso subestimaba a Alexander en 250 € y a Nicasio en 172 €.
 *
 * Con esto, el script escribe el dato real en Supabase (tabla limpieza_mensual, migración 031)
 * y el dashboard deja de estimar. Efecto lateral: las tarifas dejan de estar duplicadas — el
 * script manda euros, no tarifas, así que TARIFAS.precioHora vive en un solo sitio.
 *
 * INSTALACIÓN (una vez)
 *  1. Desplegar la Edge Function `limpieza-ingest` (está en el repo del dashboard,
 *     supabase/functions/limpieza-ingest/).
 *  2. En Supabase → Edge Functions → Secrets, crear LIMPIEZA_INGEST_TOKEN con una cadena
 *     larga y aleatoria.
 *  3. En Apps Script → Configuración del proyecto → Propiedades de la secuencia de comandos,
 *     crear SUPABASE_INGEST_URL y SUPABASE_INGEST_TOKEN.
 *
 * NUNCA hardcodear el token en el archivo: este código se comparte y se copia.
 */

/**
 * Manda el desglose de un mes a Supabase. Idempotente: reprocesar el mes lo pisa.
 *
 * @param {number} anio
 * @param {number} mes                 1–12
 * @param {string} factura             p.ej. 'F260201'
 * @param {Array}  porPropiedad        una entrada por piso:
 *   { codigo:'4B_ALEX', servicios:11, horas:15.00,
 *     limpieza_eur:246.00, kits_eur:19.80, renting_eur:163.84, fiable:true }
 *
 *   `codigo` son los del dashboard: 1A_NICA · 4B_ALEX · 3G_MARE · 1A_JACO.
 *   `fiable` es false cuando la lectura fila-a-fila NO cuadró con el resumen de la factura
 *   (o sea, cuando usaHorasResumen o usaRentingResumen se activaron). El dato entra igual,
 *   pero el dashboard lo etiqueta 'real_revisar' en vez de 'real'. Mandar la verdad acá vale
 *   más que forzar un ✅: un dato marcado se puede filtrar, uno maquillado no.
 *
 * @return {Object} { ok:true, escritas:n } o lanza con el motivo.
 */
function enviarLimpiezaASupabase_(anio, mes, factura, porPropiedad) {
  var props = PropertiesService.getScriptProperties();
  var url   = props.getProperty('SUPABASE_INGEST_URL');
  var token = props.getProperty('SUPABASE_INGEST_TOKEN');

  if (!url || !token) {
    throw new Error('Faltan SUPABASE_INGEST_URL / SUPABASE_INGEST_TOKEN en las propiedades del script.');
  }
  if (!porPropiedad || !porPropiedad.length) {
    throw new Error('No hay filas que mandar para ' + mes + '/' + anio + '.');
  }

  var payload = {
    anio: anio,
    mes: mes,
    factura: factura || null,
    filas: porPropiedad.map(function (p) {
      return {
        codigo:       p.codigo,
        servicios:    p.servicios    || 0,
        horas:        p.horas        || 0,
        limpieza_eur: p.limpieza_eur || 0,
        kits_eur:     p.kits_eur     || 0,
        renting_eur:  p.renting_eur  || 0,
        fiable:       p.fiable !== false
      };
    })
  };

  // Tres intentos: el trigger mensual corre desatendido y un 5xx puntual no puede costar el mes.
  var ultimoError = '';
  for (var intento = 1; intento <= 3; intento++) {
    var res = UrlFetchApp.fetch(url, {
      method: 'post',
      contentType: 'application/json',
      headers: { 'x-ingest-token': token },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    });

    var code = res.getResponseCode();
    var body = res.getContentText();

    if (code >= 200 && code < 300) {
      Logger.log('Supabase OK ' + mes + '/' + anio + ': ' + body);
      return JSON.parse(body);
    }

    ultimoError = code + ' ' + body;
    // 4xx = el payload está mal; reintentar no lo arregla.
    if (code >= 400 && code < 500) break;
    Utilities.sleep(1000 * intento);
  }

  throw new Error('Supabase rechazó ' + mes + '/' + anio + ': ' + ultimoError);
}

/**
 * Cómo engancharlo en conciliarMes(), después de generar el Sheet.
 *
 * Va en try/catch a propósito: si Supabase está caído, la conciliación y el pago NO se pueden
 * frenar. El dashboard puede esperar; la factura de Ecocleans no.
 *
 *   try {
 *     enviarLimpiezaASupabase_(anio, mes, resultado.facturaNumero, [
 *       { codigo: '1A_NICA', servicios: n1.servicios, horas: n1.horas,
 *         limpieza_eur: n1.horas * TARIFAS.precioHora,
 *         kits_eur: n1.servicios * TARIFAS.kitCocina,
 *         renting_eur: n1.renting, fiable: !v.usaHorasResumen && !v.usaRentingResumen },
 *       ... idem 4B_ALEX y 3G_MARE ...
 *     ]);
 *   } catch (e) {
 *     Logger.log('Aviso: no se pudo mandar a Supabase — ' + e.message);
 *   }
 */
