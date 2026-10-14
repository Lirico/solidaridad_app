# Backlog incremental para reversos automáticos

> Documento de ejecución basado en
> [`plan-reversos-automaticos.md`](plan-reversos-automaticos.md).
>
> Estado: RA-00 a RA-04 completadas. RA-05 es la siguiente tarea del orden de
> integración.
>
> Última revisión: 2026-10-13.

## 1. Objetivo

Convertir el diseño de reversos automáticos en tareas pequeñas, implementables,
testeables y revisables de forma independiente. Cada tarea se desarrolla en su
propia branch, conserva commits incrementales y deja el repositorio en un estado
integrable.

Este documento no reemplaza el diseño funcional. Si aparece una contradicción,
primero se actualiza el plan de diseño y luego este backlog.

## 2. Reglas de trabajo

### 2.1 Una branch por tarea

Cada tarea `RA-XX` usa una branch propia:

```text
codex/reversal-ra-XX-descripcion-corta
```

La branch se crea desde `main` actualizado con todas sus dependencias ya
integradas. No se reutiliza una branch para dos tareas y no se incorporan
refactors ajenos al alcance.

Si dos tareas pueden ejecutarse en paralelo, cada una parte del ancestro común
indicado en la tabla de dependencias. Si una tarea necesita una branch todavía
no integrada, debe esperar o declarar explícitamente que es una branch apilada.

### 2.2 Commits incrementales

Cada branch conserva entre dos y cinco commits cohesivos. El orden esperado es:

1. modelo/contrato o migración;
2. comportamiento productivo;
3. pruebas;
4. documentación operativa y actualización de gaps.

Los mensajes sugeridos usan Conventional Commits. Los commits indicados en cada
tarea son una guía mínima; pueden dividirse más si cada commit compila y tiene
sentido por sí mismo. No se debe dejar un commit intermedio que rompa los checks
del componente salvo una migración y su modelo inseparables dentro del mismo
commit.

No se recomienda hacer squash al integrar: los commits incrementales son parte
de la trazabilidad pedida para este trabajo.

### 2.3 Definition of Done común

Toda tarea debe cumplir:

- criterios de aceptación propios cubiertos;
- pruebas nuevas para caminos exitosos, fallos y límites relevantes;
- PAN, vencimiento y otros datos sensibles ausentes de logs, errores, fixtures
  versionados y snapshots;
- migraciones con `upgrade` y `downgrade` comprobados cuando corresponda;
- contratos públicos compatibles o con cambio documentado;
- actualización de `docs/gaps.md` en el mismo trabajo si se implementa,
  completa o invalida alcance;
- actualización de `docs/alcance.md` si cambia una decisión de producto;
- actualización de este backlog si el trabajo descubre una dependencia nueva;
- diff limitado a la tarea y sin modificar cambios locales ajenos.

Quality gates finales por componente:

```text
api/                 make check
payment-gateway/     make check
mobile/              flutter analyze && flutter test
```

Si una branch modifica más de un componente, ejecuta todos los gates aplicables.
En `api/` y `payment-gateway/` la cobertura total debe permanecer en al menos
90 %.

### 2.4 Reglas de seguridad y compatibilidad

- `payment_processor/legacy/` es inmutable durante estas tareas. Un bug
  reproducible que obligue a cambiarlo requiere una tarea nueva, acotada, y la
  actualización de `payment_processor/LEGACY_CHANGELOG.md`.
- Nunca se persiste CVV.
- El PAN completo se persiste en texto plano por la aceptación de riesgo del
  diseño, pero nunca sale en respuestas ni observabilidad.
- `FAILED` solo se publica cuando se sabe que no existe un impacto activo.
- Un reverso ambiguo nunca se reenvía automáticamente: pasa a
  `MANUAL_REVIEW`.
- Una operación `PENDING / UNDER_REVIEW` no bloquea una venta independiente con
  otra `Idempotency-Key`.
- La anulación existente (`void`) no se mezcla con el reverso técnico (`0400`).

## 3. Orden de integración

