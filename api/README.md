# Solidaridad API

REST API built with FastAPI.

## Requirements

- Python 3.12
- [`uv`](https://github.com/astral-sh/uv)
- Docker (Docker Compose) for local Postgres

## Local setup

Para levantar el backend local completo para mobile, usar `make dev` desde la
raíz del monorepo. El flujo manual de este componente es:

```bash
cp .env.example .env
make install
make db-up
make migrate
make db-seed
make run
```

Or, after `.env` + install + seed once:

```bash
make dev   # db-up + migrate + run
```

API: `http://127.0.0.1:8000`

Endpoints:

- `GET /ping` → `{"status": "ok"}`
- Auth: see [docs/auth-plan.md](docs/auth-plan.md)
- Payments: `POST /v1/transactions` — see [docs/payments-plan.md](docs/payments-plan.md)

### Demo seed users (`APP_ENV=local` only)

| Email | Password | Notes |
|-------|----------|--------|
| `demo@solidaridad.local` | `demo1234` | Usuario demo |
| `mustchange@solidaridad.local` | `changeme1` | `must_change_password=true` |

Instalación/terminal de ejemplo: `05000001`

### Configuración manual del comercio

Un administrador carga `merchants` y asigna
`users.merchant_id` al comercio correspondiente. `code` debe coincidir con el
código de comercio del procesador asociado a la terminal; se conserva como
texto, incluidos los ceros iniciales. La asociación es obligatoria. Durante la
transición, login y `GET /v1/me/merchant` responden 403 si aún falta. El endpoint
consulta el comercio de la cuenta autenticada en cada solicitud.

```sql
INSERT INTO merchants (code, name, address, city, tax_id)
VALUES ('CODIGO', 'NOMBRE', 'DOMICILIO', 'LOCALIDAD', 'CUIT');

UPDATE users SET merchant_id = (SELECT id FROM merchants WHERE code = 'CODIGO')
WHERE email = 'cuenta@ejemplo.com';
```

No existe un endpoint de registro público. El alta se realiza directamente en
la base y debe incluir `merchant_id` y un hash de contraseña compatible con la
API. Para generar el hash sin escribir la contraseña en el comando:

```bash
uv run python -c 'from getpass import getpass; from pwdlib import PasswordHash; print(PasswordHash.recommended().hash(getpass("Contraseña inicial: ")))'
```

Usar el hash obtenido en una conexión administrativa segura:

```sql
INSERT INTO users (merchant_id, name, email, password_hash, must_change_password)
SELECT id, 'NOMBRE', 'cuenta@ejemplo.com', 'HASH_GENERADO', true
FROM merchants WHERE code = 'CODIGO';
```

El seed local crea un comercio de demostración con datos ficticios y lo asigna
a las cuentas demo.

Para una base con cuentas existentes, aplicar primero
`uv run alembic upgrade 20261105_0014`, cargar y asociar comercios, y después
`make migrate`. La migración `20261105_0015` rechaza cuentas sin asociación;
no inventa un comercio para ellas. Una base nueva puede migrarse normalmente.

La API envía el código en DE42 mediante el gateway. Para anulaciones y reversos
consulta el comercio asociado a la cuenta que hizo la venta; se asume que esa
asociación y su código permanecen estables. Si falta un comercio válido, la
anulación se rechaza y el reverso pasa a revisión manual. La validación de la
relación cuenta-terminal dentro de la API sigue pendiente; el procesador
verifica terminal y comercio para Verifone.

Re-ejecutar seed es seguro (idempotente):

```bash
make db-seed
```

### Useful Make targets

| Target | Acción |
|--------|--------|
| `make install` | `uv sync` |
| `make db-up` | Levanta Postgres (espera healthcheck) |
| `make db-down` | Baja containers |
| `make db-reset` | Borra volume y recrea DB |
| `make migrate` | `alembic upgrade head` |
| `make migrate-new MSG="..."` | Nueva revisión autogenerada |
| `make db-seed` | Puebla datos demo (solo `local`) |
| `make run` | Uvicorn con reload |
| `make run HOST=0.0.0.0` | Uvicorn accesible desde emulador/LAN |
| `make dev` | `db-up` + `migrate` + `run` |
| `make lint` | Ruff check |
| `make lint-fix` | Ruff check --fix + format |
| `make typecheck` | mypy |
| `make test` | pytest |
| `make check` | lint + typecheck + test |
| `make integ-stub` | Gateway HTTP controlado para integración (`:8011`) |
| `make integ-test` | Suite HTTP contra `API_BASE_URL` |

### Environment variables

Copy `.env.example` → `.env` (`.env` is gitignored).

| Variable | Purpose | Local example |
|----------|---------|---------------|
| `APP_ENV` | Environment | `local` |
| `BUSINESS_TIMEZONE` | Zona IANA para numeración diaria de operaciones | `America/Argentina/Buenos_Aires` |
| `POSTGRES_USER` | Compose DB user | `solidaridad` |
| `POSTGRES_PASSWORD` | Compose DB password | `solidaridad` |
| `POSTGRES_DB` | Compose DB name | `solidaridad` |
| `POSTGRES_PORT` | Host port | `5434` (default local; change if free) |
| `DATABASE_URL` | SQLAlchemy URL | `postgresql+psycopg://solidaridad:solidaridad@localhost:5434/solidaridad` |
| `JWT_SECRET` | JWT signing secret | long local-only string |
| `JWT_ALGORITHM` | JWT algorithm | `HS256` |
| `JWT_EXPIRE_MINUTES` | Access token TTL | `1440` |

### Hitting the API from a device / emulator

- Host machine / iOS simulator: `http://127.0.0.1:8000/v1`
- Android emulator: `http://10.0.2.2:8000/v1`
- Physical device on same LAN: `http://<your-lan-ip>:8000/v1`

Para Android o un dispositivo físico, ejecutar `make run HOST=0.0.0.0`. El
comando raíz `make dev` ya aplica esta configuración.

Auth plan: [docs/auth-plan.md](docs/auth-plan.md).

Agent / contributor checklist: [AGENTS.md](AGENTS.md).

## Quality checks

```bash
make lint       # ruff
make typecheck  # mypy
make test       # pytest
make check      # lint + typecheck + test
```

Auto-fix lint/format:

```bash
make lint-fix
```

## HTTP integration tests

`make integ-test` is a separate black-box gate: it sends requests to an
already running API over HTTP. It does not use FastAPI `TestClient` or
dependency overrides. The API must use an isolated database migrated to `head`
and its `PAYMENT_GATEWAY_URL` must point to the controlled integration stub.

The gate does not create or wipe the database; it inserts test merchants and
operators directly. Set `INTEGRATION_DATABASE_URL` to the same dedicated,
disposable database used by the API, never to a production database. In separate terminals,
from `api/`:

```bash
# 1. Controlled HTTP downstream.
make integ-stub HOST=127.0.0.1

# 2. API configured with a dedicated, migrated DATABASE_URL, the stub and
#    recovery disabled for deterministic PENDING assertions.
DATABASE_URL=postgresql+psycopg://... PAYMENT_GATEWAY_URL=http://127.0.0.1:8011 \
  make run HOST=127.0.0.1

# 3. In a third terminal, execute the gate.
INTEGRATION_DATABASE_URL=postgresql+psycopg://... \
  make integ-test API_BASE_URL=http://127.0.0.1:8000 \
  INTEGRATION_GATEWAY_CONTROL_URL=http://127.0.0.1:8011
```

`API_BASE_URL` makes the same gate usable with a Compose stack or a remote
integration environment. `INTEGRATION_GATEWAY_CONTROL_URL` is intentionally
separate: it resets and scripts only the test gateway. Never expose that stub
or its `__test__` endpoints in an environment that handles real payment data.

### E2E contra el procesador local

El gate controlado anterior sigue siendo el que cubre timeouts, reintentos y
respuestas ambiguas. Para comprobar el recorrido real API → gateway TCP →
autorizador C de manera repetible, ejecutar desde la raíz del monorepo:

```bash
make e2e-test
```

El comando usa una PostgreSQL dedicada y descartable en el puerto `5435`; la
resetea, migra y carga antes de iniciar la API. También **borra el volumen
local de MySQL del procesador**, instala las tarjetas E2E con saldo, sin saldo,
sin producto y ausente, inicia el gateway con `ISO_TRANSPORT=tcp` y corre
únicamente `tests/integration/test_local_processor_http_integration.py`.
No usa el gateway stub ni comparte datos con la PostgreSQL de desarrollo.

`make integ-test-processor` se conserva para ejecutar sólo ese módulo contra
una API/gateway ya levantados; el invocador debe preparar la base de API.

## Architecture

```
api/
├── main.py              # App entry point
├── config/              # Settings / env
├── presentation/        # HTTP routing and dependencies
│   ├── router.py
│   ├── controllers/
│   └── dependencies.py
├── application/         # Use cases / services
├── domain/              # Business objects
├── persistence/         # Database / models / migrations / seed
│   ├── models/
│   ├── migrations/
│   ├── database.py
│   └── seed.py
├── docker-compose.yml   # Local Postgres
├── alembic.ini
├── .env.example
└── Makefile
```
