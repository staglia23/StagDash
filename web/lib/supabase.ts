import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { cache } from "react";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && key);

// Cliente por request: lee la sesión de las cookies (@supabase/ssr) y firma cada consulta
// con el JWT del usuario (rol authenticated). Hasta la 059 las vistas también admiten anon;
// después del candado, este token es la ÚNICA vía de lectura. setAll es no-op a propósito:
// un server component no puede escribir cookies — el refresh de sesión lo hace el middleware
// antes de llegar acá.
// cache() de React: UN cliente por render, no uno por readView — la portada dispara ~16 en
// paralelo y 16 clientes sueltos podrían intentar 16 refresh con el mismo refresh token si
// el access token venciera a mitad de render (el primero lo rota, el resto quema el viejo).
// cache: "no-store" — sin esto, la Data Cache de Next puede servir respuestas viejas de
// Supabase incluso con dynamic="force-dynamic" (visto en local: KPIs pre-migración).
const clientePorRequest = cache(function clientePorRequest() {
  const jar = cookies();
  return createServerClient(url ?? "http://localhost:54321", key ?? "public-anon-key", {
    cookies: {
      getAll: () => jar.getAll(),
      setAll: () => {},
    },
    global: {
      fetch: (input: RequestInfo | URL, init?: RequestInit) =>
        fetch(input, { ...init, cache: "no-store" }),
    },
  });
});

/**
 * Email de la sesión (o null). Lo usa /anotar para saber qué notas son suyas y por tanto
 * corregibles. Va contra el servidor de Auth (getUser), no contra la cookie: una cookie
 * se puede editar a mano, y de esta respuesta depende que se pinte un botón de borrar.
 */
export async function emailSesion(): Promise<string | null> {
  if (!supabaseConfigured) return null;
  try {
    const { data } = await clientePorRequest().auth.getUser();
    return data.user?.email ?? null;
  } catch {
    return null;
  }
}

export type ViewQuery = {
  order?: { col: string; asc?: boolean };
  eq?: Record<string, string | number>;
  gte?: Record<string, string | number>;
  lt?: Record<string, string | number>;
};

/**
 * Lee una vista; devuelve fallback si no hay config o falla (para build/offline).
 *
 * Reintenta UNA vez ante un fallo de red. La portada dispara ~16 lecturas en paralelo y un
 * corte suelto no es teórico: se vio una carga en la que v_breakeven_ytd volvió vacía y la
 * tabla de margen asegurado pintó en rojo meses que en realidad solo estaban a medio vender
 * (sin equilibrio conocido, el semáforo no puede distinguirlos). Devolver [] en silencio
 * convierte un fallo de red en un número equivocado, que es peor que un hueco.
 */
export async function readView<T>(view: string, q: ViewQuery = {}, fallback: T[] = []): Promise<T[]> {
  if (!supabaseConfigured) return fallback;

  const supabase = clientePorRequest();

  const intentar = async () => {
    let query = supabase.from(view).select("*");
    for (const [col, v] of Object.entries(q.eq ?? {})) query = query.eq(col, v);
    for (const [col, v] of Object.entries(q.gte ?? {})) query = query.gte(col, v);
    for (const [col, v] of Object.entries(q.lt ?? {})) query = query.lt(col, v);
    if (q.order) query = query.order(q.order.col, { ascending: q.order.asc ?? true });
    const { data, error } = await query;
    if (error) throw error;
    return (data as T[]) ?? fallback;
  };

  try {
    return await intentar();
  } catch (e1) {
    console.warn(`readView(${view}) falló, reintentando:`, e1);
    try {
      await new Promise((r) => setTimeout(r, 250));
      return await intentar();
    } catch (e2) {
      console.error(`readView(${view}) falló también en el reintento:`, e2);
      return fallback;
    }
  }
}
