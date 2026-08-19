import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

// POST /anotar/borrar — tira una nota dictada por error (088).
//
// Borrado de verdad, no marca de "descartada": lo que se dijo sin querer no tiene por qué
// quedar en la bandeja. Quien decide si se puede es `f_nota_borrar` en la base — solo notas
// propias y solo mientras sigan SIN_PROCESAR. El `id` que manda el navegador no es una
// autorización: si no es suya, la base lo rechaza con 42501.
export async function POST(req: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const volver = (query: string) =>
    NextResponse.redirect(new URL(`/anotar${query}`, req.url), { status: 303 });

  let id: number;
  try {
    const form = await req.formData();
    id = Number(form.get("id"));
    if (!Number.isInteger(id) || id <= 0) return volver("?error=fallo");
  } catch {
    return volver("?error=fallo");
  }

  if (!url || !key) return volver("?error=fallo");

  const jar = cookies();
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => jar.getAll(),
      setAll: (cs: { name: string; value: string; options: CookieOptions }[]) =>
        cs.forEach(({ name, value, options }) => jar.set(name, value, options)),
    },
  });

  const { error } = await supabase.rpc("f_nota_borrar", { p_id: id });
  if (error) {
    console.error("borrar nota falló:", error.message);
    return volver(error.code === "42501" ? "?error=tarde" : "?error=fallo");
  }

  return volver("?ok=borrada");
}
