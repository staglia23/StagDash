// pricelabs-sync — Edge Function (Deno) · v3
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
//
// Secrets requeridos (supabase secrets set ...):
//   PRICELABS_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// La key se genera en PriceLabs → Account Settings → API Details (cuesta 1 $/mes por
// listing sincronizado). Sin el secret, la corrida falla y queda anotada en
// sync_state.pricelabs_last_error — el dato en pricelabs_prices simplemente envejece
// (y v_freshness ahora lo delata en la portada).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PL_URL = "https://api.pricelabs.co/v1/listing_prices";
const DIAS = 365; // se pide DIAS+1 y se descarta el último (artefacto de borde)
const CHUNK = 500;

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

async function pricelabsPost(key: string, body: unknown, tries = 4): Promise<any> {
  let last = "";
  for (let i = 0; i < tries; i++) {
    const res = await fetch(PL_URL, {
      method: "POST",
      headers: { "X-API-Key": key, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
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
      .select("codigo, guesty_listing_id, fecha_inicio").not("guesty_listing_id", "is", null);
    if (error) throw error;
    if (!listings?.length) throw new Error("listings sin guesty_listing_id: nada que pedir");
    const porId = new Map(listings.map((l: any) => [l.guesty_listing_id, l]));

    const desde = startedAt.slice(0, 10);
    // +1 día: el último de la ventana llega "unbookable" por artefacto y se descarta abajo
    const hasta = new Date(Date.now() + (DIAS + 1) * 86_400_000).toISOString().slice(0, 10);
    const json = await pricelabsPost(key, {
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

    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt,
      pricelabs_last_error: errores.length ? errores.join(" · ") : null,
      updated_at: startedAt,
    }).eq("id", 1);

    return Response.json({ ok: errores.length === 0, upserted, fotos, desde, hasta, errores });
  } catch (e) {
    // el detalle va al log y a sync_state (de donde lo lee v_freshness), NO a la respuesta
    console.error(e);
    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt, pricelabs_last_error: String(e), updated_at: startedAt,
    }).eq("id", 1);
    return Response.json({ ok: false }, { status: 500 });
  }
});
