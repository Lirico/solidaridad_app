# Plan de reversos automáticos y recuperación durable

> Estado: recuperación de **ventas** implementada. La extensión a anulaciones
> está diseñada, pero la caracterización VA-00 demostró que un `0400/020000`
> no compensa de forma segura una anulación en el legacy vigente; ver
> [`diseno-recuperacion-anulaciones.md`](diseno-recuperacion-anulaciones.md).
> Por decisión de producto, el reverso solo se emite para un `0200` previamente
> enviado y `0410/DE39=00` confirma que el procesador aceptó la neutralización.
>
> Última revisión: 2026-10-22.

## 1. Objetivo

Evitar que una autorización cuyo resultado no pudo confirmarse quede cobrada en
el procesador pero presentada como fallida o desconocida en Solidaridad.

La propiedad buscada es:

> Ante un timeout, una respuesta inválida o la caída de una instancia, el
> sistema debe converger a una venta confirmada o a una neutralización
> confirmada. Si la recuperación automática no puede demostrar el resultado,
> debe conservar la incertidumbre, alertar a casa central y entregar al
> comercio una referencia verificable sin bloquear nuevas ventas.

El mecanismo de compensación es el reverso ISO8583 `0400` que ya reconoce el
procesador legacy.

La implementación actual aplica este objetivo a la autorización de una venta.
Una anulación también es un `0200`, pero tiene semántica de negocio distinta:
su incertidumbre no debe convertir la venta ya aprobada en `UNKNOWN` ni
habilitar un segundo envío desde la terminal. Su extensión se especifica por
separado para no prometer una equivalencia ISO todavía no verificada.

## 2. Decisiones de diseño

1. La API coordina la autorización, el reverso y la máquina de estados.
2. El gateway continúa siendo un adaptador HTTP → ISO y expone primitivas para
   autorizar, anular y reversar.
3. El camino normal de autorización sigue siendo síncrono. La terminal no debe
   hacer polling en todas las ventas.
4. El worker durable es el único responsable de ejecutar reversos. Corre en el
   mismo proceso que FastAPI, iniciado y detenido mediante su lifespan. La API
   no intenta el mismo reverso de manera síncrona después de crear el trabajo.
5. La terminal solo conoce cuatro estados públicos: `PENDING`, `APPROVED`,
   `DECLINED` y `FAILED`. `PENDING` es temporal, pero no siempre implica
   polling: `reason = UNDER_REVIEW` detiene el polling automático, imprime un
   comprobante de verificación y permite iniciar una venta independiente.
6. Para priorizar time to market, la API persistirá el PAN completo y el
   vencimiento en texto plano, sin borrado automático al finalizar la
   operación. Se acepta explícitamente el riesgo y el incumplimiento PCI de
   esta etapa; nunca se guardará el CVV.
7. `FAILED` es un resultado final y garantiza que la venta no produjo, o ya no
   conserva, un efecto en el procesador. Es seguro iniciar otra venta.
8. Los detalles técnicos internos (`authorization_outcome` y el estado del job
   de reverso) no se exponen a mobile: se proyectan como `PENDING` hasta
   alcanzar un final.
9. Anulación y reverso son operaciones diferentes:
   - la **anulación** es una acción voluntaria sobre una venta confirmada;
   - el **reverso** es una compensación técnica automática ante un resultado
     incierto.
10. Las cantidades de intentos y las políticas de backoff de autorización y
    reverso son configuración persistida. Como la API no tiene actualmente una
    tabla de configuración, se creará una específica para procesamiento de
    pagos.
11. No se usan leases ni se recuperan automáticamente jobs abandonados. Un job
    `PROCESSING` envejecido pasa a `MANUAL_REVIEW` para evitar reenviar un
    reverso que pudo haber impactado.
12. Una operación `PENDING` no bloquea toda la terminal ni impide una nueva
    venta con otra clave de idempotencia. La API solo impide reenviar la misma
    operación.
13. Una anulación ambigua tendrá su propia operación durable. No reutiliza ni
    altera el estado de recuperación de la venta original. VA-00 dejó probado
    que el legacy vigente no admite su compensación por `0400/020000`: queda en
    revisión manual y no se reenvía el `0200` ni se emite un `0400`.

## 3. Clasificación de resultados

No todo error requiere reverso. La decisión depende de si el mensaje ISO pudo
haber llegado al procesador.

| Situación | ¿Pudo impactar? | Tratamiento |
|---|---:|---|
| Validación fallida antes del envío | No | Rechazo técnico, sin reverso |
| No se pudo establecer la conexión TCP | No | Reintentar autorización según configuración; al agotar, `NOT_SENT` → `FAILED` |
| Respuesta de aprobación | Sí, confirmado | `APPROVED` |
| Respuesta de rechazo | No se concretó | `DECLINED` |
| Timeout después de iniciar el envío | Sí | Reverso automático |
| Conexión cerrada esperando la respuesta | Sí | Reverso automático |
| Respuesta ISO ilegible o incompleta | Sí | Reverso automático |
| `PENDING` envejecido tras una caída | No se sabe | Recuperación conservadora mediante reverso |

La frontera debe conservar la distinción ya iniciada en el sistema:

- `503`: no se pudo conectar al procesador; el mensaje no salió;
- `502`: fallo ambiguo; el mensaje pudo haber llegado.

Solo se reintenta la autorización cuando existe certeza de que el mensaje no
salió, por ejemplo conexión rechazada entre API/gateway o gateway/procesador.
Un timeout después de iniciar el envío, una conexión cortada esperando
respuesta o una respuesta inválida se clasifican como `INDETERMINATE`: no se
reenvía el `0200`; se crea el job de reverso.

## 4. Arquitectura híbrida

```text
Terminal ── POST ──> API ── síncrono ──> Gateway ── ISO ──> Procesador
                         │
                         └── ante ambigüedad o caída:
                             estado durable + trabajo de reverso
                                            │
                                            v
                                         Worker
```

### 4.1 Camino normal

1. La API valida la solicitud.
2. Antes de efectuar un efecto externo, crea una transacción `PENDING` con PAN,
   vencimiento e identificadores del procesador.
3. La API envía la autorización al gateway de manera síncrona.
4. Si el intento falla con certeza de que no hubo envío, la API reintenta el
   mismo `0200` con los mismos identificadores según la política configurada.
