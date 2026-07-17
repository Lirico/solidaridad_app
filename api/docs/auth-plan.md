# Plan: autenticación (login, register, change-password)

Plan top-down para implementar auth en la API FastAPI, alineado al contrato que ya consume el client Flutter en `mobile/`.

## 1. Objetivo

Exponer autenticación por email/usuario + contraseña con token Bearer, de forma que:

- El mobile pueda dejar de depender de mocks (`mustChangePassword` en memoria).
- Las rutas protegidas (p. ej. `/v1/sales/gas`) validen `Authorization: Bearer <token>`.
- Cada sesión autenticada quede asociada al `installation_id` de 8 caracteres
  configurado en la terminal.
- La implementación respete las capas existentes: `presentation` → `application` → `domain` ← `persistence`.

## 2. Decisiones cerradas

| Tema | Decisión | Motivo |
|------|----------|--------|
| Modelo de sesión | JWT access token (Bearer) | El client ya espera `token` y lo envía como Bearer |
| Terminal de origen | `installation_id` | Identificador funcional de 8 caracteres configurado en la terminal |
| Identity provider | Auth propia (sin Cognito/Auth0) | Flujos simples; evita acoplamiento AWS en esta fase |
| Hash de contraseña | Argon2 | Estándar actual recomendado para passwords nuevos |
| Persistencia | PostgreSQL + SQLAlchemy 2 + Alembic | Encaja en `persistence/`; migraciones versionadas |
| Refresh tokens | Fuera de alcance (fase 1) | Simplifica; se puede agregar después |
| Reset por email | Fuera de alcance | Distinto de change-password autenticado |
| Roles / RBAC | Fuera de alcance | No requerido por el contrato actual |
| Validación de terminal | Procesador existente | El procesador confirma que la terminal esté dada de alta |

## 3. `installation_id` — por qué existe

Un usuario puede operar desde **más de un client** (p. ej. varias V660p, y a futuro también un teléfono). Hace falta distinguir **quién** autentica de **desde dónde** opera.

| Concepto | Pregunta que responde | Ejemplo |
|----------|----------------------|---------|
| `User` (`sub`) | ¿Quién es? | Cajero / operador |
| `installation_id` | ¿Desde qué instalación de la app? | Instancia en una V660p o en un mobile |
| Sesión JWT (`jti` / `exp`) | ¿Esta autenticación concreta sigue vigente? | Access token actual |

**Por qué no `terminal_id`:** el nombre ata el dominio a hardware POS. La app también puede vivir en mobile; el concepto real es “esta instalación del client”, no “esta terminal Verifone”.

**Por qué no confundirlo con sesión:** la sesión es efímera (el JWT). El `installation_id` es **estable** entre logins de la misma instalación: sirve para auditoría, atribución de ventas y, más adelante, autorizar qué instalaciones puede usar un usuario.

**Quién lo configura:** se provisiona en la terminal y el client lo envía a la
API. Es un identificador funcional estable de hasta 8 caracteres; el procesador
existente valida que corresponda a una terminal dada de alta.

**Fase 1:** el client lo envía en login/register; el API lo valida como requerido, lo registra/actualiza si hace falta, y lo mete en el JWT. **No** se exige aún que el usuario tenga esa instalación preautorizada.

## 4. Contrato HTTP (fuente de verdad: mobile)

Prefijo: `/v1`.

### 4.1 `POST /v1/auth/register`

**Request**

```json
{
  "name": "string",
  "email": "string",
  "password": "string",
  "installation_id": "string"
}
```

**Response `201`**

```json
{
  "name": "string",
  "email": "string",
  "token": "string",
  "must_change_password": false
}
```

**Errores**

| Status | Cuándo |
|--------|--------|
| `400` | Validación (email inválido, password débil, `installation_id` ausente/vacío, campos faltantes) |
| `409` | Email ya registrado |

### 4.2 `POST /v1/auth/login`

**Request** (el client envía `username`; puede ser email)

