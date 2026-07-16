# Solidaridad Payment Gateway

Adaptador HTTP → ISO8583 hacia el autorizador (`authkig`). Sin contexto de clientes ni persistencia propia.

## Requirements

- Python 3.12
- [`uv`](https://github.com/astral-sh/uv)
- Opcional: `payment_processor` levantado si `ISO_TRANSPORT=tcp`

## Local setup

Para levantar el backend local completo, incluido `authkig`, usar `make dev`
desde la raíz del monorepo. El flujo manual del gateway es:

```bash
cp .env.example .env
make install
make run
```

Gateway: `http://127.0.0.1:8001`

Por defecto `ISO_TRANSPORT=mock` (no necesita el procesador).

### Contra el procesador real (local)

```bash
# desde la raíz del monorepo
make processor-up

# en payment-gateway/.env
ISO_TRANSPORT=tcp
ISO_HOST=127.0.0.1
ISO_PORT=4452
```

### Endpoints

- `GET /ping` → `{"status": "ok"}`
- `POST /v1/authorize` → autorización compra (ver [docs/gateway-plan.md](docs/gateway-plan.md))

### Useful Make targets

| Target | Acción |
|--------|--------|
| `make install` | `uv sync` |
| `make run` | Uvicorn `:8001` con reload |
| `make run HOST=0.0.0.0` | Uvicorn accesible desde emulador/LAN |
| `make lint` | Ruff check |
| `make lint-fix` | Ruff fix + format |
| `make typecheck` | mypy |
| `make test` | pytest |
| `make check` | lint + typecheck + coverage |

### Environment variables

| Variable | Purpose | Local example |
|----------|---------|---------------|
| `APP_ENV` | Environment | `local` |
| `ISO_TRANSPORT` | `mock` or `tcp` | `mock` |
| `ISO_HOST` | authkig host | `127.0.0.1` |
| `ISO_PORT` | authkig port | `4452` |
| `ISO_CONNECT_TIMEOUT_SECONDS` | TCP connect timeout | `5` |
| `ISO_READ_TIMEOUT_SECONDS` | TCP read timeout | `30` |
| `ISO_TPDU` | TPDU (10 hex digits) | `6000030000` |
| `ISO_NII` | NII | `003` |
| `ISO_PROCESSING_CODE` | DE3 | `000000` |
| `ISO_POS_ENTRY_MODE` | DE22 | `012` |
| `ISO_POS_CONDITION_CODE` | DE25 | `00` |

Agent checklist: [AGENTS.md](AGENTS.md).

## Architecture

```
payment-gateway/
├── main.py
├── config/                 # Settings / env
├── presentation/           # HTTP
│   ├── router.py
│   ├── controllers/
│   ├── schemas/
│   └── dependencies.py
├── application/            # Use cases + ports
│   └── payments/
├── domain/                 # Entities / exceptions
├── infrastructure/         # ISO packer, mock, TCP
│   └── iso/
├── docs/
├── .env.example
└── Makefile
```