| Tarea | Resultado | Depende de | Puede avanzar en paralelo con |
|---|---|---|---|
| RA-00 | Evidencia ejecutable del `0400` legacy | — | RA-03, RA-04 |
| RA-01 | Construcción ISO del reverso | RA-00 | RA-03, RA-04 |
| RA-02 | Endpoint `/v1/reverse` del gateway | RA-01 | RA-03, RA-04 |
| RA-03 | Datos de recuperación en `transactions` | — | RA-00 a RA-02, RA-04 |
| RA-04 | Jobs y configuración persistida | — | RA-00 a RA-03 |
| RA-05 | Puerto API ↔ gateway y taxonomía de resultados | RA-02 | — |
| RA-06 | Reintentos seguros de autorización | RA-03, RA-04, RA-05 | — |
| RA-07 | Creación atómica del job ante ambigüedad | RA-04, RA-06 | — |
| RA-08 | Consulta y contrato público `PENDING` | RA-07 | RA-09 |
| RA-09 | Reclamo y ejecución de jobs | RA-04, RA-05, RA-07 | RA-08 |
| RA-10 | Timeouts, `MANUAL_REVIEW` y alertas durables | RA-09 | — |
| RA-11 | Worker embebido en FastAPI | RA-10 | RA-12, RA-13 |
| RA-12 | Operación de casa central y resolución manual | RA-08, RA-10 | RA-11, RA-13 |
| RA-13 | Protección del cierre de lote | RA-07, RA-10 | RA-11, RA-12 |
| RA-14 | Polling mobile de operaciones en proceso | RA-08 | RA-09 a RA-13 |
| RA-15 | `UNDER_REVIEW`, comprobante y nueva venta | RA-08, RA-10, RA-14 | RA-12 |
| RA-16 | Observabilidad y controles de datos sensibles | RA-11, RA-12 | RA-15 |
| RA-17 | Pruebas integrales y activación controlada | RA-13, RA-15, RA-16 | — |

Camino crítico aproximado:

```text
RA-00 → RA-01 → RA-02 → RA-05 → RA-06 → RA-07 → RA-09
                                                   └────→ RA-10 → RA-11
                                      RA-08 → RA-14 ─────→ RA-15
                                                   └────→ RA-12
                                      RA-13 ─────────────→ RA-17
```

## 4. Tareas

## RA-00 — Caracterizar el reverso del procesador legacy

**Branch:** `codex/reversal-ra-00-legacy-contract`

**Estado:** completada el 2026-10-12. Evidencia en
`payment-gateway/docs/legacy-reversal-contract.md` y fixtures ejecutables en
`payment-gateway/tests/fixtures/legacy_reversal_contract.json`.

**Objetivo:** obtener evidencia reproducible del mensaje `0400` y de las
garantías reales del procesador antes de implementar recuperación automática.

**Alcance:**

- documentar campos obligatorios y coincidencia contra la venta original;
- capturar mensajes anonimizados o sintéticos de request/response;
- comprobar venta existente, venta inexistente, duplicado y reverso antes de
  que la venta termine de registrarse;
- comprobar si `00` diferencia “revertida” de “original inexistente”;
- determinar si repetir el mismo `0400` es idempotente;
- no modificar el código C legacy.

**Commits sugeridos:**

1. `test(gateway): add sanitized reversal contract fixtures`
2. `test(gateway): characterize legacy 0400 responses`
3. `docs(payments): record reversal processor guarantees`

**Pruebas:**

- tests de caracterización sobre fixtures en `payment-gateway/tests/`;
- prueba de integración manual contra el procesador local, con PAN sintético;
- `make check` en `payment-gateway/`.

**Criterio de aceptación:** existe una matriz de resultados reproducible que
permite fijar el contrato operativo. Por decisión de producto, el `0400` solo
se emite para un `0200` previamente enviado y `0410/00` se acepta como
`REVERSED_CONFIRMED`; una fila `0400` sin original no afecta el saldo.

---

## RA-01 — Agregar el mensaje ISO8583 de reverso al gateway

**Branch:** `codex/reversal-ra-01-gateway-iso`

**Estado:** completada el 2026-10-12. Contrato en
`payment-gateway/domain/reversal.py`, construcción `0400` y transporte en
`payment-gateway/infrastructure/iso/`, y cobertura byte a byte en
`payment-gateway/tests/test_reversal_iso.py`.

**Objetivo:** modelar y construir el `0400` sin exponer todavía un endpoint
HTTP.

**Alcance:**

- agregar `ReverseCommand` y resultado tipado;
- extender el puerto `IsoProcessor` con `reverse`;
- construir el mensaje con PAN, vencimiento, importe, terminal, identificadores
  originales y un `reversal_stan` estable en el contrato de orquestación; por
  el contrato probado en RA-00, DE11 conserva el STAN original y el legacy no
  ofrece un DE separado donde transmitir `reversal_stan`;
- mantener separado `build_void_request` del nuevo
  `build_reversal_request`;
- extender mock y transporte TCP sin reintentos internos.

**Commits sugeridos:**

1. `feat(gateway): define reversal domain contract`
2. `feat(gateway): build ISO 0400 reversal message`
3. `test(gateway): cover reversal packing and validation`