```json
{
  "username": "string",
  "password": "string",
  "installation_id": "string"
}
```

**Response `200`**

```json
{
  "name": "string",
  "email": "string",
  "token": "string",
  "must_change_password": true
}
```

**Errores**

| Status | Cuándo |
|--------|--------|
| `400` | `installation_id` ausente/vacío |
| `401` | Credenciales inválidas (mensaje genérico; no revelar si el usuario existe) |

### 4.3 `POST /v1/auth/change-password`

**Auth:** `Authorization: Bearer <token>` (requerido en API). El `installation_id` viaja en el JWT; no hace falta reenviarlo en el body.

> **Gap mobile:** hoy `AuthRepository.changePassword` no envía el Bearer. Hay que corregirlo en el client al integrar.

**Request**

```json
{
  "current_password": "string",
  "new_password": "string"
}
```

**Response `200`**

```json
{
  "message": "Contraseña actualizada correctamente"
}
```

**Errores**

| Status | Cuándo |
|--------|--------|
| `401` | Token ausente/inválido, o `current_password` incorrecta |
| `400` | `new_password` no cumple política / igual a la actual |

### 4.4 Dependency compartida

`get_current_user` (Bearer JWT) para cualquier ruta protegida posterior (`/v1/sales/...`, etc.). Expone al menos `user_id` e `installation_id` del token.

### 4.5 Forma de error

Respuestas de error con cuerpo legible por el client:

```json
{
  "message": "string"
}
```

(el mobile lee `data['message']`).

> **Nota de compatibilidad:** el client actual aún no envía `installation_id`. Fase 4 del plan alinea el mobile; hasta entonces, tests de API usan el campo nuevo explícitamente.

## 5. Modelo de dominio

### 5.1 Entidad `User`

| Campo | Tipo | Notas |
|-------|------|--------|
| `id` | int64 | PK autoincremental, sin significado de negocio |
| `name` | str | Display name |
| `email` | str | Único, normalizado a lowercase |
| `password_hash` | str | Argon2; nunca se expone |
| `must_change_password` | bool | Default `false` en register self-service |
| `created_at` | datetime | UTC |
| `updated_at` | datetime | UTC |

Reglas:

- Login acepta el valor de `username` como email (case-insensitive).
- Password mínima: longitud ≥ 8 (ajustar si el product pide más).
- Tras `change-password` exitoso: `must_change_password = false`.

### 5.2 Entidad `Installation`

Representa una terminal configurada.

| Campo | Tipo | Notas |
|-------|------|--------|
| `id` | int64 | PK autoincremental, sin significado de negocio |
| `installation_id` | str(8) | Clave funcional única configurada en la terminal |
| `platform` | str \| null | Opcional a futuro: `pos` / `mobile` / … (no requerido en fase 1) |
| `last_seen_at` | datetime | Último login/register exitoso |
| `created_at` | datetime | UTC |

Al autenticarse, se hace upsert por la clave funcional `installation_id` y se
asocia la sesión JWT a ese valor. Las relaciones SQL usan siempre el `id`
surrogado; el procesador valida que la terminal funcional esté dada de alta.

### 5.3 Token JWT (claims mínimos)

| Claim | Valor |
|-------|--------|
| `sub` | user id (int64 serializado como string) |
| `email` | email |
| `installation_id` | instalación del client (§3) |
| `jti` | id único de esta sesión (opcional pero recomendado) |
| `exp` | expiración |
| `iat` | emisión |

TTL sugerido fase 1: **24h** (ajustable vía settings). Sin refresh token todavía.

## 6. Diseño por capas (top-down)

```
presentation/          # HTTP: schemas, controllers, deps
  controllers/auth_controller.py
  schemas/auth.py      # request/response Pydantic
  dependencies.py      # get_current_user, get_db, settings

application/           # casos de uso
  auth/
    register_user.py
    login_user.py
    change_password.py
    token_service.py   # emitir / verificar JWT

domain/
  user.py              # entidad / value objects
  installation.py      # entidad Installation
  exceptions.py        # EmailAlreadyExists, InvalidCredentials, ...

persistence/
  models/user.py
  models/installation.py
  repositories/user_repository.py
  repositories/installation_repository.py
  database.py          # engine, session factory
  migrations/          # Alembic
```

