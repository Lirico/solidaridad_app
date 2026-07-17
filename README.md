# Solidaridad App

Monorepo del proyecto Solidaridad (GAS Terminal / POS Virtual).

## Levantar el backend local para mobile

### Requisitos

- [Docker](https://docs.docker.com/engine/install/) con el plugin Docker Compose
  v2 (debe soportar `docker compose up --wait`)
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/)
- [GNU Make](https://www.gnu.org/software/make/) y Bash

No hace falta instalar Python por separado. Los proyectos declaran Python 3.12
en sus archivos `.python-version` y `pyproject.toml`; `uv` descarga y administra
una versión compatible automáticamente cuando se ejecuta `uv sync`.

No hace falta instalar Postgres ni MySQL en el host: ambos se ejecutan en
contenedores. Antes de comenzar, verificar que Docker esté iniciado:

```bash
docker compose version
uv --version
make --version
```

### Windows (WSL2)

En Windows se recomienda ejecutar el proyecto dentro de
[WSL2](https://learn.microsoft.com/windows/wsl/install). El `Makefile` usa
funcionalidades de Bash que no son compatibles de forma confiable con
PowerShell o `cmd.exe`.

1. Abrir PowerShell como administrador e instalar WSL:

   ```powershell
   wsl --install
   ```

   Reiniciar Windows si el instalador lo solicita y completar la configuración
   inicial de Ubuntu.

2. Instalar [Docker Desktop para Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
   y habilitar la integración con la distribución WSL en **Settings → Resources
   → WSL Integration**.

3. Abrir la terminal de Ubuntu e instalar las herramientas necesarias:

   ```bash
   sudo apt update
   sudo apt install -y git make curl
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

   Cerrar y volver a abrir la terminal para que `uv` quede disponible.

4. Clonar el repositorio dentro del filesystem de WSL (por ejemplo, bajo
   `~/dev`) y no en `/mnt/c`, para evitar problemas de rendimiento y permisos:

   ```bash
   mkdir -p ~/dev
   cd ~/dev
   git clone <URL-DEL-REPOSITORIO>
   cd solidaridad_app
   ```

5. Comprobar los requisitos y levantar el backend:

   ```bash
   docker compose version
   uv --version
   make --version
   make dev
   ```

Todos estos comandos deben ejecutarse desde la terminal WSL. Docker Desktop
puede permanecer abierto en Windows; los comandos `docker` de WSL se conectan
automáticamente a su motor.

Desde la raíz del repositorio:

```bash
make dev
```

Ese único comando:

1. crea los `.env` locales a partir de los `.env.example` si no existen;
2. instala las dependencias de `api` y `payment-gateway`;
3. levanta MySQL 5.7 y espera al procesador `authkig`;
4. levanta Postgres, aplica todas las migraciones y ejecuta el seed idempotente;
5. inicia el gateway, espera que escuche en el puerto `8001`;
6. inicia la API, espera que escuche en el puerto `8000` y recién entonces
   informa que todo está listo.

El orden efectivo del flujo de pagos es procesador → gateway → API. Si una
dependencia no queda disponible en 90 segundos, `make dev` termina con un
mensaje de error en lugar de dejar un backend parcialmente iniciado.

Dejar esa terminal abierta mientras se prueba la app. `Ctrl-C` detiene la API y
el gateway; los contenedores se detienen por separado:

```bash
make down
```

En ejecuciones posteriores se usa el mismo `make dev`; no pisa ningún `.env`
existente ni borra datos locales. Las migraciones y el seed de la API pueden
ejecutarse varias veces. El esquema y seed de MySQL se cargan automáticamente
al crear su volumen por primera vez.

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
- Instalación/terminal: `05000001`

Health checks:

```bash
curl http://127.0.0.1:8000/ping
curl http://127.0.0.1:8001/ping
```

Ambos deben responder `{"status":"ok"}`.

### OpenAPI y documentación interactiva

FastAPI publica Swagger UI y el esquema OpenAPI de ambos servicios:

- API:
  - Swagger UI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
  - OpenAPI JSON: [http://127.0.0.1:8000/openapi.json](http://127.0.0.1:8000/openapi.json)
- Payment gateway:
  - Swagger UI: [http://127.0.0.1:8001/docs](http://127.0.0.1:8001/docs)
  - OpenAPI JSON: [http://127.0.0.1:8001/openapi.json](http://127.0.0.1:8001/openapi.json)

Desde Android Emulator, reemplazar `127.0.0.1` por `10.0.2.2`.

### Alcance actual del flujo local

- La API implementa autenticación bajo `/v1/auth`.
- La API implementa `POST /v1/transactions`, persiste la transacción y llama al
  gateway.
- El gateway implementa `POST /v1/authorize` y se comunica con `authkig`.
- El backend local soporta el flujo completo API → gateway → procesador.
- Mobile todavía consume el contrato anterior `/v1/sales/gas`; para probar una
  venta desde la app debe migrarse ese cliente a `/v1/transactions`.

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
