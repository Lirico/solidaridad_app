# Diseño — recuperación durable de anulaciones

> Estado: propuesta de rediseño. La caracterización contra `authkig` demostró
> que un reverso de anulación no compensa su efecto en el legacy vigente. No
> autoriza envíos automáticos de `0400/020000`.
>
> Última revisión: 2026-10-22.

## 1. Problema y objetivo

Hoy `POST /v1/transactions/{transaction_number}/void` envía una anulación
síncrona. Si el gateway devuelve un resultado ambiguo, la venta se actualiza a
`UNKNOWN`. Eso mezcla dos hechos diferentes: la venta original fue aprobada,
pero no se sabe si la **anulación** tuvo efecto. Tampoco queda una recuperación
durable ni un único dueño para resolverla.

El objetivo es aplicar a la anulación las garantías ya usadas por la venta:

- persistir el intento y sus identificadores antes del efecto externo;
- distinguir `NOT_SENT` de `INDETERMINATE`;
- no reenviar un `0200` que pudo haber llegado;
- crear una única operación durable que gobierne una anulación ambigua;
- publicar un estado terminal o un handoff a revisión, sin inventar certeza.

No se modifica `payment_processor/legacy/`. El gateway sigue siendo un
adaptador HTTP → ISO. El worker de la API continúa siendo el único emisor de
reversos de **ventas**; no emite reversos de anulaciones con el legacy actual.

## 2. Decisión condicionada por el contrato legacy

La anulación vigente es un `0200` con `DE3=020000`, un STAN nuevo y un ticket
de anulación en `DE62`; referencia la venta en `DE37`. El reverso actual (`0400`)
fue caracterizado para una venta, no para ese `0200` de anulación.

La lectura estática sugería una posibilidad: todo `0400` llega a `reverso()` y
la búsqueda compara `procode`; una anulación se persiste como `0200/020000`.
La prueba integrada VA-00 la descartó. Tras una venta aprobada y una anulación
confirmada, un `0400/020000` con el mismo STAN y ticket respondió `0410/00`,
pero dejó activa la fila de anulación `0200/020000` y agregó otra `0400/020000`.

La causa es verificable: el camino Verifone de `anula_cupon()` guarda
`vencimiento=NULL`; `valida_cupon_reverso()` exige el vencimiento de `DE14`
(`1228` en la sonda) para encontrarla. `reverso()` trata el miss como éxito e
inserta su fila `0400`. Ver
`payment-gateway/docs/legacy-reversal-contract.md` y su fixture ejecutable.

Por lo tanto el diseño conserva el registro durable y el handoff a
`MANUAL_REVIEW`, pero **no** crea ni reintenta un `0400` para la anulación. La
app nunca reenvía el `0200` ambiguo. Una eventual corrección acotada del C
legacy requeriría una decisión explícita, prueba de compatibilidad y actualización
de `payment_processor/LEGACY_CHANGELOG.md` antes de reabrir esta alternativa.

## 3. Modelo de dominio propuesto

`transactions` continúa representando la venta. Una venta aprobada no pasa a
`UNKNOWN` porque falle su anulación: permanece `APPROVED` hasta que una
anulación se confirme como `VOIDED`.

Se agrega una operación hija persistente, denominada aquí `void_operations`:

| Dato | Propósito |
|---|---|
| `id` (`BIGINT IDENTITY`) y `transaction_id` | identidad técnica y venta de origen |
| `idempotency_key` y huella del request | replay seguro de la intención de anular |
| `stan`, `void_ticket`, `original_ticket` | reproducir o compensar exactamente el `0200` |
| `outcome` | `PENDING`, `APPROVED`, `DECLINED`, `NOT_SENT` o `INDETERMINATE` |
| `public_status` derivado | `PENDING`, `VOIDED`, `DECLINED` o `FAILED` |
| código y mensaje sanitizados | trazabilidad sin PAN, CVV ni datos de pista |

El PAN ya persistido para recuperación de la venta se reutiliza solo si la
política PCI vigente lo permite. La comparación de `last4` sigue verificando
que el operador presente la misma tarjeta. No se persiste CVV ni se agregan
datos sensibles a eventos, logs o respuestas.

No se crea por ahora un `processor_job` emisor para la anulación: el único
`0400/020000` caracterizado no es compensatorio. La operación indeterminada
crea una alerta durable y queda en `UNDER_REVIEW`; una futura herramienta de
central podrá resolverla con evidencia externa. Debe existir a lo sumo una
operación de anulación activa por venta; el constraint se verifica en base de
datos, no solo en la API.

Los intentos ya existentes en estado `UNKNOWN` no contienen los identificadores
necesarios para compensarlos. Una migración los deja consultables como
`UNDER_REVIEW`; no intenta reconstruir ni reenviar mensajes históricos.

