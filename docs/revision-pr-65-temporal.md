# Revisión temporal del PR #65

> Documento temporal de análisis. No reemplaza `docs/alcance.md` ni
> `docs/gaps.md`. Debe eliminarse o consolidarse en la documentación oficial
> cuando se implementen las mejoras propuestas.

## Problema que el PR intenta solucionar

Cuando una venta no obtiene una respuesta concluyente, la aplicación puede
quedar esperando indefinidamente en la pantalla de procesamiento. Si el
operador abandona esa pantalla, la venta continúa registrada como `PENDING`,
pero la terminal puede perder el seguimiento visible de la operación.

Esta situación produce varios riesgos relacionados:

- el operador no sabe si la venta fue aplicada, rechazada o quedó sin respuesta;
- un reintento con una clave nueva podría generar un segundo cobro;
- puede confundirse el reintento de la misma venta con el inicio legítimo de
  una venta independiente;
- el cierre de lote se bloquea mientras existan operaciones ambiguas;
- una venta `PENDING` que quedó persistida antes de finalizar la llamada al
  autorizador puede no tener todavía un job de reverso que la recupere;
- aun después de confirmar el reverso, el cierre podía continuar bloqueado por
  conservar el outcome histórico `INDETERMINATE` de la autorización original.

El objetivo funcional es que la terminal deje de esperar después de un tiempo
razonable sin inventar un resultado, que la recuperación continúe de manera
durable en el backend y que el lote pueda cerrarse cuando la operación ya no
pueda cambiar.

## Decisión funcional acordada

Una transacción en curso no debe impedir que la terminal comience otra venta
independiente. El backend puede recuperar varias operaciones en paralelo y cada
venta tiene su propio número, STAN, ticket e `Idempotency-Key`.

La política deseada distingue tres acciones:

- **reintentar la misma venta:** reutilizar siempre la misma
  `Idempotency-Key`, para que una respuesta HTTP perdida no produzca otro cobro;
- **iniciar una venta independiente:** permitirla después de entregar la venta
  anterior al seguimiento durable del backend, generando una clave nueva;
- **cerrar el lote:** bloquearlo mientras alguna venta o anulación todavía
  pueda cambiar de resultado.

La terminal debe seguir mostrando la operación pendiente en el historial y
advertir, al vencer la espera, que no se vuelva a cobrar la misma venta. No se
requieren confirmaciones, banners persistentes ni nuevos campos de contrato.

## Cómo intentaba solucionarlo el PR original

### Reintento idempotente del envío

Si el primer `POST` de la venta termina con un error de conexión, Mobile hace
un único reintento automático usando la misma `Idempotency-Key`. De esta forma,
si la primera solicitud llegó a la API pero se perdió la respuesta, el segundo
envío recupera la misma operación en lugar de crear otra.

### Polling sin reenviar el cobro

Cuando la API responde `202 PENDING`, Mobile conserva el número de operación y
consulta su estado mediante `GET`. El `POST` de autorización no se repite
durante este seguimiento.

### Fin de la espera visible

La espera automática de Mobile se limita a 30 segundos. La versión original del
PR también permitía seleccionar **Dejar de esperar**, aunque la decisión
acordada es no permitir una salida manual de la operación en curso. Sólo el
resultado o el timeout deben abandonar la pantalla de procesamiento.

Al vencer el timeout, la venta permanece sin confirmar y no se la presenta como
rechazada. La pantalla de resultado existente debe mostrar:

> **Transacción en proceso**  
> La operación `OP-...` sigue pendiente. No repita esta misma venta. Puede
> consultar su resultado en el historial e iniciar una venta diferente.

### Bloqueo original de una nueva venta en Mobile

Mientras el estado actual del `SalesCubit` representa una autorización
`PENDING` que todavía puede cambiar y `may_start_new_sale` es `false`, el
formulario de venta se deshabilita.

Este comportamiento forma parte de la implementación del PR, pero diverge de
la decisión funcional acordada: evita tanto un reintento accidental como una
venta nueva e independiente.

### Recuperación de ventas `PENDING` sin job

Antes de reclamar el siguiente job de reverso, `ReversalJobWorker` busca ventas
`PENDING` antiguas cuyo outcome continúa en `PENDING`, que tienen STAN y ticket,
y que aún no poseen un job de reverso. Para cada candidata crea el trabajo
durable de recuperación y luego puede procesarlo.

