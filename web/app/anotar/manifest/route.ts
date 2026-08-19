import { NextResponse } from "next/server";

// Manifiesto PROPIO de /anotar. Existe por un fallo real: al añadir "Anotar" a la pantalla
// de inicio, el iPhone abría la portada del dashboard. La causa es que iOS, cuando la página
// enlaza un manifiesto, usa su `start_url` en vez de la página en la que estás — y el del
// layout raíz apunta a "/". Con éste, las dos interpretaciones posibles (el `start_url` del
// manifiesto, o la URL actual) llevan al mismo sitio: /anotar.
//
// `scope` es "/" a propósito: con "/anotar", tocar "← Morning Check" dentro de la app
// instalada se saldría a Safari.
export const dynamic = "force-static";

export function GET() {
  const manifiesto = {
    name: "Anotar — Stag",
    short_name: "Anotar",
    description: "Dictar un gasto en el momento en que ocurre",
    start_url: "/anotar",
    scope: "/",
    display: "standalone",
    background_color: "#0d0d0d",
    theme_color: "#1f5eb0",
    lang: "es",
    icons: [{ src: "/anotar/apple-icon", sizes: "180x180", type: "image/png" }],
  };
  return new NextResponse(JSON.stringify(manifiesto), {
    headers: { "content-type": "application/manifest+json" },
  });
}
