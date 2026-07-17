// Stack de alertas y señales (02_Prompt §5.1):
//   · ALERTA = tiene fecha límite → countdown, consecuencia en una línea y acción enlazada.
//   · SEÑAL  = condición persistente sin fecha → diferenciada, sin countdown.
// Orden: alertas por fecha límite ascendente, señales después. Máximo 3 visibles, overflow "+N más".
import Link from "next/link";
import { propColor } from "@/lib/colors";
import { nombreCorto } from "@/lib/headline";

export type AlertaV2 = {
  tipo: string;
  codigo: string;
  severidad: string;
  mensaje: string;
  clase: "alerta" | "senal";
  fecha_limite: string | null;
  dias_restantes: number | null;
};

const MAX_VISIBLES = 3;
const PESO_SEV: Record<string, number> = { critical: 0, warning: 1 };

const fechaCorta = (iso: string) => {
  const [a, m, d] = iso.split("-");
  return `${d}/${m}/${a}`;
};

/** El mensaje de contrato trae la fecha embebida (compat v1); acá va estructurada en el chip. */
const consecuencia = (a: AlertaV2) =>
  a.clase === "alerta" ? a.mensaje.split(" — fecha límite")[0] : a.mensaje;

function accion(a: AlertaV2) {
  if (a.tipo === "contrato") {
    return { href: `/simulador?p=${encodeURIComponent(a.codigo)}`, label: "Simular renegociación →" };
  }
  return { href: `/p/${encodeURIComponent(a.codigo)}`, label: "Ver ficha →" };
}

function Fila({ a }: { a: AlertaV2 }) {
  const act = accion(a);
  const esAlerta = a.clase === "alerta";
  return (
    <li className={`av2 ${a.severidad} ${esAlerta ? "es-alerta" : "es-senal"}`}>
      <div className="av2-head">
        <span aria-hidden>{esAlerta ? "⏰" : "⚠️"}</span>
        <span className="dot" style={{ background: propColor(a.codigo) }} />
        <Link href={`/p/${encodeURIComponent(a.codigo)}`} className="alerta-prop">
          {nombreCorto(a.codigo)}
        </Link>
        {esAlerta && a.dias_restantes != null && a.fecha_limite ? (
          <span className={"countdown " + a.severidad}>
            {a.dias_restantes === 0 ? "vence hoy"
              : a.dias_restantes === 1 ? "falta 1 día"
              : `faltan ${a.dias_restantes} días`} · {fechaCorta(a.fecha_limite)}
          </span>
        ) : (
          <span className="tag-senal">señal</span>
        )}
      </div>
      <div className="av2-msg">{consecuencia(a)}</div>
      <Link href={act.href} className="av2-accion">{act.label}</Link>
    </li>
  );
}

export function AlertStack({ rows }: { rows: AlertaV2[] }) {
  if (!rows.length) {
    return (
      <div className="alerta ok">
        ✅ <span className="alerta-msg">Nada con fecha límite ni señales de riesgo activas.</span>
      </div>
    );
  }

  const alertas = rows.filter((r) => r.clase === "alerta")
    .sort((a, b) => (a.dias_restantes ?? 999) - (b.dias_restantes ?? 999));
  const senales = rows.filter((r) => r.clase !== "alerta")
    .sort((a, b) => (PESO_SEV[a.severidad] ?? 9) - (PESO_SEV[b.severidad] ?? 9));
  const orden = [...alertas, ...senales];
  const visibles = orden.slice(0, MAX_VISIBLES);
  const resto = orden.slice(MAX_VISIBLES);

  return (
    <div>
      <ul className="alertas">
        {visibles.map((a, i) => <Fila key={`${a.tipo}-${a.codigo}-${i}`} a={a} />)}
      </ul>
      {resto.length > 0 && (
        <details className="alertas-mas">
          <summary>+{resto.length} más</summary>
          <ul className="alertas">
            {resto.map((a, i) => <Fila key={`${a.tipo}-${a.codigo}-${i}`} a={a} />)}
          </ul>
        </details>
      )}
    </div>
  );
}