### Cierre de lote después de un reverso confirmado

El cierre continúa bloqueándose cuando la venta tiene estado público `PENDING`
o `UNKNOWN`, cuando existe un job de reverso abierto o cuando existe una
anulación abierta. Sin embargo, permite incluir una venta `FAILED` cuyo reverso
ya terminó, aunque su `authorization_outcome` conserve el valor histórico
`INDETERMINATE`.

### Tratamiento del rechazo de cierre

Mobile distingue el `409` de cierre de lote de un error de conectividad y
muestra el mensaje de negocio enviado por la API.

## Resultado aplicado para ventas independientes

El ajuste del 2026-11-10 resolvió las divergencias de Mobile de este ítem:

1. se eliminó `blocksNewSale` y sus guards del formulario, ingreso manual y MSR;
2. una operación que alcanza el timeout puede cerrar su handoff visible y queda
   en el historial mientras una venta independiente genera otra clave;
3. se retiró **Dejar de esperar**;
4. `PopScope(canPop: false)` bloquea el back de Android y la pantalla de
   procesamiento ya no ofrece el menú de usuario;
5. el timeout usa la pantalla de resultado existente con el mensaje de no
   repetir la misma venta y de consultarla en el historial;
6. `may_start_new_sale` se conserva por compatibilidad, pero ya no condiciona el
   formulario;
7. los tests ahora cubren la clave nueva, la conservación del historial, la
   ausencia de salida manual y el mensaje de timeout.

Permanece fuera de este ítem la carrera entre una autorización todavía activa y
el watchdog de reversos, detallada más abajo.

## Mejora: permitir ventas independientes y bloquear sólo duplicados

**Estado: aplicada el 2026-11-10.**

### Problema

El PR original usaba `blocksNewSale` para deshabilitar el formulario y agregaba guards en la
selección de producto, la preparación manual y la preparación MSR. Mientras la
operación anterior siga en `PENDING / PROCESSING`, no permite comenzar otra
venta.

Ese bloqueo es demasiado amplio. Resuelve el riesgo de volver a cobrar
accidentalmente la misma operación, pero también impide atender a otro cliente
con una venta que debe tener identidad propia.

Además, el comportamiento es inconsistente: el bloqueo vive en memoria y se
pierde al abrir el historial, reiniciar la aplicación, cerrar sesión o recrear
el cubit. Por lo tanto, no constituye una garantía durable contra duplicados y,
al mismo tiempo, restringe el uso normal mientras permanece activo.

### Solución aplicada

Separar explícitamente “continuar la misma venta” de “iniciar una venta nueva”:

1. mantener el guard contra dos invocaciones simultáneas de `sendIsoMessage()`;
2. conservar la `Idempotency-Key` mientras el operador reintenta o recupera la
   misma venta;
3. impedir abandonar manualmente la pantalla de procesamiento y esperar un
   resultado o el timeout de UI;
4. al vencer el timeout, usar la pantalla de resultado existente para informar
   que la operación sigue pendiente, que no debe repetirse y que puede verse en
   el historial;
5. al finalizar esa pantalla, mover la operación al historial y habilitar el
   formulario para otra venta independiente;
6. generar una nueva `Idempotency-Key` únicamente al preparar esa nueva venta;
7. mantener el cierre de lote bloqueado hasta que todas las operaciones abiertas
   alcancen un resultado que ya no pueda cambiar.

No se recomienda agregar una guardia backend que rechace todas las ventas nuevas
de una terminal por tener otra `PENDING`. La API debe continuar garantizando la
idempotencia por operación, pero puede aceptar varias operaciones independientes
con claves diferentes.

No hace falta agregar `may_retry_same_sale`, `may_start_independent_sale` ni
`blocks_batch_close`. Son invariantes del flujo:

- mientras se trate del mismo intento, Mobile conserva la misma
  `Idempotency-Key`;
- una venta nueva e independiente siempre genera otra clave y está permitida;
- `POST /transactions/batch-close` consulta el estado durable y devuelve `409`
  si todavía existe una operación que puede cambiar.

`may_start_new_sale` no debería utilizarse para bloquear ventas independientes.
Puede retirarse del contrato si no tiene otro consumidor o mantenerse
temporalmente por compatibilidad sin condicionar el formulario.

