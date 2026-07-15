# Solidaridad App

Monorepo del proyecto Solidaridad (GAS Terminal / POS Virtual).

## Estructura

```
solidaridad_app/
├── mobile/   # App Flutter (Android, iOS, web, desktop)
└── api/      # Backend API (FastAPI)
```

## Desarrollo

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Detalle de arquitectura y features: [mobile/README.md](mobile/README.md).

### API

```bash
cd api
uv sync
make run
```

Endpoint de health: `GET /ping` → `{"status": "ok"}`.

Detalle: [api/README.md](api/README.md).
