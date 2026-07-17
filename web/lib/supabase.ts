import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && key);

// Cliente de solo lectura (anon key). Solo puede leer las VISTAS del dashboard (ver RLS).
// cache: "no-store" — sin esto, la Data Cache de Next puede servir respuestas viejas de
// Supabase incluso con dynamic="force-dynamic" (visto en local: KPIs pre-migración).
export const supabase = createClient(url ?? "http://localhost:54321", key ?? "public-anon-key", {
  global: {
    fetch: (input: RequestInfo | URL, init?: RequestInit) =>
      fetch(input, { ...init, cache: "no-store" }),
  },
});

export type ViewQuery = {
  order?: { col: string; asc?: boolean };
  eq?: Record<string, string | number>;
  gte?: Record<string, string | number>;
  lt?: Record<string, string | number>;
};

/** Lee una vista; devuelve fallback si no hay config o falla (para build/offline). */
export async function readView<T>(view: string, q: ViewQuery = {}, fallback: T[] = []): Promise<T[]> {
  if (!supabaseConfigured) return fallback;
  try {
    let query = supabase.from(view).select("*");
    for (const [col, v] of Object.entries(q.eq ?? {})) query = query.eq(col, v);
    for (const [col, v] of Object.entries(q.gte ?? {})) query = query.gte(col, v);
    for (const [col, v] of Object.entries(q.lt ?? {})) query = query.lt(col, v);
    if (q.order) query = query.order(q.order.col, { ascending: q.order.asc ?? true });
    const { data, error } = await query;
    if (error) throw error;
    return (data as T[]) ?? fallback;
  } catch (e) {
    console.error(`readView(${view}) falló:`, e);
    return fallback;
  }
}
