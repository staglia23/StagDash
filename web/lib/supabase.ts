import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && key);

// Cliente de solo lectura (anon key). Solo puede leer las VISTAS del dashboard (ver RLS).
export const supabase = createClient(url ?? "http://localhost:54321", key ?? "public-anon-key");

/** Lee una vista; devuelve fallback si no hay config o falla (para build/offline). */
export async function readView<T>(view: string, order?: { col: string; asc?: boolean }, fallback: T[] = []): Promise<T[]> {
  if (!supabaseConfigured) return fallback;
  try {
    let q = supabase.from(view).select("*");
    if (order) q = q.order(order.col, { ascending: order.asc ?? true });
    const { data, error } = await q;
    if (error) throw error;
    return (data as T[]) ?? fallback;
  } catch (e) {
    console.error(`readView(${view}) falló:`, e);
    return fallback;
  }
}
