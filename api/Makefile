.PHONY: install run run-once run-recovery-worker integ-stub integ-test integ-test-processor recovery-concurrency-test recovery-concurrency-local db-up db-down db-logs db-reset e2e-db-up e2e-db-down e2e-db-reset migrate migrate-new db-seed \
	dev lint lint-fix typecheck test test-cov check

HOST ?= 0.0.0.0
API_BASE_URL ?= http://127.0.0.1:8000
INTEGRATION_GATEWAY_CONTROL_URL ?= http://127.0.0.1:8011
E2E_COMPOSE := docker compose --project-name solidaridad-e2e -f docker-compose.e2e.yml
E2E_DATABASE_URL := postgresql+psycopg://solidaridad_e2e:solidaridad_e2e@localhost:5435/solidaridad_e2e

install:
	uv sync

db-up:
	docker compose --env-file .env up -d --wait

db-down:
	docker compose --env-file .env down

db-logs:
	docker compose --env-file .env logs -f db

db-reset:
	docker compose --env-file .env down -v
	docker compose --env-file .env up -d --wait

# Dedicated, disposable PostgreSQL instance for the real local E2E gate.
# It never shares a container or volume with the normal development database.
e2e-db-up:
	$(E2E_COMPOSE) up -d --wait

e2e-db-down:
	$(E2E_COMPOSE) down

e2e-db-reset:
	$(E2E_COMPOSE) down -v
	$(E2E_COMPOSE) up -d --wait

migrate:
	uv run alembic upgrade head

migrate-new:
	uv run alembic revision --autogenerate -m "$(MSG)"

db-seed:
	uv run python -m persistence.seed

run:
	uv run uvicorn main:app --host $(HOST) --port 8000 --reload

run-once:
	uv run uvicorn main:app --host $(HOST) --port 8000

# Explicit single-process runner; the worker is already enabled by default.
run-recovery-worker:
	EMBEDDED_RECOVERY_WORKER_ENABLED=true uv run uvicorn main:app --host $(HOST) --port 8000

# The stub is intentionally a separate process: the API under test reaches it
# over HTTP just as it reaches the real payment gateway.
integ-stub:
	uv run uvicorn tests.integration.gateway_stub:app --host $(HOST) --port 8011

# API_BASE_URL makes this gate usable against a locally started API, a Compose
# stack, or a deployed integration environment. That API must have been
# configured with PAYMENT_GATEWAY_URL pointing at INTEGRATION_GATEWAY_CONTROL_URL.
integ-test:
	INTEGRATION_TESTS=1 API_BASE_URL="$(API_BASE_URL)" INTEGRATION_GATEWAY_CONTROL_URL="$(INTEGRATION_GATEWAY_CONTROL_URL)" uv run pytest tests/integration

# This target assumes the API is already pointing at payment-gateway with
# ISO_TRANSPORT=tcp and the local processor fixtures have been installed.
integ-test-processor:
	INTEGRATION_TESTS=1 INTEGRATION_PROCESSOR_TESTS=1 API_BASE_URL="$(API_BASE_URL)" uv run pytest tests/integration/test_local_processor_http_integration.py

# Real PostgreSQL lock/commit races for authorization recovery.
recovery-concurrency-test:
	RECOVERY_CONCURRENCY_DATABASE_URL="$(E2E_DATABASE_URL)" uv run pytest tests/postgresql/test_recovery_concurrency.py

# Reset the dedicated disposable DB, migrate it and run the race matrix.
recovery-concurrency-local: e2e-db-reset
	APP_ENV=local DATABASE_URL="$(E2E_DATABASE_URL)" uv run alembic upgrade head
	$(MAKE) recovery-concurrency-test

dev: db-up migrate run

lint:
	uv run ruff check .

lint-fix:
	uv run ruff check --fix .
	uv run ruff format .

typecheck:
	uv run mypy

test:
	uv run pytest

test-cov:
	uv run pytest --cov --cov-report=term-missing --cov-fail-under=90

check: lint typecheck test-cov