## 4. Máquina de estados

```text
Venta APPROVED
  │ POST /void
  ├─ APPROVED ─────────────────────────────► Venta VOIDED
  ├─ DECLINED ─────────────────────────────► Venta APPROVED + void DECLINED
  ├─ NOT_SENT (agotado) ───────────────────► Venta APPROVED + void FAILED
  └─ INDETERMINATE ─► void UNDER_REVIEW + alerta durable
```

Mientras hay una anulación `PENDING`, esa venta no admite otra anulación y el
cierre de lote debe bloquearse. Si la operación pasa al estado interno
`UNDER_REVIEW`, tampoco se permite una nueva anulación **de ese cupón** ni el
cierre hasta que la herramienta administrativa futura la resuelva. Las demás
ventas de la terminal son independientes y pueden anularse normalmente. Solo
después de `DECLINED` o `FAILED` internos se puede iniciar una nueva anulación,
con una clave de idempotencia nueva y nuevos identificadores.

Un replay con la **misma** clave nunca vuelve a enviar el `0200`: devuelve el
estado de la misma `void_operation`. Los únicos reintentos síncronos permitidos
son `NOT_SENT`, con el mismo STAN/ticket y dentro del presupuesto configurado.

## 5. Contrato HTTP y mobile

La respuesta de `POST .../void` representa la anulación, no la venta:

`202 Accepted` se reserva exclusivamente para una operación cuyo estado
público sea `PENDING` y que requiera polling. Todo resultado final, incluso un
fallo técnico clasificado, devuelve `200`; un `5xx` queda reservado para un
error inesperado de la API sin resultado durable confiable.

| Resultado | HTTP | Estado público | Acción de la terminal |
|---|---:|---|---|
| confirmada | 200 | `VOIDED` | finalizar |
| rechazo explícito | 200 | `DECLINED` | informar; puede iniciar otra anulación |
| no enviada | 200 | `FAILED` + `reason=NOT_SENT` | informar; puede iniciar otra anulación |
| ambigua | 200 | `FAILED` + `reason=UNDER_REVIEW` | finalizar sin polling e imprimir/comunicar handoff; no iniciar otra para ese cupón |

Se agrega `GET /v1/transactions/{transaction_number}/void` para consultar la
operación de anulación de la terminal autenticada. Mantenerlo separado del
estado de la venta evita cambiar el significado del endpoint que ya recupera
autorizaciones. La respuesta incluye `reason`, `poll_after_seconds` y
`may_start_new_void`; no expone estado del job ni campos ISO.

Mobile reutiliza el patrón de handoff de ventas: ante
`FAILED / UNDER_REVIEW` no pide nuevamente la tarjeta ni muestra “REINTENTAR
ANULACIÓN”; informa que la
anulación está en verificación y conserva el comprobante/referencia. Cuando
central la resuelva como no aplicada, explica que la venta sigue aprobada y
ofrece iniciar una anulación nueva como acción explícita.

## 6. Implementación y validación

1. Mantener la evidencia VA-00 como gate: no exponer ni emitir reversos de
   anulación mientras el legacy vigente no tenga una corrección caracterizada.
2. ✅ **VA-01:** la migración `20261022_0013`, modelos, repositorio y
   constraints crean `void_operations` y una alerta única por revisión. No se
   reconstruyen `UNKNOWN` históricos: siguen sujetos a resolución manual.
3. ✅ **VA-01:** API tipa los resultados de anulación como `APPROVED`,
   `DECLINED`, `NOT_SENT` e `INDETERMINATE`; los finales no aplicados permiten
   una nueva anulación, pero nunca se reenvía un resultado ambiguo.
4. ✅ **VA-01:** `POST` devuelve el estado de la anulación y
   `GET /v1/transactions/{transaction_number}/void` la consulta aislada por
   terminal. La alerta y la guardia de cierre ocurren en la misma unidad
   durable; no hay worker emisor de reversos de anulaciones.
5. ✅ **VA-01:** mobile interpreta `200/FAILED` con `reason=UNDER_REVIEW` como
   handoff y conserva la venta aprobada. Quedan pendientes la impresión
   específica y la prueba en V660P.
6. Cubrir validación, aislamiento por terminal, replay concurrente, pérdida de
   respuesta, crash, `NOT_SENT`, creación única de alerta, lote bloqueado y
   datos sensibles. Ejecutar `make check` en API y gateway, además de
   `flutter analyze` y `flutter test`.

Antes de activar, aplicar la migración y verificar contra una API levantada.
La activación productiva seguirá el canary y rollback no destructivo definidos
para reversos de ventas. Las anulaciones ambiguas terminan en `UNDER_REVIEW`
hasta contar con una corrección legacy aprobada y una nueva caracterización.
