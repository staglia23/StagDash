// Color de identidad por propiedad (orden fijo, nunca cíclico)
export const PROP_COLOR: Record<string, string> = {
  "1A_NICA": "#2a78d6", // azul
  "4B_ALEX": "#eb6834", // naranja
  "3G_MARE": "#1baf7a", // aqua
  "1A_JACO": "#4a3aa7", // violeta
};

export const propColor = (codigo: string) => PROP_COLOR[codigo] ?? "#898781";
