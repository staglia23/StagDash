import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Puerta del dashboard: sin sesión → /login. También refresca el token de sesión
// (getUser) y propaga las cookies renovadas, que es lo que permite que los server
// components lean las vistas con un JWT vigente sin poder escribir cookies ellos mismos.
export async function middleware(req: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  let res = NextResponse.next({ request: req });

  // Local sin .env.local: no hay a quién preguntarle por la sesión; el dashboard ya
  // muestra su aviso de "sin configuración" y bloquear acá solo taparía ese mensaje.
  if (!url || !key) return res;

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => req.cookies.getAll(),
      setAll: (cs: { name: string; value: string; options: CookieOptions }[]) => {
        cs.forEach(({ name, value }) => req.cookies.set(name, value));
        res = NextResponse.next({ request: req });
        cs.forEach(({ name, value, options }) => res.cookies.set(name, value, options));
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const ruta = req.nextUrl.pathname;
  const esPublica = ruta === "/login" || ruta.startsWith("/auth/");

  // Un redirect NO hereda `res`: hay que copiarle las cookies que getUser() pueda haber
  // renovado. Perderlas deja al navegador con el refresh token viejo ya consumido y,
  // pasada la ventana de reutilización de GoTrue, Supabase revoca la familia de sesiones
  // entera (logout forzado en todos los dispositivos).
  const redirigir = (pathname: string) => {
    const dest = req.nextUrl.clone();
    dest.pathname = pathname;
    dest.search = "";
    // 303 en los POST (el form de /anotar): el 307 por defecto CONSERVA el método, así que
    // una sesión vencida justo al guardar reenviaría el POST contra /login y reventaría.
    // El 303 obliga al navegador a pedir /login con GET y a mostrar el formulario de entrada.
    const redir = NextResponse.redirect(dest, req.method === "GET" ? undefined : 303);
    res.cookies.getAll().forEach((c) => redir.cookies.set(c));
    return redir;
  };

  if (!user && !esPublica) return redirigir("/login");
  if (user && ruta === "/login") return redirigir("/");
  return res;
}

export const config = {
  // Todo menos los estáticos que sirve Next: el HTML de CADA página pasa por la puerta.
  //
  // OJO — no volver a excluir por extensión (`.*\\.(?:svg|png|jpg…)$`). Esa alternativa no
  // estaba anclada a carpetas de assets, y como `/p/[id]` es un segmento dinámico que acepta
  // puntos, `/p/1A_NICA.png` caía FUERA del matcher: el middleware no corría y el server
  // component se renderizaba sin comprobar sesión (verificado en producción el 04/08/2026,
  // 200 en vez de 307 → /login; también con .svg .jpg .jpeg .webp .ico y en mayúsculas).
  // No protegía ningún asset real: `web/public/` no existe y `_next/static` ya está excluido.
  matcher: ["/((?!_next/static|_next/image|favicon\\.ico).*)"],
};
