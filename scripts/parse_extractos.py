#!/usr/bin/env python3
"""Lector de extractos bancarios → filas para bank_deposits (Fase 2 de la conciliación).

Parsea los dos formatos que usamos y emite INSERTs SQL para la tabla bank_deposits.
  · Revolut (CSV, coma):  depósitos de Airbnb = TOPUP cuya Description contiene AIRBNB.
                          IBAN 7165 (Nicasio + Jacobine).
  · BBVA (CSV, coma):     BBVA no nombra al pagador → proxy = "ABONO POR TRANSFERENCIA
                          A SU FAVOR RECIBIDA EN EUROS" (entradas). IBAN 8920 (Alexander + Marechal).
                          Excluye disposiciones de préstamo y cashbacks por el filtro de concepto.

Uso:  python3 scripts/parse_extractos.py rev-*.csv bbva-*.csv > deposits.sql
Idempotente al cargar: el SQL borra por 'archivo' antes de insertar (recargar no duplica).
"""
import csv, sys, os, re

def sql_str(v):
    return "null" if v is None else "'" + str(v).replace("'", "''") + "'"

def num(v):
    return "null" if v in (None, "") else str(round(float(v), 2))

def parse_revolut(path, archivo):
    rows = []
    with open(path, encoding="utf-8") as f:
        for r in csv.reader(f):
            if len(r) < 15 or r[3] != "TOPUP":
                continue
            desc = r[5]
            if "AIRBNB" not in desc.upper():
                continue
            fecha = r[1]  # Date completed (UTC), YYYY-MM-DD
            importe = r[14]  # Amount (columna 15)
            rows.append(("revolut", "7165", fecha, importe, desc, True, archivo))
    return rows

def parse_bbva(path, archivo):
    rows = []
    with open(path, encoding="utf-8") as f:
        for r in csv.reader(f):
            if len(r) < 7:
                continue
            concepto = r[3].strip()
            if concepto != "ABONO POR TRANSFERENCIA A SU FAVOR RECIBIDA EN EUROS":
                continue
            d = r[0].strip()  # Fecha Proceso, DD/MM/YYYY
            m = re.match(r"(\d{2})/(\d{2})/(\d{4})", d)
            fecha = f"{m.group(3)}-{m.group(2)}-{m.group(1)}" if m else d
            importe = r[6]
            if float(importe) <= 0:
                continue
            rows.append(("bbva", "8920", fecha, importe, concepto, True, archivo))
    return rows

def main(paths):
    all_rows, archivos = [], set()
    for p in paths:
        archivo = os.path.basename(p)
        archivos.add(archivo)
        if archivo.startswith("rev"):
            all_rows += parse_revolut(p, archivo)
        elif archivo.startswith("bbva"):
            all_rows += parse_bbva(p, archivo)
    # Idempotente: reemplaza por archivo
    print("begin;")
    for a in sorted(archivos):
        print(f"delete from bank_deposits where archivo = {sql_str(a)};")
    print("insert into bank_deposits (banco, iban, fecha, importe, concepto, es_airbnb, archivo) values")
    vals = [
        f"  ({sql_str(b)}, {sql_str(i)}, {sql_str(f)}, {num(imp)}, {sql_str(c)}, {str(ab).lower()}, {sql_str(ar)})"
        for (b, i, f, imp, c, ab, ar) in all_rows
    ]
    print(",\n".join(vals) + ";")
    print("commit;")
    print(f"-- {len(all_rows)} depósitos de Airbnb ({len(archivos)} archivos)", file=sys.stderr)

if __name__ == "__main__":
    main(sys.argv[1:])
