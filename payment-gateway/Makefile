.PHONY: install run dev lint lint-fix typecheck test test-cov check

HOST ?= 127.0.0.1

install:
	uv sync

run:
	uv run uvicorn main:app --host $(HOST) --port 8001 --reload

dev: run

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