### Pruebas recomendadas

- dos toques sobre el envío de la misma venta producen un solo `POST`;
- un error de conexión reintenta con la misma `Idempotency-Key`;
- después del timeout, una venta diferente obtiene una clave nueva;
- antes del timeout no se puede abandonar la pantalla con navegación ni con el
  botón físico de Android;
- el resultado del timeout indica que la operación puede verse en el historial;
- la venta anterior permanece visible y consultable en el historial;
- dos ventas independientes de la misma terminal pueden estar `PENDING` sin
  compartir clave ni número de operación;
- el cierre de lote devuelve `409` mientras cualquiera de ellas pueda cambiar;
- una vez finalizadas o recuperadas ambas, el lote puede cerrarse;
- reiniciar Mobile no provoca el reenvío automático de una venta pendiente.

## Mejora: evitar un reverso concurrente con una autorización activa

**Estado: mitigada el 2026-11-10 mediante un timeout conservador.**

### Problema

La venta `PENDING` se confirma en la base antes de llamar al gateway. El nuevo
watchdog considera abandonada una operación cuando su `created_at` supera
`processing_timeout_seconds`.

Ese tiempo no demuestra que ya no exista una llamada de autorización activa.
Por ejemplo, una secuencia de intentos lentos que termina en `NOT_SENT` puede
iniciar otro intento cerca del límite configurado. Mientras ese `0200` todavía
está esperando respuesta, el worker puede seleccionar la fila, crear el job y
enviar el `0400`.

El resultado tardío del `0200` y el resultado del reverso pueden actualizar la
misma transacción en órdenes distintos. Esto puede dejar el estado público en
desacuerdo con el efecto real del procesador.

### Decisión aplicada

No se modifica el procesador legacy ni se reenvía un `0200` ambiguo. Su
deduplicación no es atómica y un reintento concurrente podría registrar dos
ventas. El `0400` tampoco deja un tombstone capaz de neutralizar una venta que
llegue después.

La API adopta una mitigación temporal y explícita:

1. `authorization_last_attempt_at` se persiste al iniciar cada intento de
   autorización;
2. `reversal_grace_seconds` queda separado del presupuesto síncrono y vale 45
   segundos por defecto, contados desde ese inicio;
3. un resultado `INDETERMINATE` crea el job durable antes de responder, pero su
   `next_attempt_at` queda después de la gracia;
4. el watchdog de requests interrumpidos mide la antigüedad desde el último
   intento, no desde la creación de la venta;
5. sólo después de vencer ese plazo el worker puede reclamar y enviar el
   `0400`.

Este timeout reduce la posibilidad de que autorización y reverso se solapen,
pero no la elimina matemáticamente: el legacy no permite cancelar o consultar
el `0200` ni garantiza un tiempo máximo de ejecución. Se acepta esa limitación
como deuda de diseño del procesador.

### Pruebas recomendadas

- un resultado ambiguo agenda el job exactamente después de la gracia;
- un segundo intento actualiza `authorization_last_attempt_at`;
- el watchdog no selecciona una venta según su `created_at` si el último intento
  es reciente;
- watchdog y request compitiendo por la misma fila en dos sesiones PostgreSQL;
- resultado `APPROVED` tardío después de crear el job, pero antes de reclamarlo;
- resultado tardío después de que el reverso quedó `PROCESSING` o `COMPLETED`;
- dos instancias del watchdog ejecutándose concurrentemente.

Las pruebas unitarias cubren el plazo y la referencia temporal. Las carreras de
locks y commits deben conservarse en la matriz PostgreSQL de recuperación.

## Mejora: separar las configuraciones de timeout

**Estado: parcialmente aplicada el 2026-11-10.**

### Problema

`processing_timeout_seconds` tiene actualmente varias responsabilidades:

- presupuesto del flujo síncrono de autorización;
- antigüedad para considerar abandonado un job de reverso `PROCESSING`;
- con este PR, antigüedad para considerar abandonada una venta `PENDING` sin
  job.

Estas duraciones no representan el mismo concepto y pueden necesitar valores
diferentes. Modificar una para resolver un problema puede volver inseguro otro
flujo.

### Recomendación

