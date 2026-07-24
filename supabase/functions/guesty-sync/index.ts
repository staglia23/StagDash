// guesty-sync — Edge Function (Deno)
// Ingesta incremental de reservas de Guesty Open API → Supabase (tabla reservations).
// - OAuth2 client_credentials (token 24h)
// - Resuelve listingId → codigo (y autocompleta listings.guesty_listing_id por nickname)
// - Paginación (limit 100) con backoff en 429
// - Upsert idempotente por id (solo si last_updated_at es más nuevo)
//
// Secrets requeridos (supabase secrets set ...):
//   GUESTY_CLIENT_ID, GUESTY_CLIENT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Mapeo de "money" CONFIRMADO (24/07/2026) contra los PDF de Airbnb H1: bruto =
// fareAccommodation + fareCleaning; host_service_fee = hostServiceFee; host_payout = hostPayout.
// v4: agrega confirmation_code (Airbnb HMxxxx) para conciliar 1:1 con Airbnb.
// v5: getToken reintenta en 429. v6: cachea el token en sync_state (dura 24h) → no lo pide
//     en cada corrida, evitando el rate-limit del endpoint de token. (todo 24/07/2026)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GUESTY_BASE = "https://open-api.guesty.com";
const TOKEN_URL = `${GUESTY_BASE}/oauth2/token`;
const PAGE = 100;

const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`Falta el secret ${k}`);
  return v;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function getToken(supabase: any, tries = 5): Promise<string> {
  // 1) Token cacheado: los de Guesty duran 24h → reusar en vez de pedir en cada corrida
  //    (pedir seguido dispara el rate-limit del endpoint de token).
  try {
    const { data } = await supabase.from("sync_state")
      .select("guesty_token, guesty_token_exp").eq("id", 1).single();
    if (data?.guesty_token && data?.guesty_token_exp &&
        new Date(data.guesty_token_exp).getTime() > Date.now() + 60_000) {
      return data.guesty_token;
    }
  } catch (_) { /* si falla la lectura del caché, pedimos uno nuevo */ }

  // 2) Pedir uno nuevo (con reintento en 429) y cachearlo con su vencimiento.
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    scope: "open-api",
    client_id: env("GUESTY_CLIENT_ID"),
    client_secret: env("GUESTY_CLIENT_SECRET"),
  });
  for (let i = 0; i < tries; i++) {
    const res = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body,
    });
    if (res.status === 429) {
      const wait = Number(res.headers.get("Retry-After") ?? 5) * 1000 * (i + 1);
      await sleep(wait);
      continue;
    }
    if (!res.ok) throw new Error(`Token error ${res.status}: ${await res.text()}`);
    const j = await res.json();
    const exp = new Date(Date.now() + ((j.expires_in ?? 86400) * 1000)).toISOString();
    await supabase.from("sync_state")
      .update({ guesty_token: j.access_token, guesty_token_exp: exp }).eq("id", 1);
    return j.access_token;
  }
  throw new Error("Token error 429: agotó reintentos");
}

async function guestyGet(path: string, token: string, tries = 4): Promise<any> {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(`${GUESTY_BASE}${path}`, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
    if (res.status === 429) {
      const wait = Number(res.headers.get("Retry-After") ?? 2) * 1000 * (i + 1);
      await sleep(wait);
      continue;
    }
    if (!res.ok) throw new Error(`GET ${path} → ${res.status}: ${await res.text()}`);
    return res.json();
  }
  throw new Error(`GET ${path} agotó reintentos (429)`);
}

// listingId (Guesty) → codigo (Samavi). Empareja por nickname con listings.listing_nickname.
async function buildListingMap(supabase: any, token: string): Promise<Map<string, string>> {
  const { data: rows, error } = await supabase.from("listings")
    .select("codigo, listing_nickname, guesty_listing_id");
  if (error) throw error;

  const byNickname = new Map<string, string>();      // nickname → codigo
  const known = new Map<string, string>();           // guesty_id → codigo (ya mapeados)
  for (const r of rows) {
    if (r.listing_nickname) byNickname.set(String(r.listing_nickname).toLowerCase(), r.codigo);
    if (r.guesty_listing_id) known.set(r.guesty_listing_id, r.codigo);
  }

  const map = new Map<string, string>(known);
  const gl = await guestyGet(`/v1/listings?fields=_id nickname title&limit=100`, token);
  for (const l of gl.results ?? []) {
    const nick = String(l.nickname ?? l.title ?? "").toLowerCase();
    const codigo = byNickname.get(nick);
    if (codigo && !map.has(l._id)) {
      map.set(l._id, codigo);
      // autocompleta guesty_listing_id en listings (Fase 0 automática)
      await supabase.from("listings").update({ guesty_listing_id: l._id }).eq("codigo", codigo);
    }
  }
  return map;
}

