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
	@$(MAKE) up
	@$(MAKE) api-migrate
	@$(MAKE) api-seed
	@echo ""
	@echo "Local backend ready:"
	@echo "  API:     http://0.0.0.0:8000 (Android: http://10.0.2.2:8000/v1)"
	@echo "  Gateway: http://0.0.0.0:8001 (Android: http://10.0.2.2:8001)"
	@echo "Press Ctrl-C to stop API and gateway; run 'make down' to stop containers."
	@set -e; \
	$(MAKE) api-run HOST=0.0.0.0 & api_pid=$$!; \
	ISO_TRANSPORT=tcp $(MAKE) gateway-run HOST=0.0.0.0 & gateway_pid=$$!; \
	trap 'kill "$$api_pid" "$$gateway_pid" 2>/dev/null || true; wait "$$api_pid" "$$gateway_pid" 2>/dev/null || true' EXIT INT TERM; \
	wait -n "$$api_pid" "$$gateway_pid"

up: api-up processor-up

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
