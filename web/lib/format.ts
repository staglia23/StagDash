export const eur = (n: number | null | undefined, dec = 0) =>
  new Intl.NumberFormat("es-ES", {
    style: "currency", currency: "EUR",
    minimumFractionDigits: dec, maximumFractionDigits: dec,
  }).format(n ?? 0);

export const pct = (n: number | null | undefined, dec = 1) =>
  new Intl.NumberFormat("es-ES", {
    style: "percent", minimumFractionDigits: dec, maximumFractionDigits: dec,
  }).format(n ?? 0);

export const MESES = [
  "", "Ene", "Feb", "Mar", "Abr", "May", "Jun",
  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic",
];

export const fechaLarga = (iso: string | null | undefined) => {
  if (!iso) return "—";
  try {
    return new Intl.DateTimeFormat("es-ES", {
      dateStyle: "medium", timeStyle: "short",
    }).format(new Date(iso));
  } catch {
    return "—";
  }
};