5. Si recibe `APPROVED` o `DECLINED`, persiste el resultado y responde en la
   misma petición HTTP.
6. Si agota los intentos seguros sin haber enviado, publica `FAILED`; no crea
   un reverso.
7. Si cualquier intento queda ambiguo, detiene los reintentos de autorización
   y entra al camino durable de reverso.
8. El PAN permanece persistido después del resultado final. En esta etapa no
   se implementa una política automática de purga.

En este camino no existe polling.

`max_authorization_attempts` cuenta el primer intento. Por ejemplo, `3`
significa un intento inicial y hasta dos reintentos seguros. Cada ejecución
incrementa `transactions.authorization_attempt_count` y registra un evento.
El backoff de autorización usa delays cortos porque ocurre dentro del
presupuesto síncrono del request.

La clasificación por intento es:

| Resultado del intento | Próxima acción |
|---|---|
| `APPROVED` | Finalizar `APPROVED` |
| `DECLINED` | Finalizar `DECLINED` |
| `NOT_SENT` y quedan intentos | Esperar el backoff y reintentar el mismo `0200` |
| `NOT_SENT` y se agotó el máximo | Finalizar `FAILED`, sin reverso |
| `INDETERMINATE` | Detener autorización, crear job de reverso y devolver `PENDING` |

No se reintentan automáticamente rechazos explícitos del procesador ni errores
permanentes de validación o formato.

### 4.2 Camino ambiguo

1. La API recibe un resultado que indica que el mensaje pudo haber llegado.
2. En una misma transacción de Postgres:
   - marca la venta como indeterminada;
   - crea un trabajo durable de reverso en estado `READY`;
   - registra el evento de estado.
3. La API confirma esa transacción local y responde `202 PENDING`. No envía el
   reverso desde el request HTTP.
4. El worker reclama el trabajo de forma atómica y es el único que envía el
   `0400`.
5. Si el reverso se confirma, el worker publica el resultado final `FAILED`:
   la venta no quedó aplicada y es seguro iniciar otra operación.
6. Solo programa otro intento si puede demostrar que el `0400` no fue enviado.
   Una respuesta ambigua, un error permanente o un job abandonado pasan a
   `MANUAL_REVIEW` sin reenvío automático.
7. Mientras el trabajo esté en recuperación automática, la terminal consulta
   la operación. Si pasa a revisión manual, recibe `PENDING` con
   `reason = UNDER_REVIEW`, detiene el polling automático, imprime el
   comprobante correspondiente y puede iniciar otra venta independiente.

Esta separación evita una carrera entre el request síncrono y el worker. Una
vez creado el trabajo durable, no existe otro ejecutor autorizado a enviar ese
reverso. El worker puede completar el trabajo antes del primer polling; en ese
caso la consulta devuelve directamente `FAILED`.

## 5. Estados

### 5.1 Contrato público de la terminal

La terminal solo conoce cuatro estados:

```text
PENDING
APPROVED
DECLINED
FAILED
```

| Estado | ¿Final? | Garantía | Acción de la terminal |
|---|---:|---|---|
| `PENDING` | No | La API aceptó la operación, pero todavía no puede afirmar su resultado | Seguir `reason` y `poll_after_seconds`; puede iniciar una venta independiente cuando `may_start_new_sale = true` |
| `APPROVED` | Sí | La venta quedó aplicada | Finalizar e imprimir |
| `DECLINED` | Sí | El procesador rechazó explícitamente la venta | Informar el rechazo; puede iniciar otra venta |
| `FAILED` | Sí | La venta no salió o cualquier posible efecto fue neutralizado | Informar el fallo; puede iniciar otra venta |

`PENDING` puede representar internamente autorización en curso, espera de
respuesta, resultado ambiguo, reverso en curso o revisión manual. Mobile no
interpreta los estados internos del worker. La API le entrega instrucciones
explícitas para dos variantes públicas:

| `reason` | `poll_after_seconds` | `may_start_new_sale` | Comportamiento |
|---|---:|---:|---|
| `PROCESSING` | valor positivo | `false` | Consultar la misma operación; un reenvío técnico conserva la misma clave |
| `UNDER_REVIEW` | `null` | `true` | Detener polling automático, imprimir comprobante y liberar la terminal para una venta nueva |

La venta nueva siempre usa un nuevo `transaction_id` y una nueva
`Idempotency-Key`; nunca se reenvía el `0200` incierto. Permitirla es una
decisión comercial explícita: puede existir un doble impacto que luego deba
reclamarse a casa central.

`FAILED` no significa timeout ni excepción. Solo se asigna cuando la API puede
garantizar que no queda un impacto activo en el procesador. En particular:

- fallo confirmado antes del envío → `FAILED`;
- autorización incierta con reverso confirmado → `FAILED`;
- autorización o reverso todavía inciertos → `PENDING`.

Los tres estados finales son inmutables. No existen transiciones desde
`APPROVED`, `DECLINED` o `FAILED` hacia otro estado.

Se separa el resultado de la autorización original del trabajo durable que
ejecuta su recuperación. No se agrega `recovery_status` a `transactions`: el
estado del job es la única fuente de verdad del reverso.

### 5.2 `transactions.authorization_outcome`

Describe exclusivamente qué sabe la API del `0200` original:

```text
PENDING
APPROVED
DECLINED
NOT_SENT
INDETERMINATE
```

| Valor | Significado |
|---|---|
| `PENDING` | La autorización todavía no produjo un resultado clasificable |
| `APPROVED` | El procesador confirmó la venta |
| `DECLINED` | El procesador rechazó explícitamente la venta |
| `NOT_SENT` | Existe certeza de que el mensaje no llegó al procesador |
| `INDETERMINATE` | El mensaje pudo haber llegado, pero no hay una respuesta confiable |

### 5.3 `processor_jobs.state` y `processor_jobs.result`

El estado de recuperación vive únicamente en el job de tipo `REVERSE`:

```text
READY
PROCESSING
RETRY
COMPLETED
MANUAL_REVIEW
```

