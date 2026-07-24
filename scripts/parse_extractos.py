#!/usr/bin/env python3
"""Lector de los 3 formatos de la conciliación → INSERTs SQL (Fase 2/4).

  · Revolut (CSV):  depósitos Airbnb = TOPUP cuya Description contiene AIRBNB → bank_deposits (IBAN 7165).
  · BBVA (CSV):     entradas "ABONO POR TRANSFERENCIA A SU FAVOR RECIBIDA EN EUROS" → bank_deposits (IBAN 8920).
                    (BBVA no nombra al pagador; proxy por transferencias entrantes. Excluye préstamos/cashback.)
  · Airbnb transacciones (CSV): filas Payout (IBAN destino + fecha de llegada + cobrado) y Reserva
                    (código de confirmación + bruto/limpieza/comisión) → airbnb_tx.

Detecta el formato por la cabecera. Idempotente: borra por 'archivo' antes de insertar.
Uso:  python3 scripts/parse_extractos.py <archivos...> > carga.sql
"""
import csv, sys, os, re

def s(v):  return "null" if v in (None, "") else "'" + str(v).replace("'", "''") + "'"
def num(v):
    if v in (None, ""): return "null"
    v = str(v)
    v = v.replace(".", "").replace(",", ".") if ("," in v and "." in v) else v.replace(",", ".")
    return str(round(float(v), 2))

def revolut(path, arch):
    out = []
    for r in csv.reader(open(path, encoding="utf-8")):
        if len(r) < 15 or r[3] != "TOPUP" or "AIRBNB" not in r[5].upper(): continue
        out.append(("revolut", "7165", r[1], r[14], "AIRBNB PAYMENTS", "true", arch))
    return out

def bbva(path, arch):
    out = []
    for r in csv.reader(open(path, encoding="utf-8")):
        if len(r) < 7 or r[3].strip() != "ABONO POR TRANSFERENCIA A SU FAVOR RECIBIDA EN EUROS": continue
        if float(r[6]) <= 0: continue
        m = re.match(r"(\d{2})/(\d{2})/(\d{4})", r[0].strip())
        f = f"{m.group(3)}-{m.group(2)}-{m.group(1)}" if m else r[0]
        out.append(("bbva", "8920", f, r[6], "ABONO TRANSFERENCIA", "true", arch))
    return out

def mmddyyyy(d):
    m = re.match(r"(\d{2})/(\d{2})/(\d{4})", d or "")
    return f"{m.group(3)}-{m.group(1)}-{m.group(2)}" if m else None

def airbnb(path, arch):
    out = []
    for row in csv.DictReader(open(path, encoding="utf-8-sig")):
        tipo = (row.get("Tipo") or "").strip()
        iban = None
        det = row.get("Detalles") or row.get("Detalles ") or ""
        mi = re.search(r"IBAN (\d+)", det)
        if mi: iban = mi.group(1)
        if tipo == "Payout":
            out.append(("Payout", mmddyyyy(row["Fecha"]), mmddyyyy(row.get("Fecha de llegada estimada","")),
                        None, iban, None, None, None, None, row.get("Cobrado"), None, None, None, None,
                        row.get("Año fiscal"), arch))
        elif tipo in ("Reserva",) or "resoluci" in tipo.lower():
            out.append(("Reserva" if tipo == "Reserva" else "Resolucion",
                        mmddyyyy(row["Fecha"]), None, (row.get("Código de confirmación") or None), None,
                        (row.get("Alojamiento") or None), mmddyyyy(row.get("Fecha de inicio","")),
                        mmddyyyy(row.get("Fecha de finalización","")), (row.get("Noches") or None),
                        None, row.get("Importe"), row.get("Comisión de servicio"),
                        row.get("Gastos de limpieza"), row.get("Ingresos brutos"),
                        row.get("Año fiscal"), arch))
    return out

def main(paths):
    banks, txs, archivos = [], [], set()
    for p in paths:
        a = os.path.basename(p); archivos.add(a)
        head = open(p, encoding="utf-8-sig").readline()
        if a.startswith("rev"):      banks += revolut(p, a)
        elif a.startswith("bbva"):   banks += bbva(p, a)
        elif "confirmaci" in head:   txs += airbnb(p, a)
    print("begin;")
    for a in sorted(archivos):
        print(f"delete from bank_deposits where archivo={s(a)};")
        print(f"delete from airbnb_tx where archivo={s(a)};")
    if banks:
        print("insert into bank_deposits (banco,iban,fecha,importe,concepto,es_airbnb,archivo) values")
        print(",\n".join(f"  ({s(b)},{s(i)},{s(f)},{num(imp)},{s(c)},{ab},{s(ar)})" for b,i,f,imp,c,ab,ar in banks) + ";")
    if txs:
        cols = "tipo,fecha,fecha_llegada,confirmation_code,iban,alojamiento,inicio,fin,noches,cobrado,importe,comision_servicio,limpieza,bruto,anio_fiscal,archivo"
        print(f"insert into airbnb_tx ({cols}) values")
        def row(t):
            tp,fe,fl,cc,ib,al,ini,fin,no,co,im,cs,li,br,af,ar = t
            return (f"  ({s(tp)},{s(fe)},{s(fl)},{s(cc)},{s(ib)},{s(al)},{s(ini)},{s(fin)},"
                    f"{no or 'null'},{num(co)},{num(im)},{num(cs)},{num(li)},{num(br)},{af or 'null'},{s(ar)})")
        print(",\n".join(row(t) for t in txs) + ";")
    print("commit;")
    print(f"-- {len(banks)} depósitos + {len(txs)} filas Airbnb ({len(archivos)} archivos)", file=sys.stderr)

if __name__ == "__main__":
    main(sys.argv[1:])
