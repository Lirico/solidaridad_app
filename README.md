# Solidaridad App

Monorepo del proyecto Solidaridad (GAS Terminal / POS Virtual).

## Levantar el backend local para mobile

### Requisitos

- Docker con Docker Compose
- Python 3.12
- [`uv`](https://docs.astral.sh/uv/)
- GNU Make

Desde la raíz del repositorio:

```bash
make dev
```

Ese único comando:

1. crea los `.env` locales a partir de los `.env.example` si no existen;
2. instala las dependencias de `api` y `payment-gateway`;
3. levanta Postgres, MySQL 5.7 y el autorizador `authkig`;
4. ejecuta las migraciones y carga los usuarios demo de forma idempotente;
5. inicia la API en el puerto `8000` y el gateway en el `8001`;
6. conecta el gateway al autorizador local por TCP.

Dejar esa terminal abierta mientras se prueba la app. `Ctrl-C` detiene la API y
el gateway; los contenedores se detienen por separado:

```bash
make down
```

En ejecuciones posteriores se usa el mismo `make dev`; no pisa ningún `.env`
existente ni borra datos locales.

### URLs desde el emulador

| Cliente | API base URL | Gateway |
|---|---|---|
| Android Emulator | `http://10.0.2.2:8000/v1` | `http://10.0.2.2:8001` |
| iOS Simulator | `http://127.0.0.1:8000/v1` | `http://127.0.0.1:8001` |
| Equipo host | `http://127.0.0.1:8000/v1` | `http://127.0.0.1:8001` |
| Dispositivo físico en la misma red | `http://<IP-LAN-DEL-HOST>:8000/v1` | `http://<IP-LAN-DEL-HOST>:8001` |

La API y el gateway iniciados por `make dev` escuchan en `0.0.0.0`, por lo que
son accesibles desde emuladores y desde la red local. Para un dispositivo
físico puede ser necesario habilitar los puertos `8000` y `8001` en el firewall.

> **Configuración mobile actual:** la app tiene la URL de producción escrita
> directamente en `mobile/lib/features/auth/data/auth_repository.dart` y
> `mobile/lib/features/sales/data/sales_repository.dart`. Quien desarrolle
> mobile debe apuntar esos repositorios a la API base URL de la tabla anterior
> en su entorno local. Este setup no modifica código de `mobile/`.

### Datos para probar autenticación

- Usuario: `demo@solidaridad.local`
- Contraseña: `demo1234`
- Instalación: `local-dev-installation`

Health checks:

```bash
curl http://127.0.0.1:8000/ping
curl http://127.0.0.1:8001/ping
```

Ambos deben responder `{"status":"ok"}`.

### Alcance actual del flujo local

- La API implementa autenticación bajo `/v1/auth`.
- El gateway implementa `POST /v1/authorize` y se comunica con `authkig`.
- La API todavía no está conectada al gateway.
- El endpoint `/v1/sales/gas` que consume mobile todavía no existe en la API
  local; por lo tanto, hoy puede probarse autenticación local y el gateway por
  separado, pero no una venta completa desde la app.

## Estructura

```
solidaridad_app/
├── mobile/              # App Flutter (Android, iOS, web, desktop)
├── api/                 # Backend API (FastAPI + Postgres)
├── payment-gateway/     # Adaptador HTTP → ISO8583
└── payment_processor/   # Autorizador legacy (C + MySQL 5.7)
```

## Comandos útiles desde la raíz

```bash
make help               # lista completa de comandos
make setup              # crea .env e instala dependencias, sin iniciar servicios
make up                 # solo Postgres + MySQL/auth
make down               # detiene ambos stacks Docker
make api-dev            # Postgres + migraciones + API :8000
make gateway-run        # gateway :8001 (usa su configuración .env)
make processor-logs     # logs de MySQL/authkig
```

Documentación por componente:

- [Mobile](mobile/README.md)
- [API](api/README.md)
- [Payment gateway](payment-gateway/README.md)
- [Payment processor](payment_processor/README.md)