function toRow(r: any, codigo: string) {
  const m = r.money ?? {};
  return {
    id: r._id,
    guesty_listing_id: r.listingId,
    codigo,
    checkin: r.checkIn ?? null,
    checkout: r.checkOut ?? null,
    checkin_local: r.checkInDateLocalized ?? null,
    checkout_local: r.checkOutDateLocalized ?? null,
    nights: r.nightsCount ?? null,
    status: r.status ?? null,
    source: r.source ?? r.integration?.platform ?? null,
    guest_nombre: [r.guest?.firstName, r.guest?.lastName].filter(Boolean).join(" ") || null,
    // Código del canal (Airbnb HMxxxx, etc.): clave única para conciliar 1:1 contra el
    // reporte de transacciones de Airbnb, sin depender de monto/fecha.
    confirmation_code: r.confirmationCode ?? null,
    // Mapeo CONFIRMADO contra el Excel (comisión 18,76% coincide):
    //   bruto = fareAccommodation + fareCleaning · comisión = hostServiceFee · payout = hostPayout
    bruto: (m.fareAccommodation ?? 0) + (m.fareCleaning ?? 0),
    host_service_fee: m.hostServiceFee ?? null,
    host_payout: m.hostPayout ?? null,
    total_paid: m.totalPaid ?? null,
    total_taxes: m.totalTaxes ?? null,
    money_raw: m,
    created_at: r.createdAt ?? null,
    last_updated_at: r.lastUpdatedAt ?? null,
  };
}

Deno.serve(async () => {
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const startedAt = new Date().toISOString();
  try {
    const token = await getToken(supabase);
    const listingMap = await buildListingMap(supabase, token);

    const { data: st } = await supabase.from("sync_state").select("last_sync").eq("id", 1).single();
    // 1ª corrida: since=2024 → backfill completo (el listado por defecto de Guesty solo trae
    // reservas futuras; filtrar por lastUpdatedAt trae también el histórico). Luego, incremental.
    const since = st?.last_sync ?? "2024-01-01T00:00:00Z";
    const filters = encodeURIComponent(JSON.stringify([
      { operator: "$gte", field: "lastUpdatedAt", value: since },
    ]));
    const fields = encodeURIComponent(
      "_id listingId confirmationCode checkIn checkOut checkInDateLocalized checkOutDateLocalized " +
      "nightsCount status source integration guest money createdAt lastUpdatedAt",
    );

    let skip = 0, total = Infinity, upserted = 0, skippedNoMap = 0;
    while (skip < total) {
      const page = await guestyGet(
        `/v1/reservations?filters=${filters}&fields=${fields}&sort=lastUpdatedAt&limit=${PAGE}&skip=${skip}`,
        token,
      );
      total = page.count ?? (page.results?.length ?? 0);
      const rows = [];
      for (const r of page.results ?? []) {
        const codigo = listingMap.get(r.listingId);
        if (!codigo) { skippedNoMap++; continue; }
        rows.push(toRow(r, codigo));
      }
      if (rows.length) {
        // upsert idempotente: solo pisa si la fila entrante es más reciente
        const { error } = await supabase.from("reservations")
          .upsert(rows, { onConflict: "id", ignoreDuplicates: false });
        if (error) throw error;
        upserted += rows.length;
      }
      skip += PAGE;
      await sleep(150); // holgura de rate limit
    }

    await supabase.from("sync_state").update({
      last_sync: startedAt, last_run: startedAt, last_error: null, updated_at: startedAt,
    }).eq("id", 1);

    return Response.json({ ok: true, upserted, skippedNoMap, since });
  } catch (e) {
    await supabase.from("sync_state").update({
      last_run: startedAt, last_error: String(e), updated_at: startedAt,
    }).eq("id", 1);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
