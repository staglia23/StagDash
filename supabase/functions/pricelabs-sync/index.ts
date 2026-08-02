// pricelabs-sync — Edge Function (Deno)
// Calendario forward de PriceLabs → tabla pricelabs_prices (migración 063).
// - POST api.pricelabs.co/v1/listing_prices, hoy → +365 días, los 4 listings en una llamada
// - listing_id de PriceLabs = listings.guesty_listing_id (PMS guesty): sin mapeo propio
// - Upsert idempotente por (codigo, fecha); las noches pasadas quedan como última foto
// - Corre 1×/día a las 07:10 UTC (cron), después del refresh de PriceLabs (~06:00 UTC)
//
// Secrets requeridos (supabase secrets set ...):
//   PRICELABS_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// La key se genera en PriceLabs → Account Settings → API Details (cuesta 1 $/mes por
// listing sincronizado). Sin el secret, la corrida falla y queda anotada en
// sync_state.pricelabs_last_error — el dato en pricelabs_prices simplemente envejece.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PL_URL = "https://api.pricelabs.co/v1/listing_prices";
const DIAS = 365;
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

Deno.serve(async () => {
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const startedAt = new Date().toISOString();
  try {
    const key = env("PRICELABS_API_KEY");

    const { data: listings, error } = await supabase.from("listings")
      .select("codigo, guesty_listing_id").not("guesty_listing_id", "is", null);
    if (error) throw error;
    if (!listings?.length) throw new Error("listings sin guesty_listing_id: nada que pedir");
    const codigoPorId = new Map(listings.map((l: any) => [l.guesty_listing_id, l.codigo]));

    const desde = startedAt.slice(0, 10);
    const hasta = new Date(Date.now() + DIAS * 86_400_000).toISOString().slice(0, 10);
    const json = await pricelabsPost(key, {
      listings: listings.map((l: any) => ({
        id: l.guesty_listing_id, pms: "guesty", dateFrom: desde, dateTo: hasta,
      })),
    });

    // La API devuelve un array; por si algún proxy lo envuelve en {data: [...]}
    const resultados = Array.isArray(json) ? json : Array.isArray(json?.data) ? json.data : [];
    if (!resultados.length) throw new Error(`respuesta sin listings: ${JSON.stringify(json).slice(0, 300)}`);

    const errores: string[] = [];
    let upserted = 0;
    for (const listing of resultados) {
      const codigo = codigoPorId.get(listing.id);
      if (!codigo) { errores.push(`listing sin mapa: ${listing.id}`); continue; }
      if (listing.error || !Array.isArray(listing.data)) {
        errores.push(`${codigo}: ${listing.error ?? listing.error_code ?? "sin data"}`);
        continue;
      }
      const rows = listing.data
        .filter((d: any) => fecha(d.date))
        .map((d: any) => ({
          codigo,
          fecha: d.date,
          precio: num(d.price),
          precio_usuario: num(d.user_price),
          precio_base: num(d.uncustomized_price),
          min_stay: num(d.min_stay),
          reservado: d.occupancy === 1,
          booking_status: d.booking_status || null,
          adr: num(d.ADR),
          fecha_reserva: fecha(d.booked_date),
          // startsWith: el STLY también puede venir 'Blocked', que no es noche vendida
          stly_reservado: typeof d.booking_status_STLY === "string" ? d.booking_status_STLY.startsWith("Booked") : null,
          stly_adr: num(d.ADR_STLY),
          demanda: d.demand_desc ?? null,
          no_vendible: d.unbookable === 1,
          currency: listing.currency ?? null,
          refreshed_at: listing.last_refreshed_at ?? null,
          synced_at: startedAt,
        }));
      for (let i = 0; i < rows.length; i += CHUNK) {
        const slice = rows.slice(i, i + CHUNK);
        const { error: e } = await supabase.from("pricelabs_prices")
          .upsert(slice, { onConflict: "codigo,fecha" });
        if (e) throw e;
        upserted += slice.length;
      }
    }

    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt,
      pricelabs_last_error: errores.length ? errores.join(" · ") : null,
      updated_at: startedAt,
    }).eq("id", 1);

    return Response.json({ ok: errores.length === 0, upserted, desde, hasta, errores });
  } catch (e) {
    await supabase.from("sync_state").update({
      pricelabs_last_run: startedAt, pricelabs_last_error: String(e), updated_at: startedAt,
    }).eq("id", 1);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
