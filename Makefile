SHELL := /bin/bash

DEV_STARTUP_TIMEOUT ?= 90
API_BASE_URL ?= http://127.0.0.1:8000
INTEGRATION_GATEWAY_CONTROL_URL ?= http://127.0.0.1:8011
E2E_API_BASE_URL ?= http://127.0.0.1:8000
E2E_DATABASE_URL ?= postgresql+psycopg://solidaridad_e2e:solidaridad_e2e@127.0.0.1:5435/solidaridad_e2e

.PHONY: help env setup dev up down e2e-db-up e2e-db-down e2e-db-reset e2e-test integ-test-controlled test-all \
	catalog-install catalog-check \
	api-up api-down api-run api-dev api-install api-migrate api-seed api-check api-integ-test api-integ-test-processor integ-test integ-test-processor \
	gateway-install gateway-run gateway-check \
	processor-up processor-down processor-logs processor-reset processor-seed-refresh processor-integration-reset

help:
	@echo "Solidaridad monorepo"
	@echo ""
	@echo "  make dev                Prepare and run the complete local backend"
	@echo "                          (API :8000 + gateway :8001 + Postgres + MySQL/auth)"
	@echo "  make setup              Create local env files and install Python dependencies"
	@echo "  make up                 Start API Postgres + payment processor (MySQL + auth)"
	@echo "  make down               Stop both stacks"
	@echo ""
	@echo "  make catalog-install    uv sync (packages/catalog)"
	@echo "  make catalog-check      lint + typecheck + tests (catalog)"
	@echo ""
	@echo "  make api-up             Start API Postgres"
	@echo "  make api-down           Stop API Postgres"
	@echo "  make api-run            Run API (uvicorn :8000)"
	@echo "  make api-dev            db-up + migrate + run"
	@echo "  make api-install        uv sync"
	@echo "  make api-check          lint + typecheck + tests"
	@echo "  make api-integ-test     Run black-box API integration tests"
	@echo "  make integ-test         Alias for api-integ-test"
	@echo "  make integ-test-processor  Reset local processor, load E2E cards and test API"
	@echo "  make e2e-test           Reset dedicated E2E databases and run API → gateway → processor"
	@echo "  make integ-test-controlled  Prepare local stub/API and run make integ-test"
	@echo "  make test-all           Run catalog, API, gateway, controlled integration and real E2E checks"
	@echo ""
	@echo "  make gateway-install    uv sync (payment-gateway)"
	@echo "  make gateway-run        Run gateway (uvicorn :8001)"
	@echo "  make gateway-check      lint + typecheck + tests"
	@echo ""
	@echo "  make processor-up       Build/start MySQL 5.7 + authkig :4452"
	@echo "  make processor-down     Stop processor stack"
	@echo "  make processor-logs     Follow processor logs"
	@echo "  make processor-reset    Wipe processor DB volume and recreate"
	@echo "  make processor-integration-reset  Wipe local DB and load known E2E cards"
	@echo "  make processor-seed-refresh  Re-dump seed from desa"

env:
	@test -f api/.env || cp api/.env.example api/.env
	@test -f payment-gateway/.env || cp payment-gateway/.env.example payment-gateway/.env
	@test -f payment_processor/.env || cp payment_processor/.env.example payment_processor/.env

setup: env catalog-install api-install gateway-install

