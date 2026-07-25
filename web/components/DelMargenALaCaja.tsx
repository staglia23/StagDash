// "Del margen a la caja" — el puente entre el margen operativo que muestra la portada y lo
// que de verdad le queda a la empresa. Vive en /analisis, no en la portada: es contexto de
// diagnóstico, y la provisión es una estimación, no un dato devengado.
//
// Regla del prompt CEO: todo importe etiquetado. Acá conviven tres naturalezas distintas y
// mezclarlas sería el error — real devengado (margen), plata de terceros (IVA) y estimación
// (provisión IS). Cada línea dice cuál es.
import { eur, pct } from "@/lib/format";
import { calcularFiscal } from "@/lib/impuestos";

export function DelMargenALaCaja({ contribucion, overheadOperativo, margenOperativo,
  costesCorporativos, resultado, ivaRepercutido, ivaSoportadoRenta, anio }: {
  contribucion: number; overheadOperativo: number; margenOperativo: number;
  costesCorporativos: number; resultado: number;
  ivaRepercutido: number; ivaSoportadoRenta: number; anio: number;
}) {
  const f = calcularFiscal(resultado);

  return (
    <div className="card fiscal-card">
      <div className="fiscal-fila">
        <span>Contribución de los 4 pisos <span className="tag">real devengado</span></span>
        <strong className={contribucion >= 0 ? "pos" : "neg"}>
          {contribucion >= 0 ? "+" : "−"}{eur(Math.abs(contribucion))}
        </strong>
      </div>
      <div className="fiscal-fila">
        <span>Overhead de gestión <span className="tag">por días bajo gestión</span></span>
        <strong className="neg">−{eur(Math.abs(overheadOperativo))}</strong>
      </div>
      <div className="fiscal-fila">
        <span>Margen operativo de los pisos</span>
        <strong className={margenOperativo >= 0 ? "pos" : "neg"}>
          {margenOperativo >= 0 ? "+" : "−"}{eur(Math.abs(margenOperativo))}
        </strong>
      </div>
      <div className="fiscal-fila">
        <span>Costes corporativos <span className="tag">no asignables</span></span>
        <strong className="neg">−{eur(Math.abs(costesCorporativos))}</strong>
      </div>
      <div className="fiscal-fila">
        <span>Resultado de Samavi <span className="tag">antes de impuestos</span></span>
        <strong className={resultado >= 0 ? "pos" : "neg"}>
          {resultado >= 0 ? "+" : "−"}{eur(Math.abs(resultado))}
        </strong>
      </div>
      <div className="fiscal-fila">
        <span>Provisión Impuesto de Sociedades ({pct(f.tipo, 0)}) <span className="tag">estimado</span></span>
        <strong className={f.provisionIS > 0 ? "neg" : "muted"}>
          {f.provisionIS > 0 ? `−${eur(f.provisionIS)}` : eur(0)}
        </strong>
      </div>
      <div className="fiscal-fila fiscal-total">
        <span>Queda estimado para la empresa</span>
        <strong className={f.quedaEstimado >= 0 ? "pos" : "neg"}>
          {f.quedaEstimado >= 0 ? "+" : "−"}{eur(Math.abs(f.quedaEstimado))}
        </strong>
      </div>

      <p className="fiscal-nota">
        Los <strong>costes corporativos</strong> —intereses y notaría del préstamo, el litigio
        con los gestores anteriores, formación y marketing de crecimiento— no se reparten entre
        los pisos: no son coste de gestionarlos. Prorratearlos mezclaba el resultado operativo
        con el financiero y hacía que cada propiedad pareciera peor de lo que es.
      </p>

      <p className="fiscal-nota">
        La provisión es un <strong>techo prudente, no una previsión de pago</strong>: Samavi
        viene compensando bases imponibles negativas de ejercicios anteriores — el IS de 2025
        no salió a pagar —, así que mientras queden BINs el importe real es menor y puede ser
        cero. El tipo definitivo lo confirma Confisic.
      </p>

      {ivaSoportadoRenta > 0 ? (
        <p className="fiscal-nota">
          El margen de arriba ya <strong>carga {eur(ivaSoportadoRenta)} de IVA soportado</strong> de
          las rentas de Alexander y Marechal, bajo la hipótesis prudente de que NO sea deducible
          (consulta abierta con Confisic desde abril: régimen de IVA de los pisos de Madrid).
          Si resulta deducible, el margen sube ese importe y Alexander vuelve a positivo.
        </p>
      ) : null}

      {ivaRepercutido > 0 ? (
        <p className="fiscal-nota">
          Aparte, <strong>{eur(ivaRepercutido)}</strong> de IVA repercutido por la comisión de
          Jacobine pasaron por la cuenta en {anio}: son de Hacienda, no de Samavi, y desde el
          25/07/2026 ya están fuera del margen (antes lo inflaban).
        </p>
      ) : null}
    </div>
  );
}
