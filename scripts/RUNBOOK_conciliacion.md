# Conciliación a tres puntas — rutina mensual

**Objetivo:** confirmar cada mes que *Guesty = Airbnb = banco*. El panel vive en `/cuadre`
(sección "Conciliación bancaria"). Todo verde = la plata que Airbnb dice que pagó llegó al banco.

## Cómo funciona (las tres puntas)

1. **Guesty** → Postgres: **automático**. La Edge Function `guesty-sync` corre por cron cada 3 h
   (`supabase/cron_setup.sql`). Trae cada reserva con su `confirmation_code` (Airbnb HMxxxx).
2. **Airbnb (fiscal/pago)** y **banco (caja)** → tablas `airbnb_tx` y `bank_deposits`: **manual mensual**.
   Se cargan desde los archivos que Stag deja en Drive (ver abajo). Airbnb no tiene API abierta
   para bajar esto solo, así que el export queda del lado de Stag (ya es su ritual de cierre).
3. **El panel** (`v_cuadre_banco`, `v_conciliacion_airbnb`) se recalcula solo cuando hay datos nuevos.

## Ritual mensual (al cerrar el mes)

**Stag deja en Drive** (`Confisic → SAMAVI GLOBAL VISION SL → <año> → MM - Mes → BANCOS EXTRACTOS`):
- Extracto **Revolut** del mes (CSV `account-statement_...csv`).
- Extracto **BBVA** del mes (CSV `BBVA Extracto ...csv`).
- Reporte de **transacciones de Airbnb** (los dos: IBAN 7165 = Nica+Jaco, IBAN 8920 = Alex+Mare).

**Cargar** (yo, o quien corra el cierre):
```bash
# 1) bajar los CSV del mes a una carpeta local (base64 -D si vienen en base64)
# 2) generar el SQL con el lector
python3 scripts/parse_extractos.py rev-<mes>.csv bbva-<mes>.csv airbnb-7165-<mes>.csv airbnb-8920-<mes>.csv > carga.sql
# 3) aplicar carga.sql en Supabase (MCP apply o SQL Editor). Es idempotente: borra por 'archivo'.
```

**Verificar**: abrir `/cuadre`. La sección bancaria debe quedar verde (en-tránsito chico) y el
chequeo "Conciliado contra bancos" debe avanzar al mes nuevo. Si una cuenta se pone en rojo,
el en-tránsito creció → hay un pago que no llegó: cruzar `airbnb_tx` (Payout) vs `bank_deposits`
por fecha de llegada + monto para encontrar cuál falta.

## Mapeo de cuentas (fijo)
- **IBAN 7165 = Revolut** → Nicasio + Jacobine.
- **IBAN 8920 = BBVA** → Alexander + Marechal.

## Siguiente nivel (opcional, futuro)
Automatizar del todo con un **agente programado** (cloud agent mensual) que lea los 3 archivos
de Drive, corra el lector y cargue — para que el panel se refresque sin intervención. Hoy el
paso de cargar es asistido; la parte de Guesty ya es 100 % automática.
