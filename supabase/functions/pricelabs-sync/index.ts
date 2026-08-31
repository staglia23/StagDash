// pricelabs-sync — Edge Function (Deno) · v4
// Calendario forward de PriceLabs → tabla pricelabs_prices + foto diaria pricelabs_fotos.
// - POST api.pricelabs.co/v1/listing_prices, hoy → +366 días, los 4 listings en una llamada
// - listing_id de PriceLabs = listings.guesty_listing_id (PMS guesty): sin mapeo propio
// - Upsert idempotente por (codigo, fecha); las noches pasadas quedan como última foto
// - Corre 1×/día a las 07:10 UTC (cron), después del refresh de PriceLabs (~06:00 UTC)
// v3 (auditoría 03/08/2026, migración 064):
// - STLY: PriceLabs manda cadena VACÍA cuando no hay dato (no ausencia de campo) → si la
//   fecha equivalente del año pasado es anterior a listings.fecha_inicio, se guarda NULL
//   (antes quedaba false y "no gestionábamos" parecía "0 % de ocupación").
// - Borde: la última fecha de la ventana pedida llega "unbookable" por artefacto (PriceLabs
//   no ve la noche siguiente) → se pide un día extra y se descarta.
// - Foto diaria: tras el upsert se inserta la foto del día en pricelabs_fotos (cimiento del
//   pace; la serie no se puede reconstruir hacia atrás).
// v4 (año contra año, migración 094):
// - Mercado del barrio: GET /v1/neighborhood_data por listing (misma key). Del bloque
//   "Market KPI" (categoría = listings.dormitorios) sale la serie MENSUAL del compset →
//   pricelabs_mercado; de "Future Percentile Prices", la foto diaria de percentiles →
//   pricelabs_mercado_fotos (PriceLabs no da su histórico: se acumula desde hoy).
// - Falla blanda: un error del mercado queda en sync_state.pricelabs_last_error pero no
//   tumba el sync del calendario, que es el dato crítico.
// - OJO parser (verificado contra respuesta real 01/09/2026; la doc oficial está vieja):
//   meses "Mmm AAAA" con los rollups "Last 365/730 Days" DENTRO del mismo X_values; 10
//   labels en Market KPI (no 5); Y_values[fila][col] alineado a X_values; los huecos son
//   ceros, no null/-1 → un mes sin días disponibles se descarta, no se guarda.
//
// Secrets requeridos (supabase secrets set ...):
//   PRICELABS_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// La key se genera en PriceLabs → Account Settings → API Details (cuesta 1 $/mes por
// listing sincronizado). Sin el secret, la corrida falla y queda anotada en
// sync_state.pricelabs_last_error — el dato en pricelabs_prices simplemente envejece
// (y v_freshness ahora lo delata en la portada).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PL_URL = "https://api.pricelabs.co/v1/listing_prices";
const PL_MERCADO_URL = "https://api.pricelabs.co/v1/neighborhood_data";
const DIAS = 365; // se pide DIAS+1 y se descarta el último (artefacto de borde)
const CHUNK = 500;

const MESES_EN: Record<string, string> = {
  Jan: "01", Feb: "02", Mar: "03", Apr: "04", May: "05", Jun: "06",
  Jul: "07", Aug: "08", Sep: "09", Oct: "10", Nov: "11", Dec: "12",
};

const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`Falta el secret ${k}`);
  return v;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// PriceLabs usa -1 como "no aplica" (user_price sin override, ADR de noche libre, etc.)
const num = (v: unknown): number | null => {
  const n = Number(v);
  return Number.isFinite(n) && n !== -1 ? n : null;
};
const fecha = (v: unknown): string | null =>
  typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : null;

// "2026-08-15" → "2025-08-15". Comparación lexicográfica válida contra fecha_inicio
// (un 29-feb restado da una fecha inexistente pero ordena bien igual).
const menosUnAnio = (ymd: string): string =>
  `${Number(ymd.slice(0, 4)) - 1}${ymd.slice(4)}`;

