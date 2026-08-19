import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Stag · Dashboard Samavi",
  description: "Rendimiento neto por propiedad — Samavi Global Visión SL",
  // Instalable en la pantalla de inicio del iPhone: abre sin barra de direcciones, como
  // una app. `title` corto a propósito — debajo del icono no caben más de ~11 caracteres.
  appleWebApp: { capable: true, title: "Stag", statusBarStyle: "default" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // Pinta la barra de estado del mismo color que la página en cada tema.
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f9f9f7" },
    { media: "(prefers-color-scheme: dark)", color: "#0d0d0d" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
