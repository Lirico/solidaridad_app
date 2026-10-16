# Payment processor (legacy)

Autorizador ISO8583 en C (`authkig-bin3`) + MySQL **5.7**, para pruebas locales.

## Quick start

```bash
cp .env.example .env   # ajustar solo si hace falta
make up
```

| Servicio | Puerto host | Notas |
|----------|-------------|--------|
| MySQL 5.7 | `3307` | DB `kigsolidario2`, user `kigadmin2` / pass `localdev` |
| authkig | `4452` | TCP ISO; log: `Aguardando conexiones en el puerto 4452` |

```bash
make logs          # seguir logs
make down          # parar
make reset         # borrar volumen MySQL y volver a cargar schema+seed+demo
make recarga       # recargar saldo de tarjetas de demo (sin resetear la DB)
make integration-reset  # borrar volumen y cargar tarjetas E2E conocidas
```

Desde la raíz del monorepo: `make processor-up` / `make up`.

## Terminales (DE41)

Si la terminal está vigente (`situacion = 'V'`) y tiene `cod_comercio` no vacío:

- **Comercio** (`merchid_42`): siempre se completa desde `terminales` vía DE41. No exige que DE42 del mensaje coincida con la DB. Sin `cod_comercio` → terminal desconocida / mal configurada.
- **Producto** (`currcode_49` / DE49): no es moneda ISO; es el código de producto (`sgas_productos.cod_moneda`, p.ej. `993`–`997`).
  - **Ingenico**: sobrescribe DE49 con `terminales.cod_moneda`.
  - **VeriFone / IVR**: conserva el DE49 enviado en el mensaje (producto elegido en la terminal).

## Schema y seed

Solo las **15 tablas** que usa el código C (no el resto de desa).

- [`docker/mysql/01_schema.sql`](docker/mysql/01_schema.sql) — DDL
- [`docker/mysql/02_seed.sql.gz`](docker/mysql/02_seed.sql.gz) — data: catálogos/usuarios completos; movimientos = últimos **2 meses de actividad por tabla** (relativo a `MAX(ts)` de cada una, porque desa puede estar quieta vs la fecha de hoy). En ctas se conserva además el último saldo por cuenta.
- [`utils/demo/03_fix_demo.sql`](utils/demo/03_fix_demo.sql) — ajustes de demo (terminal `05000001` → comercio GOBIERNO, saldo en tarjetas de prueba, ventas seguidas). Compose lo monta como el paso `03` del init y corre solo con un volumen limpio (`make reset` / primer `make up`).

Para recargar saldo **sin** borrar la DB (después de muchas ventas de prueba):

```bash
make recarga
```

Eso aplica [`utils/demo/recarga.sql`](utils/demo/recarga.sql). Ambos auxiliares de demo viven en `utils/demo`; únicamente schema y seed propios de la imagen quedan en `docker/mysql`. Guía end-to-end: [`docs/demo-transaccion-aprobada.md`](../docs/demo-transaccion-aprobada.md).

## Fixtures E2E locales

`make integration-reset` es un reset destructivo del **volumen Docker local**
del procesador. Luego de recrear schema, seed y demo, aplica
[`utils/demo/integration_fixtures.sql`](utils/demo/integration_fixtures.sql).
No se monta durante un `make up` habitual ni debe ejecutarse contra una base
compartida.

| Tarjeta | Resultado esperado para producto `993` |
|---|---|
| `6063007014990001` | Aprobada; saldo inicial `1000.00` |
| `6063007014990002` | Rechazada; cuenta existente sin saldo |
| `6063007014990003` | Rechazada; producto sin cuenta asignada |
| `6063007014990099` | Rechazada; tarjeta inexistente |
| `6063007014990004` | Consulta de saldo; `100` unidades disponibles para `993` |

Para regenerar desde desa (VPN + credenciales en `.env`):

```bash
make seed-refresh
```

`.env` con `DESA_MYSQL_*` no se commitea.

## Build

La imagen compila en `debian:bookworm` con `default-libmysqlclient-dev` y un include de compatibilidad ([`docker/stubs/legacy_compat.h`](docker/stubs/legacy_compat.h)) para headers que el código asumía vía `my_global.h` de MySQL 5.7. Fuentes en [`legacy/bin/`](legacy/bin/).

El **servidor** de datos local es MySQL **5.7** (`mysql:5.7`, `platform: linux/amd64` porque esa tag no publica arm64; en Apple Silicon corre con emulación).

El autorizador local usa UTC por defecto (`AUTH_TIMEZONE=Etc/UTC`). Para el
gate E2E, `make integration-reset` elige automáticamente una zona horaria
fuera de la hora 23 del autorizador, cuyo comportamiento heredado no procesa
ventas normales. Puede cambiarse en `.env` si se necesita reproducir el
comportamiento horario original.
