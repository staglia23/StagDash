// Tira de los próximos 30 días: la visión periférica en un vistazo — noche vendida
// (color de la propiedad) vs abierta (hueco). Decorativa con resumen textual accesible.
export type DiaForward = { dia: string; vendida: boolean };

export function Salud30({ dias, color, grande = false }: {
  dias: DiaForward[]; color: string; grande?: boolean;
}) {
  const vendidas = dias.filter((d) => d.vendida).length;
  return (
    <div className={"tira30" + (grande ? " grande" : "")}
      role="img"
      aria-label={`${vendidas} de ${dias.length} noches vendidas en los próximos 30 días`}>
      {dias.map((d, i) => {
        const diaMes = Number(d.dia.slice(8, 10));
        return (
          <span key={d.dia}
            className={"tira30-celda" + (d.vendida ? " vendida" : "") + (diaMes === 1 ? " mes-nuevo" : "")}
            style={d.vendida ? { background: color } : undefined}>
            {grande && (i === 0 || diaMes === 1 || diaMes % 5 === 0) ? (
              <span className="tira30-num">{diaMes}</span>
            ) : null}
          </span>
        );
      })}
    </div>
  );
}
