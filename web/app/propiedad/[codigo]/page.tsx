// Ruta v1 conservada por compatibilidad (links guardados): redirige a la ficha v2.
import { permanentRedirect } from "next/navigation";

export default function PropiedadLegacy({ params }: { params: { codigo: string } }) {
  permanentRedirect(`/p/${params.codigo}`);
}