| Estado del job | Significado |
|---|---|
| No existe job | La autorización no requiere recuperación |
| `READY` | El reverso está listo para ser reclamado |
| `PROCESSING` | Un worker reclamó el job y está ejecutando el reverso |
| `RETRY` | Existe certeza de que el `0400` no fue enviado y espera otro intento |
| `COMPLETED` | El job alcanzó un resultado terminal confirmado |
| `MANUAL_REVIEW` | La recuperación automática no puede continuar de forma segura |

`state` describe el ciclo de ejecución. `result` registra la respuesta de
negocio del reverso, por ejemplo:

```text
REVERSED_CONFIRMED
PROCESSOR_DECLINED
ACTIVE_APPROVAL_CONFIRMED
```

Mientras el job no sea terminal, `result` permanece nulo. Un resultado que no
garantice neutralización no permite publicar `FAILED`; debe conservar
`transactions.status = PENDING`. Solo un fallo concluyente anterior al envío
puede pasar a `RETRY`; una ejecución ambigua pasa a revisión manual.

### 5.4 Proyección al estado público

| `authorization_outcome` | Job de reverso | `transactions.status` público |
|---|---|---|
| `PENDING` | No existe o todavía no fue creado | `PENDING` |
| `APPROVED` | No existe | `APPROVED` |
| `DECLINED` | No existe | `DECLINED` |
| `NOT_SENT` | No existe | `FAILED` |
| `INDETERMINATE` | `READY`, `PROCESSING` o `RETRY` | `PENDING` |
| `INDETERMINATE` | `COMPLETED` + `REVERSED_CONFIRMED` | `FAILED` |
| `INDETERMINATE` | `COMPLETED` + `PROCESSOR_DECLINED` confirmado | `DECLINED` |
| `INDETERMINATE` | `COMPLETED` + `ACTIVE_APPROVAL_CONFIRMED` | `APPROVED` |
| `INDETERMINATE` | `MANUAL_REVIEW` | `PENDING` + `UNDER_REVIEW`; alerta operativa, comprobante y nuevas ventas permitidas |

Una resolución manual no reescribe retroactivamente
`authorization_outcome = INDETERMINATE`: ese campo conserva qué supo la API al
procesar el `0200`. La evidencia obtenida por casa central se registra en el
resultado del job y en eventos auditables; esa evidencia sí determina la
proyección pública final. Cuando confirma neutralización o inexistencia del
impacto, el resultado público es `FAILED`.

La fuente de verdad queda normalizada así:

| Información | Fuente |
|---|---|
| Estado que consume mobile | `transactions.status` |
| Resultado conocido del `0200` original | `transactions.authorization_outcome` |
| Ejecución durable del reverso | `processor_jobs.state` |
| Respuesta de negocio del reverso | `processor_jobs.result` |
| Historial de transiciones | `transaction_status_events` |

## 6. Flujo de estados

Flujo público que interpreta mobile:

```text
                    ┌────────────> APPROVED
                    │
NUEVA ──> PENDING ──┼────────────> DECLINED
                    │
                    └────────────> FAILED
```

Flujo técnico interno que la API proyecta sobre esos cuatro estados:

```text
authorization_outcome=PENDING
   │
   ├─ fallo previo al envío ─────────────────────> NOT_SENT
   │
   ├─ respuesta aprobada ────────────────────────> APPROVED
   │
   ├─ respuesta rechazada ───────────────────────> DECLINED
   │
   └─ envío posiblemente realizado
                  │
                  v
       authorization_outcome=INDETERMINATE
                  │
                  └── INSERT job.state=READY
                  v
          job.state=PROCESSING
               /       \
       confirmado       fallo previo al envío
           │                    │
           v                    v
 job.state=COMPLETED       job.state=RETRY
 result=REVERSED_CONFIRMED       │
           │                     ├──> PROCESSING
           v                     │
 transactions.status=FAILED      └──> MANUAL_REVIEW

Una respuesta ambigua o permanente durante `PROCESSING`, así como un job
abandonado, transiciona directamente a `MANUAL_REVIEW` sin reenvío automático.
```

## 7. Persistencia del PAN

Persistir el PAN completo aumenta el alcance y el riesgo PCI. La decisión es
aceptar temporalmente ese costo para obtener recuperación durable y priorizar
time to market. En esta primera implementación, el PAN y el vencimiento se
guardarán en columnas de texto plano de la base de datos de la API. Esta es una
aceptación explícita de riesgo, no una afirmación de cumplimiento PCI.

Requisitos mínimos:

- `card_last4` separado para visualización y búsqueda;
- prohibición absoluta de persistir CVV;
- PAN ausente de logs, trazas, excepciones, métricas, eventos y mensajes;
- columnas excluidas de los schemas y serializers públicos;
- acceso a las columnas limitado a la API, el worker de recuperación y un
  grupo administrativo explícito;
- TLS para conexiones a Postgres y cifrado de volumen/backups cuando lo provea
  la infraestructura, aunque estos controles no reemplazan el cifrado a nivel
  aplicación;
- datos reales prohibidos en ambientes no productivos, fixtures y dumps de
  desarrollo;
- conservación del PAN después de alcanzar un estado terminal; no se
  implementa borrado automático en esta etapa;
- política de retención y acceso para backups, que también pueden contener el
  PAN hasta su vencimiento;
- auditoría de consultas administrativas y accesos a la base productiva.

El futuro subsistema de tarjetas podrá reemplazar estas columnas por un token o
una referencia opaca, y agregar cifrado/tokenización apropiados, sin cambiar la
máquina de estados de pagos.

## 8. Trabajo durable de recuperación

Para la primera versión, Postgres puede funcionar como cola durable. No es
necesario incorporar Kafka o RabbitMQ.

Tabla conceptual:

```text
processor_jobs
────────────────────────────────────────
id                      BIGINT PK
transaction_id          BIGINT FK
operation_type          AUTHORIZE | REVERSE
state                   READY | PROCESSING | RETRY | COMPLETED | MANUAL_REVIEW
result                  nullable; p. ej. REVERSED_CONFIRMED
attempt_count
next_attempt_at
worker_id
claim_token             UUID
processing_started_at
original_stan
original_ticket
reversal_stan
last_error_code
last_error_detail_sanitized
created_at
updated_at
completed_at
```

Restricciones recomendadas:

```text
UNIQUE(transaction_id, operation_type)
UNIQUE(transaction_id, reversal_stan)
```

