# Rollout controlado — Worker de recuperación y reversos

Este procedimiento habilita el worker durable de recuperación de pagos por
etapas. Aplica después de desplegar la versión que contiene migraciones,
gateway con `POST /v1/reverse`, API y mobile con `PENDING / UNDER_REVIEW`.
No se borran jobs ni se modifica su estado mediante SQL durante una activación
o un rollback.

El runbook de incidentes y los límites de acceso a datos sensibles están en
[`runbook-recuperacion-pagos.md`](runbook-recuperacion-pagos.md).

## Valores iniciales

La bandera queda desactivada de forma segura en el artefacto base. El despliegue
del ambiente que se activa debe inyectar estos valores explícitos:

| Variable / configuración durable | Inicial | Justificación |
| --- | ---: | --- |
| `EMBEDDED_RECOVERY_WORKER_ENABLED` | `false` antes de cada etapa; `true` solo en réplicas seleccionadas | Permite desplegar y observar antes de reclamar jobs. |
| `EMBEDDED_RECOVERY_WORKER_SHUTDOWN_GRACE_SECONDS` | `40` s | Da tiempo a terminar la iteración actual durante un rollout o rollback. |
| `RECOVERY_WORKER_MAX_ITERATION_AGE_SECONDS` | `30` s | Hace que readiness falle si el loop deja de progresar. |
| `payment_processing_config.worker_poll_interval_seconds` | `1` s | Mantiene latencia baja sin usar polling desde mobile fuera del contrato público. |
| `payment_processing_config.processing_timeout_seconds` | `60` s | Debe ser mayor al timeout máximo del reverso y su margen operativo. |
| `payment_processing_config.max_reversal_attempts` | `5` | Cuenta el primer envío; agotarlo deriva a `MANUAL_REVIEW`. |

Cambios a `payment_processing_config` se realizan con el mecanismo operativo
autorizado y se auditan. No reactivan automáticamente un job
`MANUAL_REVIEW`.

## Precondiciones de activación

1. Confirmar migraciones aplicadas y que `GET /health/live` responde en todas
   las réplicas.
2. Confirmar que `GET /health/ready` responde `200` cuando la bandera está
   apagada y que la respuesta declara `recovery_worker.enabled=false`.
3. Verificar que el gateway apunta al transporte correspondiente al ambiente:
   `ISO_TRANSPORT=mock` únicamente para pruebas controladas; nunca asumir el
   mock en producción.
   Para una prueba local controlada, `make -C api run-recovery-worker` inicia
   una sola instancia sin `--reload` y sobrescribe la bandera solo para ese
   proceso.
4. Verificar que el mobile desplegado entiende `202 PENDING / PROCESSING` y
   `202 PENDING / UNDER_REVIEW` antes de habilitar el worker.
5. Revisar que no hay alertas `OPEN` sin dueño ni un cierre de lote en curso.
   Un job abierto bloquea el cierre hasta que finalice o quede en la futura
   resolución administrativa auditada.
6. Tener a mano el canal de incidentes y el acceso de solo lectura indicado en
   el runbook; no usar una consola SQL con privilegio de escritura para esta
   operación.

## Activación por etapas

1. Desplegar API y gateway con
   `EMBEDDED_RECOVERY_WORKER_ENABLED=false` en todas las réplicas. Verificar
   tráfico normal de autorizaciones y que ningún request síncrono envía un
   `0400`.
2. En el ambiente de prueba, habilitar la bandera en una única réplica y
   reiniciarla. Esperar dos intervalos de polling y comprobar
   `GET /health/ready`: `enabled=true`, `alive=true`, `stale=false` y sin
   `last_error`.
3. Ejecutar una venta controlada que obtenga resultado ambiguo con el mock
   determinista. Confirmar que la API responde inmediatamente `202 PENDING`,
   que se crea un único job y que el worker es quien ejecuta el reverso.
4. Repetir la prueba con dos réplicas habilitadas. Confirmar en eventos y
   base que cada job tiene un solo `claim_token` activo y que no hay dos
   envíos de un mismo reverso.
5. Mantener la prueba durante al menos 30 minutos sin readiness degradado,
   alertas inesperadas ni jobs que excedan el SLA. Verificar un cierre de lote
   controlado: debe bloquearse mientras exista recuperación abierta.
6. En producción, activar primero una réplica canary. Observar durante al
   menos 30 minutos las mismas señales y la conciliación indicada abajo.