dev: setup
	@$(MAKE) processor-up
	@$(MAKE) api-up
	@$(MAKE) api-migrate
	@$(MAKE) api-seed
	@set -Eeuo pipefail; \
	gateway_pid=""; \
	api_pid=""; \
	cleanup() { \
		for pid in "$$api_pid" "$$gateway_pid"; do \
			if [[ -n "$$pid" ]]; then kill "$$pid" 2>/dev/null || true; fi; \
		done; \
		for pid in "$$api_pid" "$$gateway_pid"; do \
			if [[ -n "$$pid" ]]; then wait "$$pid" 2>/dev/null || true; fi; \
		done; \
	}; \
	wait_for_port() { \
		local name="$$1" host="$$2" port="$$3" pid="$$4"; \
		for ((second = 1; second <= $(DEV_STARTUP_TIMEOUT); second++)); do \
			if [[ -n "$$pid" ]] && ! kill -0 "$$pid" 2>/dev/null; then \
				echo "Error: $$name terminó antes de quedar disponible." >&2; \
				return 1; \
			fi; \
			if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then return 0; fi; \
			sleep 1; \
		done; \
		echo "Error: $$name no respondió en $$host:$$port después de $(DEV_STARTUP_TIMEOUT)s." >&2; \
		return 1; \
	}; \
	ensure_port_free() { \
		local name="$$1" host="$$2" port="$$3"; \
		if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then \
			echo "Error: $$name no puede iniciar porque $$host:$$port ya está en uso." >&2; \
			return 1; \
		fi; \
	}; \
	trap cleanup EXIT; \
	trap 'exit 130' INT TERM; \
	echo "Esperando al payment processor..."; \
	wait_for_port "payment processor" 127.0.0.1 4452 ""; \
	ensure_port_free "payment gateway" 127.0.0.1 8001; \
	ensure_port_free "API" 127.0.0.1 8000; \
	echo "Iniciando payment gateway..."; \
	ISO_TRANSPORT=tcp $(MAKE) gateway-run HOST=0.0.0.0 & gateway_pid=$$!; \
	wait_for_port "payment gateway" 127.0.0.1 8001 "$$gateway_pid"; \
	echo "Iniciando API..."; \
	$(MAKE) api-run HOST=0.0.0.0 & api_pid=$$!; \
	wait_for_port "API" 127.0.0.1 8000 "$$api_pid"; \
	echo ""; \
	echo "Local backend ready:"; \
	echo "  API:     http://0.0.0.0:8000 (Android: http://10.0.2.2:8000/v1)"; \
	echo "  Gateway: http://0.0.0.0:8001 (Android: http://10.0.2.2:8001)"; \
	echo "Press Ctrl-C to stop API and gateway; run 'make down' to stop containers."; \
	while kill -0 "$$api_pid" 2>/dev/null && kill -0 "$$gateway_pid" 2>/dev/null; do sleep 1; done; \
	echo "Error: API o payment gateway se detuvo inesperadamente." >&2; \
	exit 1

up: processor-up api-up

down: processor-down api-down

catalog-install:
	cd packages/catalog && uv sync

catalog-check:
	cd packages/catalog && uv run ruff check . && uv run mypy src && uv run pytest

api-up:
	$(MAKE) -C api db-up

api-down:
	$(MAKE) -C api db-down

api-run:
	$(MAKE) -C api run

api-dev:
	$(MAKE) -C api dev

api-install:
	$(MAKE) -C api install

api-migrate:
	$(MAKE) -C api migrate

api-seed:
	$(MAKE) -C api db-seed

api-check:
	$(MAKE) -C api check

api-integ-test:
	$(MAKE) -C api integ-test API_BASE_URL="$(API_BASE_URL)" INTEGRATION_GATEWAY_CONTROL_URL="$(INTEGRATION_GATEWAY_CONTROL_URL)"

integ-test: api-integ-test

# Requires an API already configured with the local TCP payment gateway.
api-integ-test-processor: processor-integration-reset
	$(MAKE) -C api integ-test-processor API_BASE_URL="$(API_BASE_URL)"

integ-test-processor: api-integ-test-processor

# This gate intentionally exercises only the real local dependency chain:
# API -> HTTP payment gateway -> ISO8583 TCP -> authkig -> MySQL.
# It uses an isolated PostgreSQL container/volume and the processor's local
# Docker volume; both are recreated before every invocation.
e2e-db-up:
	$(MAKE) -C api e2e-db-up

e2e-db-down:
	$(MAKE) -C api e2e-db-down

e2e-db-reset:
	$(MAKE) -C api e2e-db-reset

e2e-test: setup processor-integration-reset
	$(MAKE) e2e-db-reset
	DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) -C api migrate
	DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) -C api db-seed
	@set -Eeuo pipefail; \
		gateway_pid=""; \
		api_pid=""; \
		cleanup() { \
			for pid in "$$api_pid" "$$gateway_pid"; do \
				if [[ -n "$$pid" ]]; then kill "$$pid" 2>/dev/null || true; fi; \
			done; \
			for pid in "$$api_pid" "$$gateway_pid"; do \
				if [[ -n "$$pid" ]]; then wait "$$pid" 2>/dev/null || true; fi; \
			done; \
		}; \
		wait_for_port() { \
			local name="$$1" host="$$2" port="$$3" pid="$$4"; \
			for ((second = 1; second <= $(DEV_STARTUP_TIMEOUT); second++)); do \
				if [[ -n "$$pid" ]] && ! kill -0 "$$pid" 2>/dev/null; then \
					echo "Error: $$name terminó antes de quedar disponible." >&2; return 1; \
				fi; \
				if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then return 0; fi; \
				sleep 1; \
			done; \
			echo "Error: $$name no respondió en $$host:$$port después de $(DEV_STARTUP_TIMEOUT)s." >&2; return 1; \
		}; \
		ensure_port_free() { \
			local name="$$1" host="$$2" port="$$3"; \
			if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then \
				echo "Error: $$name no puede iniciar porque $$host:$$port ya está en uso." >&2; return 1; \
			fi; \
		}; \
		trap cleanup EXIT; \
		trap 'exit 130' INT TERM; \
		wait_for_port "payment processor" 127.0.0.1 4452 ""; \
		ensure_port_free "payment gateway E2E" 127.0.0.1 8001; \
		ensure_port_free "API E2E" 127.0.0.1 8000; \
		echo "Iniciando payment gateway E2E contra el procesador local..."; \
		ISO_TRANSPORT=tcp $(MAKE) -C payment-gateway run-once HOST=127.0.0.1 & gateway_pid="$$!"; \
		wait_for_port "payment gateway E2E" 127.0.0.1 8001 "$$gateway_pid"; \
		echo "Iniciando API E2E con PostgreSQL dedicado..."; \
		DATABASE_URL="$(E2E_DATABASE_URL)" PAYMENT_GATEWAY_URL=http://127.0.0.1:8001 $(MAKE) -C api run-once HOST=127.0.0.1 & api_pid="$$!"; \
		wait_for_port "API E2E" 127.0.0.1 8000 "$$api_pid"; \
		INTEGRATION_DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) -C api integ-test-processor API_BASE_URL="$(E2E_API_BASE_URL)"