**Pruebas:**

- presencia y valor de cada bitmap/DE requerido;
- ausencia de campos no permitidos;
- normalización de STAN, ticket, terminal y vencimiento;
- vectores binarios contra las fixtures de RA-00;
- `make check` en `payment-gateway/`.

**Criterio de aceptación:** dado un comando fijo, el packer genera exactamente
el `0400` validado en RA-00 y nunca reutiliza la lógica de anulación `0200`.

---

## RA-02 — Exponer `POST /v1/reverse` en el gateway

**Branch:** `codex/reversal-ra-02-gateway-http`

**Estado:** completada el 2026-10-13. Endpoint stateless en
`payment-gateway/presentation/controllers/reversal_controller.py`, caso de uso
en `payment-gateway/application/payments/reverse_payment.py` y cobertura HTTP
en `payment-gateway/tests/test_reversal_http.py`.

**Objetivo:** ofrecer a la API una primitiva HTTP stateless para un único
intento de reverso.

**Alcance:**

- agregar schema, controller y caso de uso `ReversePayment`;
- validar sin loguear PAN ni request body;
- mapear el transporte a resultados explícitos:
  `REVERSED_CONFIRMED`, `PROCESSOR_DECLINED`, `NOT_SENT` e `INDETERMINATE`;
- usar HTTP `503` solo cuando existe certeza de no envío y `502` cuando el
  resultado es ambiguo;
- no hacer reintentos dentro del gateway.

**Commits sugeridos:**

1. `feat(gateway): add reverse payment use case`
2. `feat(gateway): expose reverse HTTP endpoint`
3. `test(gateway): cover reverse HTTP outcome mapping`

**Pruebas:**

- validación de body y sanitización de errores;
- respuestas para confirmación, rechazo, no enviado, timeout, respuesta rota y
  error inesperado;
- contrato OpenAPI sin ejemplos con PAN real;
- `make check` en `payment-gateway/`.

**Criterio de aceptación:** una llamada produce como máximo un intento TCP y la
respuesta permite distinguir con certeza `NOT_SENT` de `INDETERMINATE`.

---

## RA-03 — Persistir datos de recuperación en la transacción

**Branch:** `codex/reversal-ra-03-transaction-recovery-data`

**Estado:** completada el 2026-10-13. Migración
`20261013_0008_transaction_recovery_data.py`, outcome interno tipado y
persistencia previa al efecto externo en la API. Las filas históricas conservan
PAN/outcome nulos y no son recuperables automáticamente.

**Objetivo:** guardar antes del efecto externo todo lo necesario para recuperar
una autorización después de reiniciar la API.

**Alcance:**

- migración y modelo para `card_number`, `expiration_date`,
  `authorization_outcome` y `authorization_attempt_count`;
- valores de outcome: `PENDING`, `APPROVED`, `DECLINED`, `NOT_SENT` e
  `INDETERMINATE`;
- columnas de PAN/vencimiento excluidas de schemas públicos y `repr`;
- fingerprint calculado con el PAN completo normalizado dentro del hash, no con
  solo `last4`;
- PAN persistido antes de invocar al gateway y CVV descartado;
- estrategia explícita para filas históricas sin PAN: permanecen no
  recuperables y no generan jobs automáticamente.

**Commits sugeridos:**

1. `feat(api): migrate transaction recovery fields`
2. `feat(api): persist authorization recovery data`
3. `test(api): verify PAN persistence and public redaction`
4. `docs(gaps): record recovery data coverage and PCI debt`

**Pruebas:**

- upgrade/downgrade sobre una base con datos previos;
- creación y lectura interna con PAN y vencimiento;
- CVV nunca persistido;
- serializers, listados, errores y eventos nunca contienen PAN;
- colisión de tarjetas con mismo `last4` pero PAN diferente en idempotencia;
- `make check` en `api/`.

**Criterio de aceptación:** después del commit local de `PENDING`, otra
instancia puede reconstruir el request al procesador usando solo Postgres.

---

## RA-04 — Crear jobs y configuración persistida

**Branch:** `codex/reversal-ra-04-jobs-config`

**Estado:** completada el 2026-10-13. La migración `20261013_0009` incorpora
ambas tablas, la política `default` y sus constraints; los modelos de dominio y
repositorios permiten crear/consultar jobs y rechazan transiciones inválidas,
sin iniciar ejecución en background.

**Objetivo:** incorporar las estructuras durables sin ejecutar aún el worker.

**Alcance:**

- tablas/modelos/repositorios `processor_jobs` y
  `payment_processing_config`;
