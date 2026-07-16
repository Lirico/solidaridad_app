.PHONY: help up down \
	api-up api-down api-run api-dev api-install api-check \
	processor-up processor-down processor-logs processor-reset processor-seed-refresh

help:
	@echo "Solidaridad monorepo"
	@echo ""
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
	@echo "  make processor-up       Build/start MySQL 5.7 + authkig :4452"
	@echo "  make processor-down     Stop processor stack"
	@echo "  make processor-logs     Follow processor logs"
	@echo "  make processor-reset    Wipe processor DB volume and recreate"
	@echo "  make processor-seed-refresh  Re-dump seed from desa"
	@echo ""
	@echo "Gateway: not available yet."

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

api-check:
	$(MAKE) -C api check

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
