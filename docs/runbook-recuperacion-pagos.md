# Runbook — Recuperación de pagos y reversos

Este procedimiento opera recuperaciones `PENDING / UNDER_REVIEW` sin exponer
PAN, vencimiento, CVV ni claves de idempotencia. No habilita resoluciones desde
la API: por ahora casa central investiga mediante SQL operacional de solo
lectura y escala la decisión a Finanzas/Riesgo.

## Señales y umbrales iniciales

`GET /health/live` comprueba que el proceso responde. `GET /health/ready`
comprueba además el worker: responde `503` cuando está detenido, apagándose,
falló o quedó `stale`. El balanceador debe usar únicamente `ready`.

La exposición de métricas y alertas automáticas se difiere. La señal durable
actual para operación es `recovery_alerts`, complementada por los eventos
estructurados y el endpoint de readiness.

| Señal | Acción inicial |
| --- | --- |
| `GET /health/ready` responde `503` durante 2 min | P1: retirar la réplica del tráfico y reiniciarla; conservar los jobs para que otra réplica los reclame. |
| Nueva fila `recovery_alerts` en estado `OPEN` | P1 operativo: abrir la cola de casos y avisar a casa central. La alerta durable evita duplicados por job y causa. |
| Job `READY`, `PROCESSING` o `RETRY` que excede el SLA operativo | P1 operativo: diagnosticar gateway/DB/worker y seguir el caso por `transaction_number`; no forzar otro `0400`. |

Los valores iniciales se cambian por entorno y requieren redeploy:

| Variable | Valor inicial | Propósito |
| --- | ---: | --- |
| `RECOVERY_WORKER_MAX_ITERATION_AGE_SECONDS` | 30 s | Degrada readiness si el loop no completa una vuelta. Debe superar el intervalo de polling más la variación normal. |

`payment_processing_config` conserva los valores de política de la cola,
incluidos `worker_poll_interval_seconds`, `processing_timeout_seconds` y el
máximo de intentos. Cambiarlos no reactiva un `MANUAL_REVIEW`.

## Triage de una alerta durable

1. Registrar el incidente y buscar el `transaction_number` del evento
   `recovery_alert_opened` o `recovery_job_transition`.
2. Verificar `/health/ready` y las señales de worker. Si hay una réplica sana,
   no reiniciar ni editar un job `PROCESSING`: el claim y `claim_token` evitan
   colisiones; un job abandonado se deriva a revisión manual.
3. Con la cuenta SQL de solo lectura, consultar exclusivamente los campos
   operativos. Esta consulta no selecciona PAN, vencimiento, claves de
   idempotencia, ticket original ni datos de autenticación:

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
     j.updated_at,
     a.cause AS alert_cause,
     a.opened_at
   FROM recovery_alerts AS a
   JOIN processor_jobs AS j ON j.id = a.processor_job_id
   JOIN transactions AS t ON t.id = j.transaction_id
   WHERE t.transaction_number = :transaction_number;
   ```

4. Correlacionar únicamente con el código de error sanitizado y el proveedor.
   No copiar payloads HTTP/ISO, trazas, dumps ni campos sensibles al ticket.
5. Si la evidencia no permite confirmar el efecto económico, conservar
   `MANUAL_REVIEW` y entregar al comercio la referencia de verificación. No
   reenviar el reverso ni modificar la fila por SQL.
6. Escalar al equipo que implemente la futura resolución autenticada y
   auditada. La resolución debe registrar operador, evidencia, fecha y motivo.

## Cierre de lote bloqueado

Un lote no cierra mientras exista una transacción `PENDING`/ambigua o un job
`READY`, `PROCESSING`, `RETRY` o `MANUAL_REVIEW`. Frente al conflicto:

1. No reintentar el cierre ni crear un cierre manual.
2. Ejecutar el triage del caso abierto y notificar a casa central con
   `transaction_number`, terminal, importe, job, intentos y código sanitizado.
3. Esperar una finalización automática segura o la futura resolución
   administrativa auditada. Solo entonces volver a solicitar el cierre.

## Acceso a datos sensibles, backups y dumps

La API/worker es el único principal de aplicación que necesita leer
`transactions.card_number` y `transactions.expiration_date` para construir un
reverso. Casa central y observabilidad no tienen ese permiso. En producción:

- usar roles separados: aplicación (mínimo privilegio), operación de solo
  lectura sobre una vista/lista explícita sin las columnas sensibles y DBA de
  emergencia; revisar grants trimestralmente y registrar cada acceso de
  emergencia con aprobación de Seguridad;
- no otorgar `SELECT` amplio de `transactions` al rol operativo; prohibir
  consultas `SELECT *`, exportaciones ad hoc y herramientas BI contra esas
  columnas;
- cifrar conexiones a Postgres y volumen/backups, limitar el almacenamiento de
  backups a la cuenta de infraestructura, aplicar retención aprobada y
  registrar restauraciones; una restauración de producción nunca se usa para
  desarrollo o pruebas;
- bloquear dumps de producción salvo incidente autorizado; si se requiere
  diagnóstico, producir una copia minimizada y enmascarada fuera de producción
  con control de acceso y destrucción verificable;
- usar solo PAN sintético en fixtures, logs y pruebas. CVV nunca se persiste.

Persistir PAN y vencimiento en texto plano para recuperación durable sigue
siendo deuda PCI aceptada temporalmente; estos controles no constituyen
certificación PCI. La salida prevista es un componente especializado que
reemplace ambos campos por token/referencia opaca, añada cifrado y auditoría de
acceso, y mantenga sin cambio la máquina de estados de recuperación.