- PK `BIGINT IDENTITY` y FKs internas por `id`;
- estados `READY`, `PROCESSING`, `RETRY`, `COMPLETED`, `MANUAL_REVIEW`;
- campos `worker_id`, `claim_token`, `processing_started_at`, intentos,
  próximo intento, STAN/tickets y errores sanitizados;
- unicidad por transacción/tipo y por `reversal_stan`;
- fila `default` con constraints para intentos, delays, jitter, timeout de
  procesamiento y polling;
- repositorios unit testeables, sin loop en background.

**Commits sugeridos:**

1. `feat(api): add processor jobs migration and model`
2. `feat(api): add payment processing configuration`
3. `feat(api): add job and configuration repositories`
4. `test(api): cover job constraints and configuration snapshots`

**Pruebas:**

- upgrade/downgrade y constraints inválidos;
- unicidad del job y del STAN de reverso;
- lectura consistente de la fila `default`;
- transiciones inválidas rechazadas por dominio/repositorio;
- `make check` en `api/`.

**Criterio de aceptación:** se puede crear y consultar un job durable y su
política, pero ningún thread o request intenta ejecutarlo todavía.

---

## RA-05 — Tipar resultados y cliente de reversos en la API

**Branch:** `codex/reversal-ra-05-api-gateway-contract`

**Objetivo:** eliminar la ambigüedad de `FAILED`/`UNKNOWN` en la integración
interna y consumir `/v1/reverse`.

**Alcance:**

- reemplazar para autorización los outcomes internos genéricos por
  `APPROVED`, `DECLINED`, `NOT_SENT` e `INDETERMINATE`;
- agregar `ReverseRequest` y `ReverseResult` al puerto;
- implementar el cliente HTTP de reverso;
- clasificar conexión rechazada/`503` como `NOT_SENT`;
- clasificar timeout, `502`, respuesta inválida y desconexión posterior al
  envío como `INDETERMINATE`;
- conservar compatibilidad de balance y anulación sin reutilizar semánticas
  incorrectas.

**Commits sugeridos:**

1. `refactor(api): type authorization gateway outcomes`
2. `feat(api): add reversal gateway port and HTTP client`
3. `test(api): cover gateway failure classification`

**Pruebas:**

- matriz completa de excepciones `httpx` y códigos HTTP;
- payload exacto del reverso;
- ningún PAN en excepciones o mensajes de test;
- regresión de authorize, balance y void;
- `make check` en `api/`.

**Criterio de aceptación:** todo consumidor puede decidir de forma exhaustiva
si es seguro reintentar o si debe asumir posible impacto.

---

## RA-06 — Implementar reintentos seguros de autorización

**Branch:** `codex/reversal-ra-06-authorization-retries`

**Objetivo:** reintentar el mismo `0200` únicamente cuando se demuestra que no
salió.

**Alcance:**

- leer un snapshot de `payment_processing_config` al comenzar;
- contar el primer intento dentro de `max_authorization_attempts`;
- reutilizar STAN, ticket e Idempotency-Key;
- backoff y jitter configurables dentro del presupuesto síncrono;
- detener inmediatamente ante `APPROVED`, `DECLINED` o `INDETERMINATE`;
- al agotar `NOT_SENT`, publicar `FAILED` sin crear reverso;
- registrar cada intento sin datos sensibles.

**Commits sugeridos:**

1. `feat(api): add configurable authorization retry policy`
2. `feat(api): record authorization attempts and outcomes`
3. `test(api): cover safe authorization retry matrix`

**Pruebas:**

- 0 reintentos adicionales cuando el máximo es 1;
- éxito/rechazo en cualquier intento;
- agotamiento de `NOT_SENT`;
- `INDETERMINATE` corta el loop aunque queden intentos;
- delays con reloj y random inyectables, sin sleeps reales;
- `make check` en `api/`.

**Criterio de aceptación:** ningún resultado posiblemente enviado causa un
segundo `0200`, y `FAILED` por agotamiento solo surge de `NOT_SENT`.

---

## RA-07 — Crear el job atómicamente ante autorización ambigua

**Branch:** `codex/reversal-ra-07-ambiguous-outbox`

**Objetivo:** convertir `INDETERMINATE` en estado durable y responder
`202 PENDING` sin intentar el reverso desde el request.

**Alcance:**

- dentro de una transacción Postgres, guardar
  `authorization_outcome = INDETERMINATE`, mantener estado público `PENDING`,
  crear un job `REVERSE/READY` y registrar evento;
