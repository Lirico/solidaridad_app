# Solidaridad API

REST API built with FastAPI.

## Requirements

- Python 3.12
- `uv`

## Local setup

```bash
uv sync
```

Or:

```bash
make install
```

## Run the service locally

```bash
uv run uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

Or:

```bash
make run
```

Endpoints:

- `GET /ping`

## Architecture

```
api/
├── main.py              # App entry point
├── presentation/        # HTTP routing and dependencies
│   ├── router.py        # Assembles controllers via include_router
│   ├── controllers/     # Route handlers (one module per resource)
│   └── dependencies.py
├── application/         # Use cases / services
├── domain/              # Business objects
└── persistence/         # Database / repositories
```