# Turnkey runner for the controlled HTTP integration suite. It deliberately
# calls the existing `make integ-test` target so its scenarios remain the
# single source of truth for timeout, retry and ambiguous-response coverage.
integ-test-controlled: setup
	$(MAKE) e2e-db-reset
	DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) -C api migrate
	DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) -C api db-seed
	@set -Eeuo pipefail; \
		stub_pid=""; \
		api_pid=""; \
		cleanup() { \
			for pid in "$$api_pid" "$$stub_pid"; do \
				if [[ -n "$$pid" ]]; then kill "$$pid" 2>/dev/null || true; fi; \
			done; \
			for pid in "$$api_pid" "$$stub_pid"; do \
				if [[ -n "$$pid" ]]; then wait "$$pid" 2>/dev/null || true; fi; \
			done; \
		}; \
		wait_for_port() { \
			local name="$$1" host="$$2" port="$$3" pid="$$4"; \
			for ((second = 1; second <= $(DEV_STARTUP_TIMEOUT); second++)); do \
				if [[ -n "$$pid" ]] && ! kill -0 "$$pid" 2>/dev/null; then \
					echo "Error: $$name terminó antes de quedar disponible." >&2; return 1; \
				fi; \
				if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then return 0; fi; \
				sleep 1; \
			done; \
			echo "Error: $$name no respondió en $$host:$$port después de $(DEV_STARTUP_TIMEOUT)s." >&2; return 1; \
		}; \
		ensure_port_free() { \
			local name="$$1" host="$$2" port="$$3"; \
			if (echo >"/dev/tcp/$$host/$$port") >/dev/null 2>&1; then \
				echo "Error: $$name no puede iniciar porque $$host:$$port ya está en uso." >&2; return 1; \
			fi; \
		}; \
		trap cleanup EXIT; \
		trap 'exit 130' INT TERM; \
		ensure_port_free "gateway stub" 127.0.0.1 8011; \
		ensure_port_free "API integration" 127.0.0.1 8000; \
		echo "Iniciando gateway stub de integración..."; \
		$(MAKE) -C api integ-stub HOST=127.0.0.1 & stub_pid="$$!"; \
		wait_for_port "gateway stub" 127.0.0.1 8011 "$$stub_pid"; \
		echo "Iniciando API para integración controlada..."; \
		DATABASE_URL="$(E2E_DATABASE_URL)" PAYMENT_GATEWAY_URL=http://127.0.0.1:8011 $(MAKE) -C api run-once HOST=127.0.0.1 & api_pid="$$!"; \
		wait_for_port "API integration" 127.0.0.1 8000 "$$api_pid"; \
		INTEGRATION_DATABASE_URL="$(E2E_DATABASE_URL)" $(MAKE) integ-test API_BASE_URL="$(E2E_API_BASE_URL)" INTEGRATION_GATEWAY_CONTROL_URL=http://127.0.0.1:8011

# Full local verification gate: package checks, controlled failure scenarios
# and the real processor path, all with a resettable local database.
test-all: catalog-check api-check gateway-check integ-test-controlled e2e-test

gateway-install:
	$(MAKE) -C payment-gateway install

gateway-run:
	$(MAKE) -C payment-gateway run

gateway-check:
	$(MAKE) -C payment-gateway check

processor-up:
	$(MAKE) -C payment_processor up

processor-down:
	$(MAKE) -C payment_processor down

processor-logs:
	$(MAKE) -C payment_processor logs

processor-reset:
	$(MAKE) -C payment_processor reset

processor-integration-reset:
	$(MAKE) -C payment_processor integration-reset

processor-seed-refresh:
	$(MAKE) -C payment_processor seed-refresh