- generar una vez `reversal_stan` y reutilizarlo;
- asegurar idempotencia ante carrera y replay del request;
- no llamar `reverse()` desde `CreateTransaction`;
- watchdog inicial para transacciones `PENDING` envejecidas que quedaron entre
  persistencia y clasificación, creando el único job conservador;
- reemplazar el camino de autorización que hoy publica `UNKNOWN`.

**Commits sugeridos:**

1. `feat(api): atomically enqueue ambiguous authorizations`
2. `feat(api): enqueue stale pending transactions conservatively`
3. `test(api): cover crash windows and duplicate enqueue`
4. `docs(gaps): update ambiguous authorization recovery gap`

**Pruebas:**

- rollback conjunto si falla la creación del job;
- una sola fila ante dos intentos concurrentes;
- replay de la misma clave devuelve la operación existente;
- crash simulado antes y después del commit;
- la API devuelve `202` y no se invoca el reverso;
- `make check` en `api/`.

**Criterio de aceptación:** toda autorización ambigua confirmada localmente
tiene exactamente un trabajo durable antes de responder al cliente.

---

## RA-08 — Exponer consulta y contrato público de estado

**Branch:** `codex/reversal-ra-08-public-status-contract`

**Objetivo:** permitir que mobile recupere una operación aunque el request o la
instancia originales hayan desaparecido.

**Alcance:**

- agregar `GET /v1/transactions/{transaction_number}` limitado a la terminal
  autenticada;
- extender la respuesta con `reason`, `poll_after_seconds` y
  `may_start_new_sale`;
- proyectar job activo como `PENDING / PROCESSING`;
- proyectar `MANUAL_REVIEW` como `PENDING / UNDER_REVIEW`;
- mantener los cuatro estados públicos de autorización;
- conservar por compatibilidad el contrato existente de anulación `VOIDED`
  hasta que se diseñe su migración, sin mezclarlo con reversos;
- documentar `201`, `202`, `404` e idempotent replay en OpenAPI.

**Commits sugeridos:**

1. `feat(api): project internal payment recovery states`
2. `feat(api): add transaction status endpoint`
3. `test(api): cover pending and review public contracts`

**Pruebas:**

- aislamiento entre terminales;
- `PROCESSING` devuelve polling positivo y `may_start_new_sale = false`;
- `UNDER_REVIEW` devuelve polling nulo y `may_start_new_sale = true`;
- finales no exponen detalles del job;
- replay conserva la misma proyección;
- `make check` en `api/`.

**Criterio de aceptación:** mobile puede decidir su siguiente acción solo con
el contrato público y sin conocer `processor_jobs.state`.

---

## RA-09 — Reclamar y ejecutar jobs sin leases

**Branch:** `codex/reversal-ra-09-worker-executor`

**Objetivo:** implementar una iteración determinista del worker, invocable en
tests, todavía sin conectarla al lifespan.

**Alcance:**

- reclamar `READY`/`RETRY` vencidos mediante `FOR UPDATE SKIP LOCKED`;
- cambiar atómicamente a `PROCESSING` con `worker_id`, `claim_token` y
  `processing_started_at`;
- confirmar la transacción antes de la red;
- reconstruir `ReverseRequest` desde Postgres;
- `NOT_SENT` con intentos disponibles → `RETRY` y backoff;
- confirmación confiable → `COMPLETED` y estado público `FAILED`;
- rechazo permanente o `INDETERMINATE` → `MANUAL_REVIEW`;
- persistir el resultado con `WHERE state='PROCESSING' AND claim_token=:token`;
- nunca reclamar ni reactivar automáticamente un job `PROCESSING`.

**Commits sugeridos:**

1. `feat(api): claim reversal jobs with skip locked`
2. `feat(api): execute reversal job state machine`
3. `test(api): cover concurrent claims and conditional completion`

**Pruebas:**

- dos sesiones intentan reclamar el mismo job y solo una lo obtiene;
- commit del reclamo ocurre antes de llamar al fake gateway;
- matriz de resultados y agotamiento de intentos;
- respuesta tardía con token no vigente no cambia el job;
- no se reenvía una ejecución ambigua;
- `make check` en `api/`.

**Criterio de aceptación:** `run_once()` procesa como máximo un job con una
transición válida y es seguro ejecutarlo concurrentemente desde varias
instancias.

---

## RA-10 — Detectar jobs abandonados y generar alertas durables

**Branch:** `codex/reversal-ra-10-manual-review-alerts`

**Objetivo:** transformar falta de progreso en una acción operativa, sin
recuperación automática peligrosa.

**Alcance:**

- monitor de `PROCESSING` más antiguo que
  `processing_timeout_seconds`;
