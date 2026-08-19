import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Stag · Dashboard Samavi",
  description: "Rendimiento neto por propiedad — Samavi Global Visión SL",
  // Instalable en la pantalla de inicio del iPhone: abre sin barra de direcciones, como
  // una app. `title` corto a propósito — debajo del icono no caben más de ~11 caracteres.
  //
  // AQUÍ NO VA UN MANIFIESTO (web app manifest), y es deliberado. Cuando la página enlaza
  // uno, iOS abre el acceso en su `start_url` en vez de en la página desde la que lo
  // creaste: el icono de "Anotar" llevaba a la portada. Darle a /anotar un manifiesto
  // propio con start_url "/anotar" tampoco lo arregló (19/08/2026, probado en el iPhone de
  // Stag). Sin manifiesto, Safari usa la URL actual, que es el comportamiento de toda la
  // vida y el que hace falta. Los iconos y el nombre no dependen de él: salen de
  // `appleWebApp` y de los apple-icon.tsx.
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