El `reversal_stan` se genera una sola vez y se reutiliza en todos los
reintentos. No se debe crear un reverso nuevo por intento. Es la identidad
estable del trabajo de orquestación; en el contrato legacy caracterizado por
RA-00 no reemplaza al STAN original en DE11, porque hacerlo impediría la
coincidencia con la venta.

### 8.1 Reclamo concurrente

Varias réplicas pueden procesar trabajos mediante:

```sql
SELECT ...
FROM processor_jobs
WHERE state IN ('READY', 'RETRY')
  AND next_attempt_at <= now()
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

Dentro de la misma transacción del reclamo, el worker actualiza:

```text
state                 = PROCESSING
worker_id             = <identificador de instancia>
claim_token           = <UUID nuevo>
processing_started_at = now()
```

La transacción SQL se confirma antes de hacer la llamada de red. Un job en
`PROCESSING` nunca vuelve automáticamente a `READY` o `RETRY`: si el worker
muere o supera `processing_timeout_seconds`, un monitor lo mueve a
`MANUAL_REVIEW` y emite una alerta. Esta decisión evita un segundo `0400`
cuando no puede probarse si el primero fue enviado.

Al completar la llamada, el worker solo puede persistir el resultado mediante
una actualización condicional:

```sql
UPDATE processor_jobs
SET ...
WHERE id = :job_id
  AND state = 'PROCESSING'
  AND claim_token = :claim_token;
```

Si ninguna fila es modificada, el job ya fue movido a revisión manual. La
respuesta tardía se registra como evento sanitizado para investigación, pero
no puede sobrescribir `MANUAL_REVIEW` ni cambiar el estado público.

### 8.2 Reintentos

- backoff exponencial con jitter únicamente cuando existe certeza de que el
  reverso no fue enviado;
- cantidad máxima de intentos configurable, sin pérdida del trabajo;
- alerta al superar un umbral de intentos;
- transición inmediata a `MANUAL_REVIEW` ante una respuesta ambigua después
  de iniciar el envío, errores permanentes, inconsistencias o abandono;
- cada intento se registra en `transaction_status_events` sin datos sensibles.

`attempt_count` cuenta ejecuciones reales del reverso, incluida la primera. La
configuración se expresa como `max_reversal_attempts`; por ejemplo, `5`
significa un intento inicial y hasta cuatro reintentos.

Cuando `attempt_count` alcanza el máximo sin confirmación:

- el job pasa a `MANUAL_REVIEW` y no se elimina;
- `transactions.status` permanece en `PENDING`;
- la API proyecta `reason = UNDER_REVIEW`, deja de indicar polling y permite
  iniciar otra venta independiente;
- se genera una alerta operativa;
- un operador solo puede devolver el job a `RETRY` después de demostrar que el
  último `0400` no fue enviado; aumentar la configuración no lo reactiva.

### 8.3 Configuración persistida

La API actualmente utiliza `Settings` basados en variables de entorno y no
tiene una tabla de configuración persistida. Se agregará una tabla tipada para
las políticas de autorización y recuperación:

```text
payment_processing_config
────────────────────────────────────────
id                              BIGINT IDENTITY PK
config_name                     VARCHAR UNIQUE
max_authorization_attempts      INTEGER
authorization_initial_delay_ms  INTEGER
authorization_max_delay_ms      INTEGER
authorization_backoff_multiplier NUMERIC
max_reversal_attempts           INTEGER
reversal_initial_delay_seconds  INTEGER
reversal_max_delay_seconds      INTEGER
reversal_backoff_multiplier     NUMERIC
jitter_percentage               INTEGER
processing_timeout_seconds      INTEGER
worker_poll_interval_seconds    NUMERIC
created_at
updated_at
```

La migración crea la fila `default` con valores iniciales explícitos. Todas las
restricciones se validan en base y aplicación:

```text
max_authorization_attempts >= 1
authorization_initial_delay_ms >= 0
authorization_max_delay_ms >= authorization_initial_delay_ms
authorization_backoff_multiplier >= 1
max_reversal_attempts >= 1
reversal_initial_delay_seconds >= 0
reversal_max_delay_seconds >= reversal_initial_delay_seconds
reversal_backoff_multiplier >= 1
jitter_percentage BETWEEN 0 AND 100
processing_timeout_seconds > 0
worker_poll_interval_seconds > 0
```

Los valores iniciales acordados para esa fila son:

| Campo | Valor |
|---|---:|
| `max_authorization_attempts` | `3` |
| `authorization_initial_delay_ms` | `100` |
| `authorization_max_delay_ms` | `500` |
| `authorization_backoff_multiplier` | `2` |
| `max_reversal_attempts` | `5` |
| `reversal_initial_delay_seconds` | `5` |
| `reversal_max_delay_seconds` | `300` |
| `reversal_backoff_multiplier` | `2` |
| `jitter_percentage` | `20` |
| `processing_timeout_seconds` | `60` |
| `worker_poll_interval_seconds` | `1` |

La API consulta la configuración `default` al comenzar una autorización y usa
ese snapshot durante sus intentos síncronos. Los cambios aplican a nuevas
autorizaciones sin reiniciar el proceso. El worker consulta la fila al
programar cada reverso; los cambios aplican a jobs en `READY` o `RETRY`.
Los jobs que ya alcanzaron `MANUAL_REVIEW` no se reactivan automáticamente:
requieren una acción operativa explícita para evitar reenvíos inesperados.

Las demoras se calculan conceptualmente como:

```text
authorization_delay_ms = min(
  authorization_max_delay_ms,
  authorization_initial_delay_ms
    * authorization_backoff_multiplier^(authorization_attempt_count - 1)
) + jitter

reversal_delay_seconds = min(
  reversal_max_delay_seconds,
  reversal_initial_delay_seconds * reversal_backoff_multiplier^(attempt_count - 1)
) + jitter
```

Cada transición registra los valores efectivos de configuración o su versión
en `transaction_status_events` para poder reconstruir por qué se programó un
intento.

### 8.4 Worker embebido en FastAPI

No se desplegará un servicio o proceso independiente. Cada proceso de FastAPI
inicia una instancia del worker mediante el lifespan de la aplicación y la
detiene durante el shutdown.

Como el stack actual de Postgres y HTTP es síncrono, el loop del worker debe
correr en un hilo dedicado para no bloquear el event loop de FastAPI. El ciclo
conceptual es:

```text
FastAPI startup
  └── iniciar worker thread
        └── reclamar job → ejecutar → persistir → esperar poll interval