- transición condicional a `MANUAL_REVIEW` con error
  `PROCESSING_TIMEOUT`;
- considerar también agotamiento, error permanente e inconsistencia;
- crear registro durable de alerta `OPEN` asociado al job, único por causa;
- emitir evento/log estructurado sanitizado para el canal operativo;
- no volver a `READY` ni `RETRY` automáticamente;
- no depender de un proveedor externo de alertas para conservar el caso.

**Commits sugeridos:**

1. `feat(api): move stale processing jobs to manual review`
2. `feat(api): persist recovery alerts`
3. `test(api): cover stale jobs and alert deduplication`

**Pruebas:**

- reloj inyectable en el límite exacto del timeout;
- monitor concurrente ejecutado por dos réplicas;
- una sola alerta durable;
- late completion no sobrescribe revisión manual;
- payload de alerta sin PAN ni vencimiento;
- `make check` en `api/`.

**Criterio de aceptación:** una caída del worker deja un caso visible y
auditable en tiempo acotado, sin provocar otro `0400`.

---

## RA-11 — Ejecutar el worker dentro del proceso FastAPI

**Branch:** `codex/reversal-ra-11-fastapi-worker`

**Objetivo:** iniciar y detener un worker por proceso de FastAPI mediante el
lifespan.

**Alcance:**

- loop en thread dedicado porque DB y HTTP son síncronos;
- una sesión de DB independiente por iteración;
- señal de shutdown y prohibición de reclamar trabajo nuevo al detenerse;
- grace period para el job en curso;
- health/readiness con loop vivo, última iteración y último error;
- error fatal termina el proceso o degrada readiness, nunca queda silencioso;
- flag operativo inicialmente desactivado para desplegar antes de activar;
- comportamiento documentado para múltiples workers Uvicorn y `--reload`.

**Commits sugeridos:**

1. `feat(api): add embedded recovery worker loop`
2. `feat(api): wire worker into FastAPI lifespan`
3. `feat(api): expose worker health state`
4. `test(api): cover worker startup shutdown and fatal errors`

**Pruebas:**

- lifespan inicia exactamente un thread y lo detiene;
- el thread no bloquea requests;
- shutdown durante idle y durante ejecución;
- readiness ante loop muerto;
- dos instancias comparten jobs sin duplicarlos;
- `make check` en `api/`.

**Criterio de aceptación:** reiniciar una instancia no pierde jobs y un job
abandonado converge a `MANUAL_REVIEW`, no a una ejecución duplicada.

---

## RA-12 — Implementar revisión de casa central

**Branch:** `codex/reversal-ra-12-central-review`

**Objetivo:** permitir que un operador autorizado consulte, audite y resuelva
casos `MANUAL_REVIEW`.

**Alcance:**

- incorporar rol mínimo `CENTRAL_OPERATOR` separado del usuario terminal;
- provisionamiento administrativo explícito, sin permitir autorregistro con
  ese rol;
- endpoint interno para listar/ver jobs y alertas sin devolver PAN completo;
- acciones auditadas para resolver como:
  `REVERSED_CONFIRMED`, `PROCESSOR_DECLINED` o `ACTIVE_APPROVAL_CONFIRMED`;
- proyección final a `FAILED`, `DECLINED` o `APPROVED` según evidencia;
- conservar `authorization_outcome = INDETERMINATE` como hecho histórico;
- guardar operador, timestamp, motivo y referencia externa;
- acción separada para reintento manual, deshabilitada por defecto y con motivo
  obligatorio.

**Commits sugeridos:**

1. `feat(api): add central operator authorization`
2. `feat(api): expose manual recovery review endpoints`
3. `feat(api): audit manual payment resolutions`
4. `test(api): cover review authorization and resolution transitions`

**Pruebas:**

- usuario terminal recibe `403`;
- operador central ve datos enmascarados;
- transición y proyección por cada resultado;
- doble resolución es idempotente o rechazada con conflicto explícito;
- reintento manual exige motivo y política de seguridad;
- auditoría completa sin PAN;
- `make check` en `api/`.

**Criterio de aceptación:** casa central puede resolver una operación sin
editar directamente la base y toda acción queda atribuida y auditada.

---

## RA-13 — Bloquear cierre de lote con recuperación abierta

**Branch:** `codex/reversal-ra-13-batch-close-guard`

**Objetivo:** impedir que el cierre haga imposible completar o investigar una
operación del lote actual.

**Alcance:**

- rechazar el cierre ante transacción `PENDING`, outcome `INDETERMINATE` o job
  `READY`, `PROCESSING`, `RETRY`, `MANUAL_REVIEW`;
