SHELL := /bin/bash

DEV_STARTUP_TIMEOUT ?= 90

.PHONY: help env setup dev up down \
	api-up api-down api-run api-dev api-install api-migrate api-seed api-check \
	gateway-install gateway-run gateway-check \
	processor-up processor-down processor-logs processor-reset processor-seed-refresh

help:
	@echo "Solidaridad monorepo"
	@echo ""
	@echo "  make dev                Prepare and run the complete local backend"
	@echo "                          (API :8000 + gateway :8001 + Postgres + MySQL/auth)"
	@echo "  make setup              Create local env files and install Python dependencies"
	@echo "  make up                 Start API Postgres + payment processor (MySQL + auth)"
	@echo "  make down               Stop both stacks"
	@echo ""
	@echo "  make api-up             Start API Postgres"
	@echo "  make api-down           Stop API Postgres"
	@echo "  make api-run            Run API (uvicorn :8000)"
	@echo "  make api-dev            db-up + migrate + run"
	@echo "  make api-install        uv sync"
	@echo "  make api-check          lint + typecheck + tests"
	@echo ""
	@echo "  make gateway-install    uv sync (payment-gateway)"
	@echo "  make gateway-run        Run gateway (uvicorn :8001)"
	@echo "  make gateway-check      lint + typecheck + tests"
	@echo ""
	@echo "  make processor-up       Build/start MySQL 5.7 + authkig :4452"
	@echo "  make processor-down     Stop processor stack"
	@echo "  make processor-logs     Follow processor logs"
	@echo "  make processor-reset    Wipe processor DB volume and recreate"
	@echo "  make processor-seed-refresh  Re-dump seed from desa"

env:
	@test -f api/.env || cp api/.env.example api/.env
	@test -f payment-gateway/.env || cp payment-gateway/.env.example payment-gateway/.env
	@test -f payment_processor/.env || cp payment_processor/.env.example payment_processor/.env

setup: env api-install gateway-install

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

processor-seed-refresh:
	$(MAKE) -C payment_processor seed-refresh