FastAPI shutdown
  └── dejar de reclamar jobs
      └── esperar el trabajo actual hasta el grace period
          └── si queda abandonado, el monitor lo envía a MANUAL_REVIEW
```

Cada réplica de FastAPI y cada proceso de Uvicorn inicia su propio worker. La
coordinación inicial depende de `FOR UPDATE SKIP LOCKED`. Una vez confirmado el
reclamo, el job queda en `PROCESSING` y ninguna otra réplica puede tomarlo. El
`claim_token` impide que un worker tardío sobrescriba una decisión posterior;
no se usan locks en memoria ni leases.

Requisitos operativos:

- una sesión de base independiente por iteración/job;
- señal de parada compartida para shutdown ordenado;
- no reclamar trabajos nuevos después de recibir shutdown;
- excepción no controlada del loop no puede dejar al worker silenciosamente
  muerto: debe afectar readiness o terminar el proceso para que el orquestador
  lo reinicie;
- health/readiness debe exponer que el loop está vivo y cuándo completó su
  última iteración;
- `--reload` se limita a desarrollo; en producción cada proceso iniciado se
  considera una réplica válida con su worker.

### 8.5 Alerta y resolución manual

Toda transición a `MANUAL_REVIEW` crea una alerta durable para casa central y
la envía al canal operativo configurado. La alerta debe contener
`transaction_number`, job, comercio, terminal, importe, timestamps, cantidad
de intentos y código de error sanitizado; nunca PAN completo ni vencimiento.
La métrica o notificación por sí sola no reemplaza el registro durable.

Por el momento, casa central consulta la evidencia mediante acceso SQL
operativo de solo lectura; no se expone una herramienta administrativa ni
roles de API. Ese acceso debe aplicar mínimo privilegio y las consultas de
operación no deben seleccionar PAN completo ni vencimiento. Una futura
herramienta autenticada deberá reemplazar este procedimiento antes de habilitar
resoluciones o reintentos desde la aplicación.

Cuando se implemente esa herramienta futura, deberá permitir cerrar el caso
mediante una acción autenticada y auditada:

- impacto neutralizado → job `COMPLETED`, resultado `REVERSED_CONFIRMED`,
  estado público `FAILED`;
- rechazo original confirmado → job `COMPLETED`, resultado
  `PROCESSOR_DECLINED`, estado público `DECLINED`;
- venta activa confirmada → job `COMPLETED`, resultado
  `ACTIVE_APPROVAL_CONFIRMED`, estado público `APPROVED`;
- evidencia insuficiente → conservar `MANUAL_REVIEW` y
  `PENDING / UNDER_REVIEW`.

La futura resolución registrará operador, fecha, evidencia/referencia externa
y motivo. El reintento manual seguirá siendo una acción separada y solo se
habilitará si el operador documenta por qué es seguro hacerlo.

## 9. Recuperación ante caídas

| Momento de la caída | Recuperación |
|---|---|
| Antes de crear `PENDING` | No existe efecto externo; el cliente repite con la misma clave |
| Después de guardar `PENDING`, antes del envío | El watchdog detecta la operación envejecida y la procesa |
| Durante el envío de la venta | Se considera ambiguo y se crea/reclama el reverso |
| Después de recibir aprobación, antes de persistirla | Se considera ambiguo y se reversa de forma conservadora |
| Antes de reclamar el reverso | Un worker reclama el job `READY` mediante `SKIP LOCKED` |
| Después de reclamar, antes de poder demostrar el envío | Si el job queda envejecido, pasa a revisión manual; no se reasigna automáticamente |
| Después de enviar el reverso, antes de persistir la respuesta | Pasa a revisión manual; no se reenvía automáticamente |
| Durante una indisponibilidad concluyente anterior al envío | Se mantiene en retry y eventualmente pasa a revisión manual al agotar intentos |
| Durante una indisponibilidad de resultado ambiguo | Pasa inmediatamente a revisión manual |

Un watchdog debe buscar periódicamente:

- transacciones `PENDING` con antigüedad superior al timeout máximo;
- trabajos `PROCESSING` cuyo `processing_started_at` superó
  `processing_timeout_seconds`, para moverlos una sola vez a `MANUAL_REVIEW`;
- recuperaciones que superaron el SLA esperado.

## 10. Idempotencia y límite de la garantía

Postgres permite garantizar que el trabajo no se pierde, pero no puede hacer
atómica una escritura local con un efecto en el procesador externo.

Ejemplo inevitable:

```text
worker envía 0400
procesador lo aplica
se pierde la respuesta
worker o instancia muere antes de persistir el resultado
```

En la primera versión, el siguiente worker **no** reenvía el `0400`: el job
pasa a `MANUAL_REVIEW`, la API proyecta `PENDING / UNDER_REVIEW` y casa central
investiga. Se prioriza evitar una segunda compensación automática frente a la
disponibilidad de la recuperación.

Para poder recuperar automáticamente ese caso en una versión posterior, el
procesador debe implementar al menos una de estas opciones:

1. idempotencia real del reverso mediante una clave estable;
2. consulta del estado de una operación;
3. restricción única que impida aplicar dos veces la misma operación;
4. tombstone de reverso que impida que una venta tardía se aplique después de
   un reverso anticipado.

Por lo tanto, la primera versión no promete entrega **al menos una vez** ante
un resultado ambiguo del reverso: promete persistencia del caso, alarma y
derivación segura a revisión manual. El efecto económico exactamente una vez y
el reenvío automático dependen de idempotencia o consulta en el procesador.

## 11. Validación del procesador legacy (RA-00)

La validación del 2026-10-12 contra el stack local confirmó estas condiciones
(tramas y reproducción en
[`payment-gateway/docs/legacy-reversal-contract.md`](../payment-gateway/docs/legacy-reversal-contract.md)):

1. El reverso busca la venta mediante una coincidencia estricta de comercio,
   vencimiento, importe, STAN, terminal, ticket, producto, PAN y lote.
2. El mensaje debe reproducir los identificadores originales; no debe generar
   un nuevo STAN de venta.
3. El procesador inserta un registro `0400` aun cuando no encuentra la venta
   original y responde `00`.
4. El `UPDATE` de la venta original no verifica cuántas filas modificó.
5. Si el reverso llega primero, responde `00`, pero un `0200` posterior también
   se aprueba y queda activo.
6. Repetir exactamente el mismo `0400` vuelve a responder `00` y agrega otra
   fila; no es idempotente en persistencia.

La matriz observada es:

| Caso | DE39 | Garantía disponible |
|---|---:|---|
| Original existente | `00` | No distinguible por respuesta |
| Original inexistente | `00` | No distinguible por respuesta |
| Reverso duplicado | `00` | Agrega otra fila `0400` |
| Reverso antes de la venta | `00` | No bloquea el `0200` posterior |

La diferencia entre una venta encontrada y una inexistente no tiene efecto
económico: `calcula_consumo_vivo()` solo computa filas `0200`, y los reportes y
el cierre excluyen `0400`. El contrato operativo fija además que el reverso se
genera únicamente para un `0200` previamente enviado. Por eso el gateway
acepta `0410/00` como `REVERSED_CONFIRMED`; una respuesta inválida o un fallo
de transporte posterior al envío siguen siendo `INDETERMINATE`.

## 12. Contratos propuestos

### 12.1 Gateway

Agregar una primitiva interna:

```text
POST /v1/reverse
```

Solicitud conceptual:

```json
{
  "product_code": "...",
  "amount_minor": 100,
  "card_number": "...",
  "expiration_date": "YYMM",
  "terminal_id": "05000001",
  "original_stan": "123456",
  "original_ticket": "123456",
  "reversal_stan": "654321"
}
```

Resultado deseado:

```text
REVERSED_CONFIRMED
DECLINED
NOT_SENT
UNKNOWN
```

RA-00 comprobó que `0410/00` es la respuesta estable del procesador. El
gateway la mapea a `REVERSED_CONFIRMED` según el contrato operativo aceptado.
Solo una respuesta rota o un fallo ambiguo de transporte produce
`UNKNOWN`/`INDETERMINATE`.

### 12.2 API pública

El endpoint actual de creación conserva el camino síncrono. Puede responder:

```text
201 APPROVED | DECLINED | FAILED
202 PENDING
```

Agregar consulta individual:

```text
GET /v1/transactions/{transaction_number}
```

La respuesta pública incluye uno de los cuatro estados definidos. Los detalles
internos de recuperación no se exponen a mobile. Para `PENDING`, la API agrega
instrucciones explícitas de presentación y continuidad operativa.

El mismo `Idempotency-Key` siempre devuelve la operación existente. Una venta
independiente usa una clave nueva y puede crearse aunque otra operación esté
pendiente o en revisión.

Ejemplo temporal:

```http
HTTP/1.1 202 Accepted
Location: /v1/transactions/20261012-000001
Retry-After: 2
```

```json
{
  "transaction_number": "20261012-000001",
  "status": "PENDING",
  "reason": "PROCESSING",
  "user_message": "La operación se está procesando.",
  "poll_after_seconds": 2,
  "may_start_new_sale": false
}
```

Ejemplo cuando la recuperación requiere intervención de casa central:

```http
HTTP/1.1 202 Accepted
Location: /v1/transactions/20261012-000001
```

```json
{
  "transaction_number": "20261012-000001",
  "status": "PENDING",
  "reason": "UNDER_REVIEW",
  "user_message": "No fue posible confirmar el resultado. Verifique la operación con casa central ante un posible cobro duplicado.",
  "poll_after_seconds": null,
  "may_start_new_sale": true
}
```

`UNDER_REVIEW` no afirma que la venta falló ni que el cobro fue neutralizado.
Es una proyección pública de `processor_jobs.state = MANUAL_REVIEW`; conserva
la operación consultable y libera el flujo de venta de la terminal.

Ejemplo final después de un reverso confirmado:

```json
{
  "transaction_number": "20261012-000001",
  "status": "FAILED",
  "reason": "REVERSED_AFTER_UNCERTAIN_AUTHORIZATION",
  "user_message": "La operación no pudo realizarse."
}
```

### 12.3 Idempotencia, duplicados y concurrencia

La terminal genera la `Idempotency-Key` antes del primer request y la conserva
hasta recibir un estado final.

Para la misma clave y el mismo fingerprint:

| Estado persistido | Respuesta de la API |
|---|---|
| `PENDING` | Devuelve la misma operación con HTTP `202`; no vuelve a autorizar |
| `APPROVED` | Devuelve nuevamente `APPROVED` |
| `DECLINED` | Devuelve nuevamente `DECLINED` |
| `FAILED` | Devuelve nuevamente `FAILED` |

La misma clave con datos diferentes devuelve `409 Conflict` y no procesa nada.
La restricción única de idempotencia en Postgres determina cuál request crea la
operación cuando llegan dos simultáneamente; el perdedor carga y devuelve la
fila existente.

Una desconexión HTTP no cancela el procesamiento. Si se pierde la respuesta,
mobile reenvía el mismo `POST` con la misma clave. La API devuelve `PENDING` o
el resultado final ya alcanzado. Repetir el mismo request no es una venta
nueva.

Se distinguen dos acciones que no deben compartir la misma semántica ni el
mismo botón:

- **reintento técnico:** reenvía o consulta la misma operación con la misma
  `Idempotency-Key`; puede hacerse automáticamente mientras está
  `PENDING / PROCESSING`;
- **nueva venta independiente:** crea otra operación con una nueva clave. Se
  habilita al recibir un estado final o `PENDING / UNDER_REVIEW`; no modifica,
  reemplaza ni reenvía la operación anterior.

La API no rechaza una clave nueva solo porque la misma terminal, tarjeta o
usuario tenga una operación pendiente. El riesgo comercial de un posible
doble impacto se comunica en el comprobante y se gestiona mediante casa
central. Sí debe impedirse que dos requests con la misma clave creen dos
autorizaciones.

## 13. Comportamiento de mobile

### Resultado normal

La terminal recibe `APPROVED`, `DECLINED` o `FAILED` en la petición original y
continúa como hasta ahora, sin polling.

### Operación pendiente

Ante `202 PENDING`:

1. si `reason = PROCESSING`, mostrar la operación en proceso y consultar
   `GET /transactions/{transaction_number}` después de
   `poll_after_seconds`;
2. no crear otra operación mientras `may_start_new_sale = false`;
3. detener el polling al llegar a un estado final, al superar el tiempo de UI
   o al recibir `reason = UNDER_REVIEW`;
4. si `reason = UNDER_REVIEW`, imprimir el comprobante de verificación y
   habilitar inmediatamente una venta independiente;
5. permitir volver al historial sin cancelar la recuperación del backend;
6. mostrar el estado actualizado al reabrir la operación;
7. persistir localmente `transaction_number` e `Idempotency-Key` para que la
   operación original siga siendo consultable aunque se creen otras ventas.

La UI solo interpreta los cuatro estados públicos. El repositorio HTTP se
encarga de `202`, timeouts, reconexión, polling y reenvío de la misma clave. Un
reintento técnico conserva la operación; una venta independiente usa una clave
nueva y no resuelve ni cancela la anterior.

### Comprobante de operación en revisión

Cuando recibe `PENDING / UNDER_REVIEW`, mobile imprime o permite entregar un
comprobante que no se presenta como venta aprobada ni como rechazo. Debe
incluir como mínimo:

- leyenda visible **Operación pendiente de verificación**;
- `transaction_number` como referencia para casa central;
- fecha, hora, comercio, terminal e importe;
- PAN enmascarado, nunca el PAN completo;
- texto que indique que no fue posible confirmar el resultado;
- advertencia de verificar con casa central ante un posible cobro duplicado;
- aclaración de que el comercio puede continuar operando.

Texto sugerido:

> No fue posible confirmar el resultado de esta operación. Puede continuar
> operando. Ante un posible cobro duplicado, verifique con casa central
> indicando el número de operación.

No se propone WebSocket para la primera versión. El polling solo ocurre
mientras la API indique `PENDING / PROCESSING`; `UNDER_REVIEW` permanece
consultable, pero no genera polling automático indefinido.

## 14. Cierre de lote

El cierre de lote debe rechazarse si existen operaciones del lote actual con:

- `PENDING`;
- `authorization_outcome = INDETERMINATE`;
- jobs de reverso en `READY`, `PROCESSING` o `RETRY`.

Un job en `MANUAL_REVIEW` también debe bloquear el cierre, salvo que en el
futuro se diseñe un procedimiento administrativo explícito para exceptuarlo.

## 15. Política de timeouts

El timeout del cliente debe ser mayor que el presupuesto síncrono de la API.
Ese presupuesto incluye todos los intentos seguros de autorización y sus
delays. El reverso se ejecuta fuera del request HTTP y no extiende el tiempo de
espera de la terminal.

Ejemplo inicial sujeto a pruebas:

```text
intento autorización:        10 s
máximo intentos autorización: 2
delay entre intentos:          0,5 s inicial
presupuesto API:              25 s
timeout mobile:               35 s
reverso por worker:           independiente del request
```

La configuración y los timeouts de infraestructura deben validarse para que el
peor caso de intentos de autorización quepa dentro del presupuesto de API y
este, a su vez, sea menor que el timeout mobile. Un resultado ambiguo corta el
loop inmediatamente, aunque todavía queden intentos configurados.

`processing_timeout_seconds` debe ser mayor que el timeout máximo de la llamada
de reverso más un margen operativo. No habilita un reintento: únicamente
determina cuándo un job `PROCESSING` abandonado debe pasar a
`MANUAL_REVIEW`.

Ante un resultado ambiguo, la API persiste el trabajo y responde `202 PENDING`
sin esperar el reverso. Si la propia llamada HTTP se corta, la terminal reenvía
la misma `Idempotency-Key`: recibirá `PENDING` o el final que el worker ya haya
alcanzado.

## 16. Pruebas de aceptación

Como mínimo deben cubrirse:

1. fallo de validación: no se crea reverso;
2. conexión rechazada antes del envío: reintento seguro, sin reverso;
3. venta aprobada con respuesta normal;
4. venta rechazada con respuesta normal;
5. venta aplicada y respuesta perdida: reverso eventual;
6. mensaje nunca recibido pero resultado ambiguo: reverso seguro/no-op;
7. caída de la API antes de enviar la venta;
8. caída de la API después de enviar la venta;
9. caída del worker después de enviar el reverso y antes de guardar su
   respuesta;
10. pérdida de respuesta del reverso: transición a `MANUAL_REVIEW` sin reenvío
    automático;
11. reverso que llega antes de finalizar la venta original;
12. dos workers intentando reclamar el mismo trabajo;
13. un job `PROCESSING` envejecido pasa a `MANUAL_REVIEW` sin ser reclamado ni
    reenviado por otro worker;
14. idempotencia del endpoint público;
15. bloqueo de cierre de lote con recuperaciones abiertas;
16. PAN ausente de logs, eventos y respuestas;
17. persistencia del PAN después de alcanzar estados finales y después de
    reiniciar API/worker;
18. polling mobile únicamente ante `202 PENDING` con `reason = PROCESSING`;
19. dos requests simultáneos con la misma clave producen una sola autorización;
20. misma clave y distinto fingerprint devuelve `409`;
21. una segunda clave de la misma terminal puede crear una venta independiente
    cuando la anterior está `PENDING / UNDER_REVIEW`;
22. pérdida de la respuesta HTTP seguida por reenvío de la misma clave;
23. `FAILED` solo se emite antes del envío confirmado o después de un reverso
    confirmado;
24. `APPROVED`, `DECLINED` y `FAILED` no admiten transiciones posteriores;
25. después de crear el trabajo durable, la API no envía el reverso;
26. el worker es el único dueño del envío y dos workers no procesan
    simultáneamente el mismo trabajo;
27. la API responde `202 PENDING` sin esperar que finalice el reverso;
28. no existe una columna `transactions.recovery_status`; el estado del job es
    la única fuente de verdad de la recuperación;
29. el worker respeta `max_reversal_attempts` contando el primer intento;
30. al agotar los intentos, el job pasa a `MANUAL_REVIEW`, la transacción sigue
    `PENDING` y se emite una alerta;
31. modificar la configuración afecta jobs `READY`/`RETRY` sin reiniciar el
    worker;
32. aumentar el máximo no reactiva automáticamente jobs en `MANUAL_REVIEW`;
33. la migración crea y valida la configuración `default`;
34. `NOT_SENT` reintenta la autorización hasta `max_authorization_attempts`;
35. una aprobación o rechazo detiene inmediatamente los reintentos;
36. un resultado `INDETERMINATE` no reintenta el `0200` y crea un solo job de
    reverso;
37. agotar intentos de autorización con resultados `NOT_SENT` publica `FAILED`
    sin crear reverso;
38. modificar la política de autorización aplica a operaciones nuevas sin
    reiniciar FastAPI;
39. el lifespan inicia exactamente un worker por proceso de FastAPI y lo
    detiene ordenadamente;
40. una excepción fatal del loop afecta readiness o termina el proceso;
41. varias réplicas FastAPI con workers embebidos no ejecutan simultáneamente
    el mismo job;
42. un fallo concluyente anterior al envío del `0400` puede pasar a `RETRY`;
43. una respuesta ambigua después de iniciar el `0400` pasa inmediatamente a
    `MANUAL_REVIEW` y no se reenvía automáticamente;
44. una actualización tardía con un `claim_token` que ya no está vigente no sobrescribe
    `MANUAL_REVIEW` y queda registrada como evento;
45. `PENDING / UNDER_REVIEW` devuelve `poll_after_seconds = null` y
    `may_start_new_sale = true`;
46. mobile detiene el polling, imprime el comprobante de verificación y permite
    una nueva venta con otra clave al recibir `UNDER_REVIEW`;
47. la venta nueva no modifica ni reenvía la operación que quedó en revisión;
48. el comprobante contiene una referencia para casa central y nunca expone el
    PAN completo.

## 17. Implementación incremental

### Fase 1 — Contrato y evidencia del legacy

- construir y probar el mensaje `0400` exacto;
- validar respuesta cuando la venta existe y cuando no existe;
- reproducir la carrera reverso-antes-de-venta;
- determinar la clave idempotente real del procesador;
- definir si hace falta una corrección acotada del legacy.

### Fase 2 — Persistencia y gateway

- agregar PAN/vencimiento en texto plano, sin política automática de borrado;
- agregar `transactions.authorization_outcome`;
- agregar `processor_jobs`;
- crear `payment_processing_config` con su fila `default`, constraints y
  repositorio;
- implementar `POST /v1/reverse` en el gateway;
- registrar eventos sanitizados.

### Fase 3 — Recuperación API

- mantener autorización síncrona;
- implementar reintentos síncronos solo para resultados `NOT_SENT`, usando la
  política de `payment_processing_config`;
- crear el trabajo durable ante ambigüedad;
- responder `202 PENDING` después de persistir el trabajo;
- implementar el worker como único ejecutor de reversos, con reclamo mediante
  `SKIP LOCKED`, `claim_token`, monitor de jobs envejecidos y backoff solo para
  fallos concluyentes anteriores al envío;
- iniciar y detener el worker en el lifespan de FastAPI, usando un hilo
  dedicado y health/readiness;
- cargar la política de reintentos desde `payment_processing_config` en cada
  programación;
- agregar consulta individual de transacción;
- proyectar los estados internos al contrato público de cuatro estados;
- proyectar `MANUAL_REVIEW` como `PENDING / UNDER_REVIEW`, sin polling
  automático y con nuevas ventas permitidas;
- bloquear el cierre de lote cuando corresponda.

### Fase 4 — Mobile y operación

- manejar `202 PENDING`;
- agregar pantalla/polling de recuperación;
- persistir localmente las operaciones pendientes y sus `Idempotency-Key`;
- imprimir el comprobante de operación en revisión;
- permitir una venta independiente con nueva clave después de
  `PENDING / UNDER_REVIEW`;
- agregar alertas y procedimiento de revisión manual.

### Fase futura — Subsistema de tarjetas

- mover PAN, cifrado/tokenización y acceso a un componente especializado;
- reemplazar el PAN persistido en la API por tokens opacos;
- reducir el alcance PCI de API, gateway y observabilidad;
- conservar sin cambios sustanciales la orquestación de pagos y reversos.

## 18. Decisiones abiertas

- ¿Qué combinación exacta de campos identifica idempotentemente un `0400` en
  el procesador?
- ¿Puede el legacy distinguir “venta encontrada y revertida” de “venta no
  encontrada”?
- ¿El procesador debe registrar un tombstone para una venta que todavía no
  existe?
- ¿Qué política de retención y purga se adoptará en una etapa futura?
- ¿Cuál será el SLA de alerta operativo para recuperaciones demoradas?
- ¿Cómo se reconcilian operaciones que permanezcan abiertas al cierre del día?

## 19. Criterio de finalización

El diseño se considera implementado cuando:

- una caída de cualquier instancia no pierde la intención de autorización ni
  el trabajo de recuperación;
- una operación ambigua nunca se presenta falsamente como `FAILED`;
- la terminal solo conoce `PENDING`, `APPROVED`, `DECLINED` y `FAILED`;
- `FAILED` solo se publica cuando es seguro iniciar una venta independiente;
- requests duplicados devuelven la operación existente sin reenviar la venta;
- `PENDING / UNDER_REVIEW` entrega una referencia para casa central, detiene el
  polling y permite crear otra venta independiente con una clave nueva;
- la autorización reintenta solo fallos `NOT_SENT` y respeta la configuración
  persistida;
- un resultado ambiguo nunca reenvía la autorización original;
- cada proceso FastAPI mantiene su worker embebido y observable;
- varios workers reclaman jobs `READY`/`RETRY` sin colisionar;
- un job `PROCESSING` abandonado pasa a `MANUAL_REVIEW` y nunca se recupera o
  reenvía automáticamente;
- un `claim_token` impide que respuestas tardías sobrescriban la revisión
  manual;
- el reverso es idempotente o consultable en el procesador;
- el lote no se cierra con operaciones sin resolver;
- el PAN permanece persistido, aislado de contratos y logs, con acceso
  restringido y sin borrado automático en esta etapa;
- la terminal usa el camino síncrono normal y solo hace polling mientras la API
  indique `PENDING / PROCESSING`.
