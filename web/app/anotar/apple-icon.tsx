// Icono propio de /anotar: si Stag se pone las dos pantallas en la pantalla de inicio, dos
// iconos idénticos no sirven de nada. Este es el de dictar — micrófono dibujado con cajas
// (nada de emoji: Satori necesitaría bajarse una fuente de emoji en el build).
//
// Fondo oscuro para distinguirlo de un vistazo del icono azul del dashboard.
import { ImageResponse } from "next/og";

export const size = { width: 180, height: 180 };
export const contentType = "image/png";

export default function AppleIconAnotar() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "#0b0b0b",
        }}
      >
        {/* cápsula del micrófono */}
        <div style={{ width: 52, height: 74, borderRadius: 26, background: "#ffffff" }} />
        {/* arco que lo rodea: una caja con solo tres bordes y las esquinas de abajo redondas */}
        <div
          style={{
            width: 92,
            height: 34,
            marginTop: -12,
            borderLeft: "11px solid #ffffff",
            borderRight: "11px solid #ffffff",
            borderBottom: "11px solid #ffffff",
            borderRadius: "0 0 46px 46px",
          }}
        />
        {/* pie */}
        <div style={{ width: 11, height: 16, background: "#ffffff" }} />
        <div style={{ width: 46, height: 11, borderRadius: 6, background: "#ffffff" }} />
      </div>
    ),
    size,
  );
}
