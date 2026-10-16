.PHONY: up down logs build reset seed-refresh recarga integration-fixtures integration-reset help

COMPOSE := docker compose --env-file .env

help:
	@echo "Payment processor (legacy authkig + MySQL 5.7)"
	@echo "  make up             Build and start mysql + auth"
	@echo "  make down           Stop containers"
	@echo "  make logs           Follow auth + mysql logs"
	@echo "  make build          Rebuild auth image"
	@echo "  make reset          Wipe mysql volume and recreate (schema+seed+demo)"
	@echo "  make seed-refresh   Re-dump schema/seed from desa (needs VPN + .env DESA_*)"
	@echo "  make recarga        Recargar saldo alto en tarjetas de demo (DB ya levantada)"
	@echo "  make integration-reset  Recreate local DB and load known E2E card fixtures"

up:
	$(COMPOSE) up -d --build --wait

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f auth mysql

build:
	$(COMPOSE) build auth

reset:
	$(COMPOSE) down -v
	$(COMPOSE) up -d --build --wait

seed-refresh:
	./docker/mysql/dump_seed_from_desa.sh

recarga:
	docker exec -i solidaridad-processor-mysql sh -c "MYSQL_PWD=localdev mysql -ukigadmin2 kigsolidario2" < utils/demo/recarga.sql

integration-fixtures:
	docker exec -i solidaridad-processor-mysql sh -c "MYSQL_PWD=localdev mysql -ukigadmin2 kigsolidario2" < utils/demo/integration_fixtures.sql

# Destructive only for the processor's local Docker volume. Never use it with
# a shared or production database. The C service has a legacy 23:00 hour path
# that does not process normal sales, so select a zone outside that hour before
# starting its container.
integration-reset:
	@set -eu; \
	processor_tz="Etc/UTC"; \
	if [ "$$(date -u +%H)" = "23" ]; then processor_tz="Etc/GMT+12"; fi; \
	echo "Starting processor integration fixtures with AUTH_TIMEZONE=$$processor_tz"; \
	AUTH_TIMEZONE="$$processor_tz" $(COMPOSE) down -v; \
	AUTH_TIMEZONE="$$processor_tz" $(COMPOSE) up -d --build --wait
	$(MAKE) integration-fixtures