Flujo tipico:

```
HTTP → controller → use case → repository / token_service → domain rules
                ↘ schemas (DTO) ↗
```

Principios:

- Controllers sin lógica de negocio: parsean request, llaman use case, mapean errores a status HTTP.
- Use cases dependen de abstracciones del repo (puerto), no de SQLAlchemy directo si se puede mantener simple.
- `password_hash` no sale del application/persistence hacia response.
- `installation_id` se valida como string requerido de hasta 8 caracteres.

## 7. Configuración y dependencias

### 7.1 Paquetes a agregar (`pyproject.toml`)

- `sqlalchemy` + driver async (`asyncpg`) o sync (`psycopg[binary]`) — elegir **un** estilo y ser consistente
- `alembic`
- `pwdlib[argon2]` (o `argon2-cffi`)
- `PyJWT`
- `pydantic-settings`
- `email-validator` (validación de email en schemas)

### 7.2 Settings (env)

| Variable | Uso | Ejemplo local |
|----------|-----|---------------|
| `DATABASE_URL` | Conexión Postgres | `postgresql+psycopg://solidaridad:solidaridad@localhost:5434/solidaridad` |
| `JWT_SECRET` | Firma HS256 (secreto fuerte, no commitear) | valor largo solo para local |
| `JWT_ALGORITHM` | Default `HS256` | `HS256` |
| `JWT_EXPIRE_MINUTES` | TTL del access token | `1440` |
| `APP_ENV` | `local` / `dev` / `prod` | `local` |
| `POSTGRES_USER` | Usuario del container Compose | `solidaridad` |
| `POSTGRES_PASSWORD` | Password del container Compose | `solidaridad` |
| `POSTGRES_DB` | Nombre de DB del container | `solidaridad` |
| `POSTGRES_PORT` | Puerto publicado en host | `5434` (default del example; cambiar si el puerto está libre o ocupado) |

Detalle de archivos y flujo local: Fase 0 (§8).

## 8. Fases de implementación

### Fase 0 — Cimientos + desarrollo local

Objetivo: un developer puede clonar, levantar Postgres, migrar, seedear y correr la API sin pasos manuales opacos.

#### 0.1 Dependencias y settings

1. Agregar dependencias y sync (`uv add` / `uv sync`) — ver §7.1.
2. `Settings` con `pydantic-settings` leyendo `.env`.
3. `database.py`: engine + session + dependency `get_db`.
4. Modelos SQLAlchemy `User` + `Installation` + migración Alembic inicial.

#### 0.2 Archivos de entorno

1. Crear `api/.env.example` versionado con todas las vars de §7.2 (valores seguros de ejemplo, nunca secretos reales de prod).
2. Crear `api/.env` local a partir del example (**gitignored**).
3. Asegurar `api/.gitignore` ignore `.env`, `__pycache__/`, `.venv/`, artefactos de uvicorn/pytest, etc.
4. Documentar: “copiar `.env.example` → `.env`” como primer paso tras clonar.

#### 0.3 Docker Compose (Postgres local)

