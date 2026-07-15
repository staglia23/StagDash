import Link from "next/link";
import { eur, pct } from "@/lib/format";
import { propColor } from "@/lib/colors";

export type RankingRow = {
  codigo: string;
  ingreso_samavi: number;
  margen_directo: number;
  cuota_samavi_gen: number;
  margen_neto: number;
  margen_neto_pct: number;
  eur_noche_neto: number;
  ocup_pct: number;
  adr: number;
};

function Neto({ v }: { v: number }) {
  const cls = v >= 0 ? "pos" : "neg";
  const arrow = v >= 0 ? "▲" : "▼";
  return <span className={cls}>{arrow} {eur(v)}</span>;
}

export function RankingTable({ rows }: { rows: RankingRow[] }) {
  const tot = rows.reduce(
    (a, r) => ({
      ingreso_samavi: a.ingreso_samavi + Number(r.ingreso_samavi ?? 0),
      margen_directo: a.margen_directo + Number(r.margen_directo ?? 0),
      cuota_samavi_gen: a.cuota_samavi_gen + Number(r.cuota_samavi_gen ?? 0),
      margen_neto: a.margen_neto + Number(r.margen_neto ?? 0),
    }),
    { ingreso_samavi: 0, margen_directo: 0, cuota_samavi_gen: 0, margen_neto: 0 },
  );
  const totPct = tot.ingreso_samavi ? tot.margen_neto / tot.ingreso_samavi : 0;

  return (
    <div className="table-wrap">
      <table className="ranking">
        <thead>
          <tr>
            <th>Propiedad</th>
            <th>Ingreso Samavi</th>
            <th>Margen Directo</th>
            <th>Overhead</th>
            <th>Margen Neto</th>
            <th>% Margen</th>
            <th>€/noche neto</th>
            <th>Ocup.</th>
            <th>ADR</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.codigo}>
              <td>
                <span className="dot" style={{ background: propColor(r.codigo) }} />
                <Link href={`/propiedad/${r.codigo}`}>{r.codigo}</Link>
              </td>
              <td className="num">{eur(r.ingreso_samavi)}</td>
              <td className="num">{eur(r.margen_directo)}</td>
              <td className="num">{eur(r.cuota_samavi_gen)}</td>
              <td className="num"><Neto v={Number(r.margen_neto)} /></td>
              <td className="num">{pct(r.margen_neto_pct)}</td>
              <td className="num">{eur(r.eur_noche_neto)}</td>
              <td className="num">{pct(r.ocup_pct, 0)}</td>
              <td className="num">{eur(r.adr)}</td>
            </tr>
          ))}
          <tr className="total">
            <td>TOTAL Samavi</td>
            <td className="num">{eur(tot.ingreso_samavi)}</td>
            <td className="num">{eur(tot.margen_directo)}</td>
            <td className="num">{eur(tot.cuota_samavi_gen)}</td>
            <td className="num"><Neto v={tot.margen_neto} /></td>
            <td className="num">{pct(totPct)}</td>
            <td className="num">—</td>
            <td className="num">—</td>
            <td className="num">—</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
