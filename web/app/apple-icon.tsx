// Icono de la pantalla de inicio del iPhone (180×180, el tamaño que pide iOS).
//
// Se genera en el build en vez de guardar un PNG en el repo: así el color sale de los
// mismos tokens que el dashboard y no hay un binario que se olvide de actualizar. Sin
// esto, iOS usa una captura de la página como icono y queda ilegible.
//
// Fondo pleno (el sistema recorta las esquinas él solo) y una "S" blanca sobre el azul de
// acento — el mismo que ya cumple contraste AA con texto blanco (--accent-bg de globals.css).
import { ImageResponse } from "next/og";

export const size = { width: 180, height: 180 };
export const contentType = "image/png";

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#1f5eb0",
          color: "#ffffff",
          // La fuente por defecto de ImageResponse no trae negrita, así que el peso se
          // consigue con tamaño: una "S" fina se deshace a 60 pt en la pantalla de inicio.
          fontSize: 140,
        }}
      >
        S
      </div>
    ),
    size,
  );
}
