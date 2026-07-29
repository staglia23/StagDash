import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

// POST /auth/signout — cierra la sesión (revoca el refresh token y limpia las cookies)
// y vuelve a /login. Es un form POST clásico: funciona sin JavaScript.
export async function POST(req: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (url && key) {
    const jar = cookies();
    const supabase = createServerClient(url, key, {
      cookies: {
        getAll: () => jar.getAll(),
        setAll: (cs: { name: string; value: string; options: CookieOptions }[]) =>
          cs.forEach(({ name, value, options }) => jar.set(name, value, options)),
      },
    });
    await supabase.auth.signOut();
  }

  return NextResponse.redirect(new URL("/login", req.url), { status: 303 });
}