- realizar la comprobación y el cierre dentro de la misma transacción/locking;
- devolver conflicto con mensaje accionable, sin datos sensibles;
- permitir que la terminal continúe vendiendo aunque el cierre siga bloqueado;
- conservar el procedimiento administrativo futuro como única excepción.

**Commits sugeridos:**

1. `feat(api): guard batch close with open recoveries`
2. `test(api): cover recovery and close concurrency`
3. `docs(gaps): update batch close recovery coverage`

**Pruebas:**

- cada estado de job bloqueante;
- final confirmado permite cerrar;
- carrera entre cierre y creación del job;
- operaciones nuevas quedan en el siguiente lote;
- `make check` en `api/`.

**Criterio de aceptación:** ningún lote con recuperación abierta puede cerrarse
por el endpoint normal, sin bloquear la creación de ventas nuevas.

---

## RA-14 — Implementar polling de ventas pendientes en mobile

**Branch:** `codex/reversal-ra-14-mobile-polling`

**Objetivo:** tratar `202 PENDING / PROCESSING` como una operación en curso, no
como venta rechazada.

**Alcance:**

- modelar los cuatro estados de autorización y los campos de control;
- preservar `transaction_number` e `Idempotency-Key`;
- agregar consulta individual;
- poll respetando `poll_after_seconds`;
- detener por estado final, `UNDER_REVIEW`, timeout de UI o cierre de pantalla;
- reanudar desde historial/reinicio sin reenviar un `0200` nuevo;
- durante `PROCESSING`, mantener deshabilitada en UI una nueva venta;
- no usar WebSocket.

**Commits sugeridos:**

1. `refactor(mobile): model explicit sale statuses`
2. `feat(mobile): poll pending sale status`
3. `feat(mobile): restore pending operations`
4. `test(mobile): cover polling lifecycle and idempotency`

**Pruebas:**

- secuencias `PENDING → APPROVED|DECLINED|FAILED`;
- intervalos dictados por API con fake clock;
- navegación, cancelación y reinicio;
- ningún segundo POST durante polling;
- expiración de sesión y errores transitorios;
- `flutter analyze` y `flutter test`.

**Criterio de aceptación:** un `202` nunca se muestra como declinado y la misma
operación puede continuar consultándose después de perder la respuesta inicial.

---

## RA-15 — Mostrar `UNDER_REVIEW`, imprimir comprobante y liberar la venta

**Branch:** `codex/reversal-ra-15-mobile-review-receipt`

**Objetivo:** cerrar la interacción del operador sin afirmar un resultado
financiero que la API desconoce.

**Alcance:**

- interpretar `PENDING / UNDER_REVIEW`;
- detener polling automático cuando `poll_after_seconds` es nulo;
- mostrar mensaje de verificación con casa central;
- generar comprobante específico, distinto de aprobado/rechazado;
- incluir referencia, fecha/hora, comercio, terminal, importe y PAN enmascarado;
- advertir sobre posible cobro duplicado;
- habilitar nueva venta con nueva Idempotency-Key;
- conservar la operación anterior en historial y permitir consulta manual.

**Commits sugeridos:**

1. `feat(mobile): add under review sale state`
2. `feat(mobile): print payment verification receipt`
3. `feat(mobile): allow independent sale after review handoff`
4. `test(mobile): cover review receipt and new sale flow`

**Pruebas:**

- snapshot/texto plano y HTML del comprobante;
- PAN siempre enmascarado;
- no continúa el timer de polling;
- nueva venta genera clave distinta;
- operación anterior sigue visible y consultable;
- `flutter analyze` y `flutter test`.

**Criterio de aceptación:** el comercio obtiene una referencia verificable y
puede seguir operando, mientras la operación original permanece
`PENDING / UNDER_REVIEW`.

---

## RA-16 — Completar observabilidad y controles de datos sensibles

**Branch:** `codex/reversal-ra-16-observability-security`

**Objetivo:** hacer operable la recuperación sin filtrar PAN.

**Alcance:**

- métricas de jobs por estado, antigüedad, intentos y tiempo de resolución;
- métricas/readiness del worker;
- logs estructurados con `transaction_number`, job y códigos sanitizados;
- detector/test de PAN en logs, eventos y respuestas;
- revisión de acceso a columnas sensibles, backups y dumps;
- runbook de alerta, revisión manual y cierre de lote bloqueado;
- umbrales iniciales configurables;
- documentar deuda PCI aceptada y futura tokenización.

**Commits sugeridos:**

