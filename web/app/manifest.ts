// Manifiesto de la app instalable. En iOS casi todo lo decide `appleWebApp` del layout,
// pero esto es lo que hace que en Android y en escritorio se instale con nombre e icono
// propios en vez de "stag-dash.vercel.app".
import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Stag · Dashboard Samavi",
    short_name: "Stag",
    description: "Rendimiento neto por propiedad — Samavi Global Visión SL",
    start_url: "/",
    display: "standalone",
    background_color: "#0d0d0d",
    theme_color: "#1f5eb0",
    lang: "es",
    icons: [{ src: "/apple-icon", sizes: "180x180", type: "image/png" }],
  };
}
