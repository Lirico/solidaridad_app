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
make reset         # borrar volumen MySQL y volver a cargar schema+seed
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

Para regenerar desde desa (VPN + credenciales en `.env`):

```bash
make seed-refresh
```

`.env` con `DESA_MYSQL_*` no se commitea.

## Build

La imagen compila en `debian:bookworm` con `default-libmysqlclient-dev` y un include de compatibilidad ([`docker/stubs/legacy_compat.h`](docker/stubs/legacy_compat.h)) para headers que el código asumía vía `my_global.h` de MySQL 5.7. Fuentes en [`legacy/bin/`](legacy/bin/).

El **servidor** de datos local es MySQL **5.7** (`mysql:5.7`, `platform: linux/amd64` porque esa tag no publica arm64; en Apple Silicon corre con emulación).