1. `feat(api): add payment recovery metrics and structured logs`
2. `test(api): prevent sensitive payment data leakage`
3. `docs(operations): add payment recovery runbook`
4. `docs(gaps): update observability and PCI gaps`

**Pruebas:**

- métricas ante cada transición;
- alerta durable y notificación deduplicadas;
- escaneo de respuestas/logs con PAN sintético completo;
- health/readiness degradado cuando corresponde;
- `make check` en `api/`.

**Criterio de aceptación:** soporte puede detectar y diagnosticar una
recuperación por identificadores no sensibles, y los tests fallan si el PAN
aparece en una salida prohibida.

---

## RA-17 — Validación integral y activación controlada

**Branch:** `codex/reversal-ra-17-e2e-rollout`

**Objetivo:** probar el flujo completo y habilitarlo por etapas con rollback
operativo.

**Alcance:**

- suite end-to-end API → gateway → procesador/mock determinista;
- fault injection en cada ventana de caída definida en el diseño;
- múltiples procesos FastAPI con workers simultáneos;
- prueba de mobile contra contratos `PROCESSING` y `UNDER_REVIEW`;
- prueba de cierre de lote;
- valores iniciales de configuración documentados;
- activación del worker primero en ambiente de prueba y luego productivo;
- checklist de rollback que detiene nuevos reclamos sin borrar jobs;
- conciliación posterior al despliegue.

**Commits sugeridos:**

1. `test(payments): add end to end reversal recovery scenarios`
2. `test(payments): add worker crash and concurrency scenarios`
3. `docs(operations): define reversal rollout and rollback`
4. `chore(payments): enable recovery worker configuration`
5. `docs(gaps): close validated reversal recovery gaps`

**Pruebas mínimas:**

1. aprobación y rechazo normales;
2. `NOT_SENT` con reintento y agotamiento;
3. venta aplicada con respuesta perdida;
4. API caída antes y después del envío;
5. reverso confirmado;
6. reverso `NOT_SENT` reintentable;
7. respuesta del reverso perdida → `MANUAL_REVIEW`, sin reenvío;
8. worker muerto → timeout, alerta y revisión manual;
9. respuesta tardía no pisa revisión manual;
10. dos workers no procesan el mismo job;
11. comprobante `UNDER_REVIEW` y nueva venta independiente;
12. resolución de casa central hacia cada estado final;
13. cierre de lote bloqueado hasta resolver;
14. PAN ausente de toda salida prohibida.

Quality gates:

```text
api/                 make check
payment-gateway/     make check
mobile/              flutter analyze && flutter test
```

**Criterio de aceptación:** la matriz integral pasa de forma repetible, el
worker puede habilitarse/deshabilitarse sin pérdida de jobs y existe evidencia
operativa para autorizar el rollout.

## 5. Estrategia de integración y despliegue

Las branches se integran en el orden de dependencias, no necesariamente por
número. Los cambios inertes de esquema y contrato pueden desplegarse antes que
el worker.

Secuencia recomendada:

1. desplegar migraciones y escritura de datos de recuperación;
2. desplegar gateway con `/v1/reverse`;
3. desplegar API con creación de jobs y consulta, worker desactivado;
4. desplegar mobile con soporte de `PENDING` antes de habilitar el worker;
5. verificar casa central, alertas y comprobantes;
6. habilitar worker en un ambiente controlado;
7. habilitar una réplica/canary y observar jobs, latencia y alertas;
8. habilitar el resto de las réplicas;
9. reconciliar cualquier `PENDING` previo a la activación.

Deshabilitar el worker solo detiene nuevos reclamos. No se eliminan jobs ni se
cambian automáticamente estados existentes. Un job que ya quedó
`PROCESSING` se resuelve normalmente o pasa a `MANUAL_REVIEW` por timeout.

## 6. Checklist para abrir cada branch

Antes de comenzar una tarea:

- confirmar que sus dependencias están integradas;
- actualizar `main` y crear la branch indicada;
- leer los `AGENTS.md` de todos los componentes alcanzados;
- ejecutar el quality gate de base;
- identificar cambios locales ajenos y preservarlos;
- copiar en la descripción del PR los criterios de aceptación de la tarea;
- declarar qué commits se planean antes de implementar.

Antes de integrar:

- verificar el diff commit por commit;
- ejecutar todos los quality gates aplicables;
- adjuntar evidencia de migración o concurrencia cuando corresponda;
- actualizar `docs/gaps.md` y, si aplica, `docs/alcance.md`;
- confirmar que no hay PAN, CVV ni secretos en el diff o outputs;
- rebasar sobre el `main` que contiene las dependencias y repetir los checks.
