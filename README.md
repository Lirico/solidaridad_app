# Solidaridad App

Monorepo del proyecto Solidaridad (GAS Terminal / POS Virtual).

## Estructura

```
solidaridad_app/
├── mobile/              # App Flutter (Android, iOS, web, desktop)
├── api/                 # Backend API (FastAPI + Postgres)
├── payment-gateway/     # Adaptador HTTP → ISO8583
└── payment_processor/   # Autorizador legacy (C + MySQL 5.7)
```

## Desarrollo (Makefile raíz)

```bash
make help
make up                 # Postgres (API) + MySQL/auth (procesador)
make down

make api-dev            # db + migrate + uvicorn :8000
make gateway-run        # uvicorn :8001 (mock ISO by default)
make processor-up       # MySQL :3307 + authkig :4452
make processor-logs
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Detalle: [mobile/README.md](mobile/README.md).

### API

```bash
cd api
cp .env.example .env
make install && make db-up && make migrate && make run
```

Health: `GET /ping` → `{"status": "ok"}`. Detalle: [api/README.md](api/README.md).

### Payment gateway

```bash
cd payment-gateway
cp .env.example .env
make install
make run
```

HTTP: `http://127.0.0.1:8001` — por defecto `ISO_TRANSPORT=mock`. Detalle: [payment-gateway/README.md](payment-gateway/README.md).

### Payment processor

```bash
cd payment_processor
cp .env.example .env
make up
```

Detalle: [payment_processor/README.md](payment_processor/README.md).
