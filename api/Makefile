.PHONY: install run db-up db-down db-logs db-reset migrate migrate-new db-seed \
	dev lint lint-fix typecheck test test-cov check

HOST ?= 0.0.0.0

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

migrate:
	uv run alembic upgrade head

migrate-new:
	uv run alembic revision --autogenerate -m "$(MSG)"

db-seed:
	uv run python -m persistence.seed

run:
	uv run uvicorn main:app --host $(HOST) --port 8000 --reload

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
