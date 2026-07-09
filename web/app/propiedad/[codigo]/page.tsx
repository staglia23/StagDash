import Link from "next/link";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import { eur, pct, MESES } from "@/lib/format";

export const dynamic = "force-dynamic";

type Fila = {
  codigo: string; anio: number; mes: number;
  ingreso_samavi: number; noches: number; reservas: number; ocup_pct: number; adr: number;
  total_gastos_directos: number; margen_directo: number;
  cuota_samavi_gen: number; margen_neto: number;
};

async function fetchDetalle(codigo: string): Promise<Fila[]> {
  if (!supabaseConfigured) return [];
  try {
    const { data, error } = await supabase
      .from("v_pnl_neto_propiedad")
      .select("*")
      .eq("codigo", codigo)
      .order("mes", { ascending: true });
    if (error) throw error;
    return (data as Fila[]) ?? [];
  } catch (e) {
    console.error(e);
    return [];
  }
}

export default async function PropiedadPage({ params }: { params: { codigo: string } }) {
  const codigo = decodeURIComponent(params.codigo);
  const filas = await fetchDetalle(codigo);

  return (
    <main className="container">
      <Link className="backlink" href="/">← Volver al dashboard</Link>
      <header className="header">
        <h1>{codigo}</h1>
        <div className="sub">Detalle mensual · margen directo y neto</div>
      </header>

      {filas.length === 0 ? (
        <div className="notice">Sin datos para esta propiedad (¿ingesta pendiente o código inexistente?).</div>
      ) : (
        <div className="table-wrap">
          <table className="ranking">
            <thead>
              <tr>
                <th>Mes</th>
                <th>Ingreso Samavi</th>
                <th>Noches</th>
                <th>Ocup.</th>
                <th>ADR</th>
                <th>Gastos directos</th>
                <th>Margen Directo</th>
                <th>Overhead</th>
                <th>Margen Neto</th>
              </tr>
            </thead>
            <tbody>
              {filas.map((f) => (
                <tr key={`${f.anio}-${f.mes}`}>
                  <td>{MESES[f.mes]} {f.anio}</td>
                  <td className="num">{eur(f.ingreso_samavi)}</td>
                  <td className="num">{f.noches}</td>
                  <td className="num">{pct(f.ocup_pct, 0)}</td>
                  <td className="num">{eur(f.adr)}</td>
                  <td className="num">{eur(f.total_gastos_directos)}</td>
                  <td className="num">{eur(f.margen_directo)}</td>
                  <td className="num">{eur(f.cuota_samavi_gen)}</td>
                  <td className={"num " + (f.margen_neto >= 0 ? "pos" : "neg")}>{eur(f.margen_neto)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