7. Habilitar el resto de las réplicas una por una. Después de cada cambio,
   esperar dos intervalos de polling y verificar readiness. No incrementar
   `max_reversal_attempts` para resolver casos existentes.

## Rollback operativo

Un rollback de la bandera detiene nuevos reclamos: no elimina `processor_jobs`,
no convierte automáticamente `PROCESSING` ni reenvía un `0400`.

1. Registrar la hora, las réplicas afectadas y el motivo. Si `/health/ready`
   está degradado, retirar esas réplicas del balanceador antes de reiniciarlas.
2. Cambiar `EMBEDDED_RECOVERY_WORKER_ENABLED=false` en la configuración del
   despliegue y hacer rollout de las réplicas afectadas. Respetar los `40` s de
   gracia: una iteración que ya reclamó un job puede completar antes de parar.
3. Verificar que cada réplica devuelve `enabled=false` en `/health/ready`.
   Mantener el API disponible para que mobile consulte las operaciones
   pendientes; no pedir a la terminal un segundo cobro.
4. Inspeccionar por SQL de solo lectura los jobs `READY`, `PROCESSING`,
   `RETRY` y `MANUAL_REVIEW` creados durante la ventana. Un `PROCESSING`
   abandonado debe pasar a `MANUAL_REVIEW` por el monitor al reactivar una
   réplica sana, nunca por edición directa.
5. Abrir o actualizar el incidente con `transaction_number`, job, estado,
   intentos y código sanitizado. Seguir el triage de
   [`runbook-recuperacion-pagos.md`](runbook-recuperacion-pagos.md); no copiar
   PAN, vencimiento, payloads ni claves de idempotencia.

## Conciliación posterior al despliegue

Antes de ampliar una etapa y al concluir el rollout, Operaciones ejecuta esta
consulta con el rol de solo lectura. No selecciona datos de tarjeta, tickets ni
claves de idempotencia:

```sql
SELECT
  t.transaction_number,
  t.terminal_id,
  t.amount_minor,
  t.status AS transaction_status,
  j.id AS processor_job_id,
  j.state AS job_state,
  j.attempt_count,
  j.last_error_code,
  j.created_at,
  j.updated_at
FROM processor_jobs AS j
JOIN transactions AS t ON t.id = j.transaction_id
WHERE j.operation_type = 'REVERSE'
  AND j.state IN ('READY', 'PROCESSING', 'RETRY', 'MANUAL_REVIEW')
ORDER BY j.updated_at, j.id;
```

Para cada fila, correlacionar con `recovery_job_transition` o
`recovery_alert_opened`, confirmar el estado económico con casa central y
registrar la decisión en el incidente. `MANUAL_REVIEW` queda visible para el
comercio como `UNDER_REVIEW`, sin polling automático y permitiendo una nueva
venta independiente.

## Evidencia de validación

| Criterio | Evidencia automatizada |
| --- | --- |
| Aprobación, rechazo y agotamiento antes del envío | `api/tests/test_recovery_end_to_end.py` |
| Autorización aplicada con respuesta perdida y reverso confirmado | `api/tests/test_recovery_end_to_end.py` |
| Reverso `NOT_SENT`, respuesta ambigua y cuarentena | `api/tests/test_recovery_end_to_end.py` |
| Crash, timeout, alerta durable y no reenvío | `api/tests/test_recovery_end_to_end.py` |
| Dos workers reclaman solo una vez | `api/tests/test_recovery_end_to_end.py` y `api/tests/test_processor_job_repository.py` |
| Mobile ante `PROCESSING` y `UNDER_REVIEW` | `mobile/test/sales_polling_test.dart`, `mobile/test/sale_status_screen_test.dart` |
| Cierre de lote bloqueado | `api/tests/test_close_batch.py`, `api/tests/test_transaction_repository.py` |
| PAN ausente de eventos, respuestas y logs | `api/tests/test_sensitive_data_leakage.py` |

Ejecutar antes de autorizar cada etapa:

```text
api/                 make check
payment-gateway/     make check
mobile/              flutter analyze && flutter test
```

La evidencia manual del ambiente debe incluir la versión desplegada, hora,
réplicas activadas, salida sanitizada de readiness, resultado de conciliación y
la aprobación explícita de Operaciones/Riesgo para la siguiente etapa.
