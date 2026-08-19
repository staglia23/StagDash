import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { validarNota } from "@/lib/notas";

// POST /anotar/guardar — crea una nota, o corrige una existente si viene `id` (088).
// Form POST clásico, como /auth/signout: funciona sin JavaScript.
//
// No escribe en la tabla directamente: llama a `f_nota_add` / `f_nota_editar`, lo único que
// `authenticated` puede ejecutar. El autor y el permiso los resuelve la base con el JWT, no
// el cliente: el navegador no puede firmar ni corregir una nota en nombre de otro.
//
// Siempre redirige (303): el usuario vuelve a /anotar y ve el resultado en pantalla, y un
// refresh no reenvía el formulario.
export async function POST(req: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const volver = (query: string) =>
    NextResponse.redirect(new URL(`/anotar${query}`, req.url), { status: 303 });

  let texto = "";
  let id: number | null = null;
  try {
    const form = await req.formData();
    texto = String(form.get("texto") ?? "");
    const crudo = form.get("id");
    if (crudo != null && String(crudo) !== "") {
      const n = Number(crudo);
      if (!Number.isInteger(n) || n <= 0) return volver("?error=fallo");
      id = n;
    }
  } catch {
    return volver("?error=fallo");
  }

  // Se valida acá con la MISMA función que la pantalla: el tope y el recorte tienen que
  // coincidir con los de la función SQL, o el rechazo llegaría después de "Guardar".
  const nota = validarNota(texto);
  if (!nota.ok) return volver(id ? `?error=vacia&editar=${id}` : "?error=vacia");

  if (!url || !key) return volver("?error=fallo");

  const jar = cookies();
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => jar.getAll(),
      // Un route handler SÍ puede escribir cookies: si el access token se renovó en esta
      // request, hay que quedarse con el nuevo (perderlo revoca la sesión entera).
      setAll: (cs: { name: string; value: string; options: CookieOptions }[]) =>
        cs.forEach(({ name, value, options }) => jar.set(name, value, options)),
    },
  });

  const { error } =
    id == null
      ? await supabase.rpc("f_nota_add", { p_texto: nota.texto })
      : await supabase.rpc("f_nota_editar", { p_id: id, p_texto: nota.texto });

  if (error) {
    // El detalle va al log del servidor, no a la URL: puede traer parte del texto dictado.
    console.error("guardar nota falló:", error.message);
    // 42501 = la base rechazó tocarla (ya procesada, o de otro autor). No es un fallo
    // técnico y merece un mensaje distinto: "reintentá" sería un consejo inútil.
    return volver(error.code === "42501" ? "?error=tarde" : "?error=fallo");
  }

  return volver(id == null ? "?ok=guardada" : "?ok=corregida");
}
