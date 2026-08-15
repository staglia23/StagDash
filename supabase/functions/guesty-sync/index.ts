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
// v7: bruto POST-promoción (fareAccommodationAdjusted) → ADR/RevPAR reales. Ver migración 032.
// v5: getToken reintenta en 429. v6: cachea el token en sync_state (dura 24h) → no lo pide
//     en cada corrida, evitando el rate-limit del endpoint de token. (todo 24/07/2026)
// v8: ingiere también los bloqueos de calendario con su rótulo → guesty_bloqueos
//     (migración 081, 15/08/2026). Pata independiente: si falla, no tumba las reservas.

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
    // v7: POST-promoción. fareAccommodation es el precio de lista; cuando hay una promoción del
    // canal (Early bird, Last minute, estadía larga) el cobro real es fareAccommodationAdjusted,
    // y es ese el que cierra con el payout: adjusted + cleaning − hostServiceFee = hostPayout.
    // Usar el sin ajustar inflaba ADR y RevPAR (+1,56 % en la cartera 2026). Ver migración 032,
    // que corrigió el histórico desde money_raw sin volver a pedirle nada a Guesty.
    bruto: (m.fareAccommodationAdjusted ?? m.fareAccommodation ?? 0) + (m.fareCleaning ?? 0),
    host_service_fee: m.hostServiceFee ?? null,
    host_payout: m.hostPayout ?? null,
    total_paid: m.totalPaid ?? null,
    total_taxes: m.totalTaxes ?? null,
    money_raw: m,
    created_at: r.createdAt ?? null,
    last_updated_at: r.lastUpdatedAt ?? null,
  };
}

// ── v8: bloqueos de calendario con rótulo (migración 081) ──────────────────────────────
// Los bloqueos manuales eran invisibles para el motor (solo se ingerían reservas) y la señal
// de PriceLabs ('Blocked') no trae el rótulo. El calendario minified con view=full devuelve
// en una sola llamada cada día con sus blockIds y un mapa top-level days.blocks con type y
// note. Se excluyen los bloques de reservas (r/b: ya viven en reservations) y se descarta el
// objeto reservation anidado (PII de huéspedes). Ventana hoy → hoy+365, borrar y reinsertar
// por piso: un bloqueo quitado en Guesty debe desaparecer también de la tabla.
const DIAS_BLOQUEOS = 365;

async function syncBloqueos(supabase: any, token: string, listingMap: Map<string, string>) {
  const desde = new Date().toISOString().slice(0, 10);
  const hasta = new Date(Date.now() + DIAS_BLOQUEOS * 86_400_000).toISOString().slice(0, 10);
  let filas = 0;
  for (const [guestyId, codigo] of listingMap) {
    const cal = await guestyGet(
      `/v1/availability-pricing/api/calendar/listings/minified/${guestyId}?startDate=${desde}&endDate=${hasta}&view=full`,
      token,
    );
    // OJO: la respuesta real viene envuelta en {status, message, data:{days:{...}}} aunque el
    // spec de la doc la muestra sin envoltorio (verificado en vivo 15/08/2026, causó bloqueos:0
    // silencioso en la primera corrida). Se toleran ambas formas.
    const days = cal?.data?.days ?? cal?.days ?? {};
    const dias = days.calendar ?? [];
    const bloques = days.blocks ?? {};
    const rows: any[] = [];
    for (const dia of dias) {
      for (const blockId of dia.blockIds ?? []) {
        const b = bloques[blockId];
        if (!b || b.type === "r" || b.type === "b") continue; // reservas: ya viven en reservations
        const { reservation: _r, reservationId: _rid, ...sinReserva } = b;
        rows.push({
          codigo,
          fecha: dia.date,
          block_id: blockId,
          tipo: b.type ?? "?",
          nota: b.note ?? null,
          desde: b.startDate ?? null,
          hasta: b.endDate ?? null,
          created_by: b.createdBy ?? null,
          raw: sinReserva,
        });
      }
    }
    // refresco de ventana: borrar y reinsertar (un bloqueo quitado debe desaparecer)
    const del = await supabase.from("guesty_bloqueos")
      .delete().eq("codigo", codigo).gte("fecha", desde).lte("fecha", hasta);
    if (del.error) throw del.error;
    for (let i = 0; i < rows.length; i += 500) {
      const { error } = await supabase.from("guesty_bloqueos").insert(rows.slice(i, i + 500));
      if (error) throw error;
    }
    filas += rows.length;
    await sleep(150); // holgura de rate limit
  }
  return filas;
}

Deno.serve(async (req) => {
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  // Puerta (migración 069). Hasta el 04/08/2026 esta función corría con verify_jwt=false y
  // el handler ignoraba la request: `curl -X POST .../guesty-sync` devolvía 200 desde
  // cualquier parte de internet y escribía en la base con service_role (reproducido en la
  // auditoría). verify_jwt NO alcanza como arreglo: el gateway solo valida que el JWT esté
  // bien firmado, y la anon key —que es exactamente eso— va publicada en el bundle del
  // dashboard. El secreto compartido lo manda el cron en x-sync-secret y vive cifrado en
  // Vault: la base solo responde sí/no vía f_sync_secret_ok (ejecutable solo por service_role).
  const secreto = req.headers.get("x-sync-secret") ?? "";
  if (secreto.length < 32) return new Response("no autorizado", { status: 401 });
  const { data: autorizado } = await supabase.rpc("f_sync_secret_ok", { p_secreto: secreto });
  if (autorizado !== true) return new Response("no autorizado", { status: 401 });

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

    // v8: bloqueos con rótulo — pata independiente: si falla, no tumba la corrida de reservas
    let bloqueos: number | null = null;
    try {
      bloqueos = await syncBloqueos(supabase, token, listingMap);
      await supabase.from("sync_state").update({
        bloqueos_last_run: startedAt, bloqueos_last_error: null,
      }).eq("id", 1);
    } catch (e) {
      console.error(e);
      await supabase.from("sync_state").update({
        bloqueos_last_run: startedAt, bloqueos_last_error: String(e),
      }).eq("id", 1);
    }

    await supabase.from("sync_state").update({
      last_sync: startedAt, last_run: startedAt, last_error: null, updated_at: startedAt,
    }).eq("id", 1);

    return Response.json({ ok: true, upserted, skippedNoMap, bloqueos, since });
  } catch (e) {
    // el detalle va al log y a sync_state (de donde lo lee v_freshness), NO a la respuesta:
    // String(e) puede arrastrar el cuerpo crudo de error de Guesty o de Postgres
    console.error(e);
    await supabase.from("sync_state").update({
      last_run: startedAt, last_error: String(e), updated_at: startedAt,
    }).eq("id", 1);
    return Response.json({ ok: false }, { status: 500 });
  }
});
