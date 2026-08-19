import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { validarNota } from "@/lib/notas";

// POST /anotar/guardar — la ÚNICA escritura del dashboard (migración 087). Form POST
// clásico, como /auth/signout: funciona sin JavaScript.
//
// No escribe en la tabla directamente: llama a `f_nota_add`, que es lo único que
// `authenticated` puede ejecutar. El autor lo pone el JWT del lado del servidor, así que el
// navegador no puede firmar una nota en nombre de otro. Y la nota no imputa nada: cae en la
// bandeja como SIN_PROCESAR y se convierte en recobro o event con revisión humana.
//
// Siempre redirige (303) en vez de devolver JSON: el usuario vuelve a /anotar y ve el
// resultado en pantalla, y un refresh no reenvía el formulario.
export async function POST(req: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const volver = (query: string) =>
    NextResponse.redirect(new URL(`/anotar${query}`, req.url), { status: 303 });

  let texto = "";
  try {
    const form = await req.formData();
    texto = String(form.get("texto") ?? "");
  } catch {
    return volver("?error=fallo");
  }

  // Se valida acá con la MISMA función que la pantalla: el tope y el recorte tienen que
  // coincidir con los de la función SQL, o el rechazo llegaría después de "Guardar".
  const nota = validarNota(texto);
  if (!nota.ok) return volver("?error=vacia");

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

  const { error } = await supabase.rpc("f_nota_add", { p_texto: nota.texto });
  if (error) {
    // El detalle va al log del servidor, no a la URL: puede traer parte del texto dictado.
    console.error("f_nota_add falló:", error.message);
    return volver("?error=fallo");
  }

  return volver("?ok=1");
}