1. Agregar `api/docker-compose.yml` (o `api/compose.yml`) con servicio `db`:
   - Imagen `postgres:16` (o LTS vigente).
   - Env desde `.env` / defaults (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`).
   - Puerto publicado (`POSTGRES_PORT:5432`).
   - Volume nombrado para persistir data entre reinicios.
   - Healthcheck (`pg_isready`) para que migrate/seed esperen DB lista.
2. La API **no** hace falta containererizar en fase 0 (correr con `uv` en host apunta a `localhost`). Dockerfile de la API queda opcional / fuera de esta fase si no se necesita.
3. Targets Make:
   - `make db-up` → `docker compose up -d`
   - `make db-down` → `docker compose down`
   - `make db-logs` → logs del servicio
   - `make db-reset` → `down -v` + `up -d` (borra volume; uso consciente en local)

#### 0.4 Migraciones

1. Inicializar Alembic (`alembic.ini`, `persistence/migrations/` o convención del repo).
2. Primera revisión: tablas `users` + `installations`.
3. Targets Make:
   - `make migrate` → `uv run alembic upgrade head`
   - `make migrate-new MSG="..."` → autogenerate / revisión nueva (si se adopta)
4. Flujo local estándar: `db-up` → esperar healthy → `migrate`.

#### 0.5 Población / seed de la base

1. Script o comando idempotente de seed, p. ej. `python -m persistence.seed` o `make db-seed`.
2. Datos mínimos de desarrollo (documentados en README):
   - Usuario demo: email/password conocidos (solo `APP_ENV=local`).
   - Al menos un `installation_id` de ejemplo (p. ej. `05000001`).
   - Usuario con `must_change_password=true` para probar el flujo de primer login.
3. El seed **no** corre en prod automáticamente; solo manual / Make en local (y CI de integration si aplica).
4. Passwords del seed hasheadas con Argon2 (mismo path que producción), nunca plaintext en DB.
5. Target Make: `make db-seed` (falla claro si no es `APP_ENV=local`, opcional pero recomendable).

#### 0.6 DX: Make + README

1. Ampliar `Makefile` con: `install`, `db-up`, `db-down`, `db-reset`, `migrate`, `db-seed`, `run`, y un atajo `make dev` = `db-up` + `migrate` + `run` (seed opcional / aparte).
2. Actualizar `api/README.md` con:
   - Prerrequisitos: Python 3.12, `uv`, Docker.
   - Quickstart: copiar `.env` → `make install` → `make db-up` → `make migrate` → `make db-seed` → `make run`.
   - Tabla de env vars (§7.2).
   - Credenciales del usuario demo de seed.
   - Cómo pegarle desde el mobile (base URL `http://<host-lan>:8000/v1` / notes de emulator si aplica).

#### 0.7 Criterio de done (Fase 0)

**Done when:**

1. `cp .env.example .env && make install && make db-up && make migrate && make db-seed && make run` deja la API respondiendo en `:8000`.
2. Existen tablas `users` e `installations`.
3. El seed es idempotente (segunda ejecución no rompe ni duplica usuarios).
4. `.env` no está en git; `.env.example` sí.
5. `api/README.md` documenta el flujo completo de desarrollo local.

### Fase 1 — Register

1. Domain `User` / `Installation` + excepción `EmailAlreadyExists`.
2. `UserRepository` + `InstallationRepository` (create / get / upsert).
3. Use case `RegisterUser`: validar → hash → persistir user → upsert installation → emitir JWT con `installation_id`.
4. Controller `POST /v1/auth/register`.
5. Prefijo `/v1` en el router de la API.

**Done when:** register crea usuario, registra installation y devuelve `{ name, email, token, must_change_password }` con claim `installation_id` en el token.

### Fase 2 — Login

1. Use case `LoginUser`: buscar por email → verificar Argon2 → upsert installation → emitir JWT + flag.
2. Controller `POST /v1/auth/login` (campo `username` mapeado a email; `installation_id` requerido).
3. Respuesta 401 uniforme ante fallo de credenciales; 400 si falta `installation_id`.

**Done when:** login con credenciales válidas/invalidas se comporta según contrato §4.2.

### Fase 3 — Change password + dependencia Bearer

1. `TokenService.verify` + dependency `get_current_user` (incluye `installation_id` del token).
2. Use case `ChangePassword`: verificar current → hash new → `must_change_password=false`.
3. Controller `POST /v1/auth/change-password` (protegido).
4. Tests de auth inválida / token expirado.

**Done when:** change-password exige Bearer y limpia el flag.

### Fase 4 — Alineación mobile

1. Leer el `installation_id` de 8 caracteres configurado en la terminal.
2. Enviar `installation_id` en login y register.
3. Enviar `Authorization: Bearer <token>` en `changePassword`.
4. Consumir `must_change_password` del JSON de login (eliminar mock `_usersWithPasswordChanged`).
5. Apuntar base URL local/dev configurable (hoy hardcodeada a prod).

**Done when:** flujo login → must change → change-password → home funciona contra la API local con `installation_id`.

### Fase 5 — Hardening mínimo

1. Política de password (longitud, opcional complejidad).
2. Rate limiting básico en login/register (middleware o reverse proxy).
3. No loguear passwords ni tokens.
4. CORS solo si hace falta para web/dev.

**Done when:** checklist de seguridad §9 marcada.

## 9. Checklist de seguridad

- [ ] Passwords solo como hash Argon2; nunca en responses ni logs
- [ ] `JWT_SECRET` solo por env / secret manager
- [ ] Mensajes de login genéricos (sin “usuario no existe”)
- [ ] Email único a nivel DB (constraint) además de check en app
- [ ] `installation_id` requerido y acotado (longitud máx.); string opaco, sin confiar en su formato
- [ ] HTTPS en entornos desplegados (infra, no app)
- [ ] Validación de input con Pydantic en todos los endpoints auth
- [ ] Tokens con `exp`; rechazar firmas inválidas; claim `installation_id` presente

## 10. Pruebas sugeridas

| Capa | Qué cubrir |
|------|------------|
| Use cases | register ok / email duplicado; login ok / bad password; change ok / bad current; login/register sin `installation_id` |
| HTTP | status codes y shape JSON del contrato §4 |
| Dependency | Bearer ausente, malformado, expirado; `installation_id` disponible desde el token |

Arrancar con tests de application (+ tests de controller con DB de test o SQLite si se elige soporte).

## 11. Orden de archivos a crear (referencia)

Orden sugerido al implementar Fase 0–3:

**Fase 0 (local + cimientos)**

1. `api/.gitignore` (si falta), `api/.env.example`
2. `api/docker-compose.yml` (Postgres + volume + healthcheck)
3. Settings (`pydantic-settings`) + carga de `.env`
4. `persistence/database.py`
5. `persistence/models/user.py`, `persistence/models/installation.py`
6. Alembic (`alembic.ini`, migraciones) + primera revisión
7. `persistence/seed.py` (o equivalente) + datos demo
8. `Makefile` ampliado (`db-up`, `db-down`, `db-reset`, `migrate`, `db-seed`, `dev`)
9. `api/README.md` (quickstart local)

**Fases 1–3 (auth)**

10. `domain/user.py`, `domain/installation.py`, `domain/exceptions.py`
11. `persistence/repositories/user_repository.py`, `persistence/repositories/installation_repository.py`
12. `application/auth/token_service.py`
13. `application/auth/register_user.py`
14. `application/auth/login_user.py`
15. `application/auth/change_password.py`
16. `presentation/schemas/auth.py`
17. `presentation/controllers/auth_controller.py`
18. Wiring en `presentation/dependencies.py`, `presentation/router.py`, `main.py` (prefijo `/v1`)

## 12. Fuera de alcance (explícito)

- Refresh tokens / logout server-side / denylist
- OAuth / social login
- Verificación de email
- Forgot-password por email
- Roles, permisos, multi-tenant
- Allowlist User↔Installation (restringir desde qué instalaciones puede operar un usuario)
- Implementación de `/v1/sales/gas` (solo reutilizará `get_current_user` + `installation_id` del token)

## 13. Criterio de “auth completo”

Auth se considera cerrado cuando:

1. Los tres endpoints del §4 responden al contrato (incluido `installation_id` en login/register).
2. Existe `get_current_user` reutilizable con `user_id` e `installation_id`.
3. Hay entorno local reproducible: Compose + `.env.example` + migrate + seed idempotente (§8 Fase 0).
4. El mobile envía `installation_id`, usa token real y `must_change_password` del server (Fase 4).
5. Checklist §9 cubierta al nivel mínimo acordado.
