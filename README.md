# Solidaridad App

Monorepo del proyecto Solidaridad (GAS Terminal / POS Virtual).

## Estructura

```
solidaridad_app/
├── mobile/              # App Flutter (Android, iOS, web, desktop)
├── api/                 # Backend API (FastAPI + Postgres)
└── payment_processor/   # Autorizador legacy (C + MySQL 5.7)
```

## Desarrollo (Makefile raíz)

```bash
make help
make up                 # Postgres (API) + MySQL/auth (procesador)
make down

make api-dev            # db + migrate + uvicorn :8000
make processor-up       # MySQL :3307 + authkig :4452
make processor-logs
```

El gateway ISO aún no está en el monorepo.

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

### Payment processor

```bash
cd payment_processor
cp .env.example .env
make up
```

Detalle: [payment_processor/README.md](payment_processor/README.md).
