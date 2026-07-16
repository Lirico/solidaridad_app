.PHONY: up down logs build reset seed-refresh help

COMPOSE := docker compose --env-file .env

help:
	@echo "Payment processor (legacy authkig + MySQL 5.7)"
	@echo "  make up             Build and start mysql + auth"
	@echo "  make down           Stop containers"
	@echo "  make logs           Follow auth + mysql logs"
	@echo "  make build          Rebuild auth image"
	@echo "  make reset          Wipe mysql volume and recreate"
	@echo "  make seed-refresh   Re-dump schema/seed from desa (needs VPN + .env DESA_*)"

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