Separar al menos las siguientes configuraciones:

- `authorization_budget_seconds`: presupuesto del request síncrono;
- `stale_pending_authorization_seconds`: lease vencido de una autorización sin
  resultado ni job;
- `reversal_processing_timeout_seconds`: job de reverso reclamado que dejó de
  progresar.

Se agregó `reversal_grace_seconds` para la espera previa al `0400` y dejó de
usarse `processing_timeout_seconds` para detectar ventas `PENDING` abandonadas.
Este último todavía comparte el presupuesto síncrono y el monitoreo de jobs
`PROCESSING`, por lo que la separación completa sigue pendiente.

Cada valor debería tener validaciones cruzadas. Por ejemplo, el umbral de una
autorización abandonada debe ser mayor al peor caso del request síncrono más un
margen, y el timeout del job de reverso debe ser mayor al timeout HTTP del
gateway de reversos.

## Mejora: procesar candidatas antiguas en lotes acotados

### Problema

La consulta del watchdog no establece un límite. Una acumulación grande de
ventas antiguas puede bloquear muchas filas, cargarlas todas en memoria y crear
muchos jobs dentro de una sola transacción antes de procesar uno.

### Recomendación

- ordenar por `created_at` e `id`;
- aplicar un límite configurable por iteración;
- conservar `FOR UPDATE SKIP LOCKED`;
- confirmar el lote de jobs antes de reclamar uno;
- registrar métricas del número y antigüedad de candidatas pendientes.

Esto mantiene acotada la duración de la transacción y permite repartir el
backlog entre varias réplicas.

## Mejora: actualizar la documentación oficial

### Problema

El cambio modifica comportamiento asociado a G-P1-09 y RA-13, pero
`docs/gaps.md` todavía contiene afirmaciones incompatibles:

- en la fila principal de G-P1-09 aparece RA-13 como pendiente;
- la actualización de RA-13 dice que cualquier outcome `INDETERMINATE` bloquea
  el cierre;
- el PR permite correctamente cerrar una venta `FAILED + INDETERMINATE` cuando
  ya no existe un job abierto.

Además, la espera visible de 30 segundos, la ausencia de salida manual y la
posibilidad de continuar con una venta independiente después del timeout son
decisiones de producto. Quedaron registradas en `docs/alcance.md` y en
G-P1-02 / RA-14 de `docs/gaps.md`.

### Recomendación

En el mismo trabajo que implemente las correcciones:

1. actualizar G-P1-09 con la activación del watchdog de pendientes sin job;
2. describir la diferencia entre outcome histórico y estado recuperable actual;
3. registrar que `FAILED + INDETERMINATE` puede cerrar únicamente cuando no
   existe recuperación ni anulación abierta;
4. documentar que la idempotencia protege el reintento de la misma venta, pero
   una operación pendiente no bloquea otra venta independiente;
5. actualizar la fecha de última revisión y la evidencia de tests;
6. reflejar en `docs/alcance.md` la espera de 30 segundos y el handoff al
   historial, manteniendo el `409` para el cierre de lote;

## Mejora: completar la validación operativa

### Problema

El worker embebido permanece desactivado por defecto mediante
`EMBEDDED_RECOVERY_WORKER_ENABLED=false`. El código puede estar desplegado y,
sin embargo, las ventas antiguas sin job no se recuperarán hasta activar el
worker según el procedimiento de rollout.

### Recomendación

- mantener la activación controlada por canary;
- verificar readiness, jobs creados y ausencia de duplicados;
- ejecutar una venta controlada que quede `PENDING` sin job;
- confirmar que el watchdog crea un único reverso después del lease seguro;
- probar el cierre antes y después del resultado final;
- registrar la activación efectiva del ambiente en `docs/gaps.md`.

## Evaluación general

La rama actual conserva la idempotencia del mismo intento, evita presentar como
rechazada una venta incierta, mueve la recuperación al backend y permite otra
venta independiente después del timeout sin habilitar el cierre del lote.

El ítem de continuidad operativa y la gracia previa al reverso quedaron
aplicados. La ausencia de una garantía de finalización del `0200` permanece como
limitación aceptada del procesador legacy, no como una garantía que la API pueda
probar.

Las demás mejoras refuerzan operabilidad, escalabilidad y consistencia de la
documentación.
