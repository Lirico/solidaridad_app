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

Installation de ejemplo: `local-dev-installation`

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

### Environment variables

Copy `.env.example` → `.env` (`.env` is gitignored).

| Variable | Purpose | Local example |
|----------|---------|---------------|
| `APP_ENV` | Environment | `local` |
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
