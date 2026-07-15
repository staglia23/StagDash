// useGrouping: true → fuerza el punto de miles también en 4 cifras (es-ES no lo hace por defecto)
export const eur = (n: number | null | undefined, dec = 0) =>
  new Intl.NumberFormat("es-ES", {
    style: "currency", currency: "EUR", useGrouping: true,
    minimumFractionDigits: dec, maximumFractionDigits: dec,
  }).format(n ?? 0);

export const pct = (n: number | null | undefined, dec = 1) =>
  new Intl.NumberFormat("es-ES", {
    style: "percent", useGrouping: true,
    minimumFractionDigits: dec, maximumFractionDigits: dec,
  }).format(n ?? 0);

/** Puntos porcentuales (para el colchón del break-even): "+5,6 pp" */
export const pp = (n: number | null | undefined, dec = 1) =>
  (n == null ? "—" : `${n >= 0 ? "+" : ""}${(n * 100).toLocaleString("es-ES", {
    minimumFractionDigits: dec, maximumFractionDigits: dec,
  })} pp`);

/** Nombre legible de canal (Guesty: airbnb2, bookingCom, manual…) */
export const canalNombre = (s: string | null | undefined) => {
  const m: Record<string, string> = {
    airbnb2: "Airbnb", airbnb: "Airbnb", bookingCom: "Booking.com",
    manual: "Directo / Manual", vrbo: "Vrbo",
  };
  return m[s ?? ""] ?? (s || "Otro");
};

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
