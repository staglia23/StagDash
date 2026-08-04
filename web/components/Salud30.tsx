// Tira de los próximos 30 días: la visión periférica en un vistazo — noche vendida
// (color de la propiedad) vs abierta (hueco).
//
// v2 (05/08/2026, opción B elegida por Stag). La v1 confundía: mostraba una marca en el
// día 1 sin decir de qué mes era, y como la ventana es MÓVIL (hoy → +30 días), esa marca
// caía casi al final y parecía un error ("recién arranqué agosto y la marca está al
// final"). No estaba rota: señalaba el 1 de SEPTIEMBRE. Ahora la tira lo dice sola:
//   · el día de hoy va marcado con un borde,
//   · el cambio de mes es una línea de puntos con el nombre del mes nuevo,
//   · debajo van los números de día como referencia.
import { MESES } from "@/lib/format";

export type DiaForward = { dia: string; vendida: boolean };

/** "2026-08-05" → {dia: 5, mes: 8} sin pasar por Date (evita corrimientos de zona). */
const partes = (iso: string) => ({ dia: Number(iso.slice(8, 10)), mes: Number(iso.slice(5, 7)) });

export function Salud30({ dias, color, grande = false, hoyIso }: {
  dias: DiaForward[];
  color: string;
  grande?: boolean;
  /** Día de hoy en Europe/Madrid; si no llega, se asume el primero de la ventana. */
  hoyIso?: string;
}) {
  if (dias.length === 0) return null;
  const vendidas = dias.filter((d) => d.vendida).length;
  const idxHoy = hoyIso ? dias.findIndex((d) => d.dia === hoyIso) : 0;
  // índice donde empieza el mes siguiente (día 1), si cae dentro de la ventana
  const idxMesNuevo = dias.findIndex((d, i) => i > 0 && partes(d.dia).dia === 1);
  const mesNuevo = idxMesNuevo > 0 ? MESES[partes(dias[idxMesNuevo].dia).mes] : null;

  return (
    <div className={"tira30-wrap" + (grande ? " grande" : "")}>
      <div className="tira30"
        role="img"
        aria-label={`${vendidas} de ${dias.length} noches vendidas entre el ${partes(dias[0].dia).dia} de ${MESES[partes(dias[0].dia).mes]} y el ${partes(dias[dias.length - 1].dia).dia} de ${MESES[partes(dias[dias.length - 1].dia).mes]}`}>
        {dias.map((d, i) => (
          <span key={d.dia}
            className={"tira30-celda" + (d.vendida ? " vendida" : "")
              + (i === idxHoy ? " hoy" : "") + (i === idxMesNuevo ? " mes-nuevo" : "")}
            style={d.vendida ? { background: color } : undefined} />
        ))}
      </div>

      {/* Números de día: uno de cada cinco, más hoy y el cambio de mes. Sin esto la tira
          no dice a qué fechas se refiere y hay que adivinarlas. */}
      <div className="tira30-dias" aria-hidden="true">
        {dias.map((d, i) => {
          const { dia } = partes(d.dia);
          const marca = i === idxHoy || i === idxMesNuevo || dia % 5 === 0;
          return (
            <span key={d.dia}
              className={"t30d" + (i === idxHoy ? " hoy" : "") + (i === idxMesNuevo ? " mes" : "")}>
              {marca ? dia : ""}
            </span>
          );
        })}
      </div>

      <div className="tira30-pie">
        <span><b>hoy</b> {partes(dias[Math.max(idxHoy, 0)].dia).dia} {MESES[partes(dias[Math.max(idxHoy, 0)].dia).mes]}</span>
        {mesNuevo ? <span className="t30-mes">┊ empieza {mesNuevo}</span> : null}
        <span>{partes(dias[dias.length - 1].dia).dia} {MESES[partes(dias[dias.length - 1].dia).mes]}</span>
      </div>
    </div>
  );
}
