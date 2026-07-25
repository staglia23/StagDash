// limpieza-ingest — Edge Function (Deno)
// Recibe el resultado de la conciliación de Ecocleans (Apps Script) y lo escribe en
// `limpieza_mensual`, que es lo que consume el motor vía v_limpieza_mensual (migración 031).
//
// POR QUÉ UNA EDGE FUNCTION Y NO UN INSERT DIRECTO:
// `limpieza_mensual` está REVOKEd de anon, así que la anon key no puede escribirla. La
// alternativa sería meter la service_role key en el Apps Script, y esa key lee y escribe TODA
// la base (incluida la PII de propietarios). Un secreto propio, que solo sirve para escribir
// esta tabla, es la superficie mínima: si se filtra, lo peor que pasa es que alguien meta
// costes de limpieza falsos, y se rota sin tocar nada más.
//
// Secrets requeridos (Supabase → Edge Functions → Secrets):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (los pone Supabase solo)
//   LIMPIEZA_INGEST_TOKEN                    (inventarlo largo y aleatorio; va en el header)
//
// Contrato:
//   POST  { anio, mes, factura, filas: [{ codigo, servicios, horas, limpieza_eur,
//                                         kits_eur, renting_eur, fiable }] }
//   Header: x-ingest-token: <LIMPIEZA_INGEST_TOKEN>
//   → 200 { ok: true, escritas: n }
//
// Es idempotente: upsert por (anio, mes, codigo). Reprocesar un mes lo pisa, no lo duplica.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const IVA = 0.21;
const CODIGOS = ["1A_NICA", "4B_ALEX", "3G_MARE", "1A_JACO"];

const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`Falta el secret ${k}`);
  return v;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const redondear = (n: number) => Math.round(n * 100) / 100;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Solo POST" }, 405);

  // Comparación normal: el token no es material criptográfico de sesión y el endpoint no está
  // en un camino donde un timing attack sea realista. Si algún día lo fuera, usar timingSafeEqual.
  if (req.headers.get("x-ingest-token") !== env("LIMPIEZA_INGEST_TOKEN")) {
    return json({ error: "Token inválido" }, 401);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body no es JSON" }, 400);
  }

  const { anio, mes, factura, filas } = body ?? {};
  if (!Number.isInteger(anio) || !Number.isInteger(mes) || mes < 1 || mes > 12) {
    return json({ error: "anio/mes inválidos" }, 400);
  }
  if (!Array.isArray(filas) || filas.length === 0) {
    return json({ error: "filas vacío" }, 400);
  }

  const rows = [];
  for (const f of filas) {
    if (!CODIGOS.includes(f?.codigo)) {
      return json({ error: `codigo desconocido: ${f?.codigo}` }, 400);
    }
    const limpieza = Number(f.limpieza_eur) || 0;
    const kits = Number(f.kits_eur) || 0;
    const renting = Number(f.renting_eur) || 0;
    const base = redondear(limpieza + kits + renting);
    rows.push({
      anio,
      mes,
      codigo: f.codigo,
      servicios: Number(f.servicios) || 0,
      horas: Number(f.horas) || 0,
      limpieza_eur: redondear(limpieza),
      kits_eur: redondear(kits),
      renting_eur: redondear(renting),
      base_eur: base,
      iva_eur: redondear(base * IVA),
      factura: factura ?? null,
      // El Apps Script manda false cuando su lectura fila-a-fila no cuadró con el resumen de
      // la factura: el dato entra igual, pero el dashboard lo etiqueta como 'real_revisar'.
      fiable: f.fiable !== false,
      cargado_at: new Date().toISOString(),
    });
  }

  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const { error } = await supabase
    .from("limpieza_mensual")
    .upsert(rows, { onConflict: "anio,mes,codigo" });

  if (error) return json({ error: error.message }, 500);
  return json({ ok: true, escritas: rows.length });
});