async function pricelabsFetch(key: string, url: string, body?: unknown, tries = 4): Promise<any> {
  let last = "";
  for (let i = 0; i < tries; i++) {
    const res = await fetch(url, {
      method: body === undefined ? "GET" : "POST",
      headers: { "X-API-Key": key, "Content-Type": "application/json", Accept: "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 429 || res.status >= 500) {
      last = `${res.status}: ${await res.text()}`;
      await sleep(2000 * (i + 1));
      continue;
    }
    if (!res.ok) throw new Error(`PriceLabs ${res.status}: ${await res.text()}`);
    return res.json();
  }
  throw new Error(`PriceLabs agotó reintentos (${last})`);
}

// El compset se pide por la categoría de dormitorios del piso; si la respuesta no trae
// exactamente esa clave, se usa la numérica más cercana (y queda registrada en la fila).
const eligeCategoria = (cat: Record<string, unknown> | undefined, dormitorios: number): string | null => {
  const claves = Object.keys(cat ?? {}).filter((k) => /^-?\d+$/.test(k));
  if (!claves.length) return null;
  const exacta = String(dormitorios);
  if (claves.includes(exacta)) return exacta;
  return claves.sort((a, b) =>
    Math.abs(Number(a) - dormitorios) - Math.abs(Number(b) - dormitorios) ||
    Number(a) - Number(b))[0];
};

Deno.serve(async (req) => {
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  // Puerta (migración 069). verify_jwt=true NO significa "solo usuarios logueados": el
  // gateway únicamente comprueba que el JWT esté bien firmado, y la anon key es un JWT
  // válido publicado en el bundle del dashboard — la auditoría del 04/08/2026 invocó esta
  // función desde fuera con esa key y el cuerpo corrió. El secreto compartido (x-sync-secret,
  // cifrado en Vault) es lo único que separa al cron de un anónimo.
  const secreto = req.headers.get("x-sync-secret") ?? "";
  if (secreto.length < 32) return new Response("no autorizado", { status: 401 });
  const { data: autorizado } = await supabase.rpc("f_sync_secret_ok", { p_secreto: secreto });
  if (autorizado !== true) return new Response("no autorizado", { status: 401 });

  const startedAt = new Date().toISOString();
  try {
    // La API key vive CIFRADA en Vault (migración 072), no como variable de entorno: así
    // no hay que tocar el panel para rotarla y nunca pasa por el repo. Se mantiene el
    // fallback a la env var por si algún día se prefiere el camino estándar de Supabase.
    const { data: keyVault } = await supabase.rpc("f_pricelabs_key");
    const key = (typeof keyVault === "string" && keyVault.length > 0)
      ? keyVault
      : env("PRICELABS_API_KEY");

    const { data: listings, error } = await supabase.from("listings")
      .select("codigo, guesty_listing_id, fecha_inicio, dormitorios").not("guesty_listing_id", "is", null);
    if (error) throw error;
    if (!listings?.length) throw new Error("listings sin guesty_listing_id: nada que pedir");
    const porId = new Map(listings.map((l: any) => [l.guesty_listing_id, l]));

    const desde = startedAt.slice(0, 10);
    // +1 día: el último de la ventana llega "unbookable" por artefacto y se descarta abajo
    const hasta = new Date(Date.now() + (DIAS + 1) * 86_400_000).toISOString().slice(0, 10);
    const json = await pricelabsFetch(key, PL_URL, {
      listings: listings.map((l: any) => ({
        id: l.guesty_listing_id, pms: "guesty", dateFrom: desde, dateTo: hasta,
      })),
    });

    // La API devuelve un array; por si algún proxy lo envuelve en {data: [...]}
    const resultados = Array.isArray(json) ? json : Array.isArray(json?.data) ? json.data : [];
    if (!resultados.length) throw new Error(`respuesta sin listings: ${JSON.stringify(json).slice(0, 300)}`);

    const errores: string[] = [];
    let upserted = 0, fotos = 0;
    for (const listing of resultados) {
      const meta = porId.get(listing.id);
      if (!meta) { errores.push(`listing sin mapa: ${listing.id}`); continue; }
      if (listing.error || !Array.isArray(listing.data)) {
        errores.push(`${meta.codigo}: ${listing.error ?? listing.error_code ?? "sin data"}`);
        continue;
      }
      // El último día DEVUELTO llega "unbookable" por artefacto de borde. Se descarta el
      // máximo real de la respuesta, no el pedido: si el horizonte del listing es más
      // corto que la ventana, la respuesta termina antes de `hasta`.
      const fechas = listing.data.map((d: any) => d.date).filter((x: any) => fecha(x));
      const ultima = fechas.length ? fechas.reduce((a: string, b: string) => (a > b ? a : b)) : hasta;
      const rows = listing.data
        .filter((d: any) => fecha(d.date) && d.date !== ultima)
        .map((d: any) => {
          // STLY válido solo si ya gestionábamos el piso en la fecha equivalente
          const stlyValida = !!meta.fecha_inicio && menosUnAnio(d.date) >= meta.fecha_inicio;
          return {
            codigo: meta.codigo,
            fecha: d.date,
            precio: num(d.price),
            precio_usuario: num(d.user_price),
            precio_base: num(d.uncustomized_price),
            min_stay: num(d.min_stay),
            reservado: d.occupancy === 1,
            booking_status: d.booking_status || null,
            adr: num(d.ADR),
            fecha_reserva: fecha(d.booked_date),
            stly_reservado: stlyValida && typeof d.booking_status_STLY === "string"
              ? d.booking_status_STLY.startsWith("Booked") : null,
            stly_adr: stlyValida ? num(d.ADR_STLY) : null,
            demanda: d.demand_desc ?? null,
            no_vendible: d.unbookable === 1,
            currency: listing.currency ?? null,
            refreshed_at: listing.last_refreshed_at ?? null,
            synced_at: startedAt,
          };
        });
      for (let i = 0; i < rows.length; i += CHUNK) {
        const slice = rows.slice(i, i + CHUNK);
        const { error: e } = await supabase.from("pricelabs_prices")
          .upsert(slice, { onConflict: "codigo,fecha" });
        if (e) throw e;
        upserted += slice.length;
        // Foto del día (insert-only conceptual; si el sync corre dos veces, gana la última)
        const foto = slice.map((r) => ({
          foto_fecha: desde, codigo: r.codigo, fecha: r.fecha, precio: r.precio,
          reservado: r.reservado, no_vendible: r.no_vendible, booking_status: r.booking_status,
        }));
        const { error: ef } = await supabase.from("pricelabs_fotos")
          .upsert(foto, { onConflict: "foto_fecha,codigo,fecha" });
        if (ef) throw ef;
        fotos += foto.length;
      }
    }

    // ── Mercado del barrio (v4, migración 094) — falla blanda por listing ──────
    let mercado = 0, mercadoFotos = 0;
    for (const l of listings as any[]) {
      if (!l.dormitorios) { errores.push(`${l.codigo}: sin dormitorios, mercado omitido`); continue; }
      try {
        const nj = await pricelabsFetch(
          key, `${PL_MERCADO_URL}?listing_id=${l.guesty_listing_id}&pms=guesty`);
        const d = nj?.data;
        if (!d) throw new Error(`respuesta sin data: ${JSON.stringify(nj).slice(0, 200)}`);
        const fuente = d["Neighborhood Data Source"] ?? null;

        // Serie mensual del compset (bloque "Market KPI"; los huecos vienen como CEROS,
        // no null → un mes sin días disponibles se descarta en vez de guardarse)
        const kpi = d["Market KPI"];
        const catKpi = eligeCategoria(kpi?.Category, l.dormitorios);
        const ck = catKpi ? kpi.Category[catKpi] : null;
        if (ck && Array.isArray(ck.X_values) && Array.isArray(ck.Y_values)) {
          const labels: string[] = kpi.Labels ?? [];
          const filaKpi = (nombre: string): unknown[] | null => {
            const i = labels.indexOf(nombre);
            return i >= 0 && Array.isArray(ck.Y_values[i]) ? ck.Y_values[i] : null;
          };
          const disp = filaKpi("Total Available Days"), vend = filaKpi("Total Booked Days");
          const rev = filaKpi("Revenue"), bw = filaKpi("Booking Window"), los = filaKpi("LOS");
          const rowsMercado: any[] = [];
          ck.X_values.forEach((x: unknown, col: number) => {
            const m = /^([A-Z][a-z]{2}) (\d{4})$/.exec(String(x));
            if (!m || !MESES_EN[m[1]]) return; // descarta "Last 365 Days" / "Last 730 Days"
            const disponibles = num(disp?.[col]);
            if (!disponibles) return; // cero días disponibles = relleno sin historia
            rowsMercado.push({
              codigo: l.codigo,
              mes: `${m[2]}-${MESES_EN[m[1]]}-01`,
              categoria: catKpi,
              n_listings: num(ck["Listings Used"]),
              noches_disponibles: disponibles,
              noches_vendidas: num(vend?.[col]) ?? 0,
              revenue: num(rev?.[col]) ?? 0,
              booking_window: num(bw?.[col]),
              los: num(los?.[col]),
              fuente,
              synced_at: startedAt,
            });
          });
          if (rowsMercado.length) {
            const { error: em } = await supabase.from("pricelabs_mercado")
              .upsert(rowsMercado, { onConflict: "codigo,mes" });
            if (em) throw em;
            mercado += rowsMercado.length;
          }
        } else {
          errores.push(`${l.codigo}: Market KPI sin categoría utilizable`);
        }

        // Foto diaria de percentiles forward (la "mediana pagada" no tiene histórico en
        // PriceLabs: se acumula desde hoy, igual que pricelabs_fotos)
        const fpp = d["Future Percentile Prices"];
        const catFpp = eligeCategoria(fpp?.Category, l.dormitorios);
        const cp = catFpp ? fpp.Category[catFpp] : null;
        if (cp && Array.isArray(cp.X_values) && Array.isArray(cp.Y_values)) {
          const labelsP: string[] = fpp.Labels ?? [];
          const filaFpp = (nombre: string): unknown[] | null => {
            const i = labelsP.indexOf(nombre);
            return i >= 0 && Array.isArray(cp.Y_values[i]) ? cp.Y_values[i] : null;
          };
          const p25 = filaFpp("25th Percentile"), p50 = filaFpp("50th Percentile");
          const p75 = filaFpp("75th Percentile"), p90 = filaFpp("90th Percentile");
          const med = filaFpp("Median Booked Price"), nb = filaFpp("N_Bookings");
          const rowsFoto: any[] = [];
          cp.X_values.forEach((x: unknown, col: number) => {
            if (!fecha(x)) return;
            rowsFoto.push({
              foto_fecha: desde, codigo: l.codigo, fecha: x,
              mediana_pagada: num(med?.[col]),
              p25: num(p25?.[col]), p50: num(p50?.[col]),
              p75: num(p75?.[col]), p90: num(p90?.[col]),
              n_reservas: Number.isFinite(Number(nb?.[col])) ? Number(nb?.[col]) : null,
            });
          });
          for (let i = 0; i < rowsFoto.length; i += CHUNK) {
            const slice = rowsFoto.slice(i, i + CHUNK);
            const { error: ef2 } = await supabase.from("pricelabs_mercado_fotos")
              .upsert(slice, { onConflict: "foto_fecha,codigo,fecha" });
            if (ef2) throw ef2;
            mercadoFotos += slice.length;
          }
        }
      } catch (e) {
        errores.push(`${l.codigo}: mercado ${String(e)}`);
      }
    }

    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt,
      pricelabs_last_error: errores.length ? errores.join(" · ") : null,
      updated_at: startedAt,
    }).eq("id", 1);

    return Response.json({
      ok: errores.length === 0, upserted, fotos, mercado, mercadoFotos, desde, hasta, errores,
    });
  } catch (e) {
    // el detalle va al log y a sync_state (de donde lo lee v_freshness), NO a la respuesta
    console.error(e);
    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt, pricelabs_last_error: String(e), updated_at: startedAt,
    }).eq("id", 1);
    return Response.json({ ok: false }, { status: 500 });
  }
});
