# Errores del flujo de venta (mobile → API → gateway → procesador)

> **Última revisión:** 2026-09-21 — revisión completa del camino de venta y
> anulación en `fix/errores_transacciones_ventas` (HEAD `b394162`).
>
> Documento **enfocado en la venta**. No reemplaza a la serie general
> ([`errores-backend.md`](errores-backend.md): contrato común, cadena de
> propagación y matriz de decisión; satélites [`errores-api.md`](errores-api.md),
> [`errores-gateway.md`](errores-gateway.md),
> [`errores-procesador.md`](errores-procesador.md),
> [`errores-mobile.md`](errores-mobile.md) y
> [`errores-hallazgos.md`](errores-hallazgos.md) con la serie BN-01…BN-18).
> Acá se listan **defectos de comportamiento** del camino de venta, cada uno con
> evidencia `archivo:línea` y con la prueba manual de UI que lo revela
> ([`test_cases_ventas_ui.md`](test_cases_ventas_ui.md), serie `TC-V-###`).
>
> **Estado:** a esta fecha **ninguno** de los VE-xx está corregido en el código.
> Los IDs `VE-xx` son nuevos y no colisionan con `BE-xx` (serie del hub) ni con
> `BN-xx` (hallazgos de contrato).

---

## 1. Mapa del camino de venta

| Paso | Archivo | Qué ocurre |
|------|---------|------------|
| 1. Producto y cantidad | `mobile/lib/features/sales/presentation/screens/sale_form_screen.dart` | Catálogo `GET /v1/products`; la **cantidad** viaja como `amount` (string) |
| 2. Captura | `sale_waiting_for_card_screen.dart` + `mobile/lib/psdk/psdk_card_reader.dart` (banda) / `sale_manual_card_screen.dart` (manual) | `entry_mode` `022` (banda, sin `track2`) o `012` (manual) |
| 3. Confirmación | `sale_review_screen.dart` → `sales_cubit.dart` (`sendIsoMessage`) | Emite `SalesProcessing` y navega a "Procesando" |
| 4. Envío | `mobile/lib/features/sales/data/sales_repository.dart` (`registerSale`) | `POST /v1/transactions` + `Idempotency-Key` |
| 5. API | `api/presentation/controllers/transactions_controller.py` → `api/application/payments/create_transaction.py` | Valida, persiste `PENDING`, llama al gateway |
| 6. Gateway | `payment-gateway/application/payments/authorize_payment.py` → `infrastructure/iso/message_builder.py` → `tcp_processor.py` | Arma ISO `0200` y lo envía por TCP a authkig |
| 7. Resultado | `create_transaction._apply_gateway_result` → `sale_processing_screen.dart` → `sale_status_screen.dart` | Estado + mensaje + impresión de ticket |
| 8. Anulación | `void_card_screen.dart` → `sales_cubit.voidSale` → `api/application/payments/void_transaction.py` | ISO `0200`/`020000` con reingreso de tarjeta |

Cadena de estados que puede devolver el backend a la app:

```
PENDING ──► APPROVED ──► VOIDED
   │  └──► DECLINED
   │  └──► FAILED   (no se pudo procesar; reintentable)
   └─────► UNKNOWN  (ambiguo: el ISO pudo haber llegado; NO reintentar)
```

---

## 2. Índice de hallazgos

| ID | Sev. | Hallazgo | Prueba | Traza |
|----|:----:|----------|--------|-------|
| VE-01 | P0 | La API rechaza `entry_mode=022` sin `track2` y el flujo MSR de la app envía exactamente eso → la venta por banda nunca llega al procesador | TC-V-002 | G-P0-19 · G-P1-06 · G-P0-15 |
| VE-02 | P0 | Corregido: el cobro espera 45 s (más que los 35 s del backend). Si igual no hay respuesta, avisa pendiente de confirmación y no invita a reintentar. TC-V-009 sigue manual | TC-V-009 | G-P0-20 |
| VE-03 | P0 | La `Idempotency-Key` se regenera en cada intento y la UI no tiene guard de reentrada (doble tap = doble venta) | TC-V-011 | G-P0-21 · G-P1-02 · hallazgo #24 |
| VE-04 | P1 | Un resultado ambiguo (`UNKNOWN`) se muestra como "Transacción Rechazada / 51 Fondos insuficientes" | TC-V-012 | G-P1-11 · G-P1-09 |
| VE-05 | P1 | La pantalla de resultado no muestra el `user_message` del backend y el código de respuesta es fijo por estado | TC-V-012 · TC-V-007 | G-P1-11 · hallazgo #20 |
| VE-06 | P1 | Los 400/404/409 de la API se descartan en la app (`message` vs `user_message`) | TC-V-003 · TC-V-014 | G-P1-12 · BN-01 · BN-09 |
| VE-07 | P1 | `expiration_date` no se valida en ninguna capa (formato MMYY, mes 01-12) | TC-V-014 | G-P1-14 |
| VE-08 | P2 | Sin cota superior de importe: DE4 puede desbordar 12 dígitos y desalinear el ISO | TC-V-005 | G-P2-07 |
| VE-09 | P2 | Decimales de cantidad: el procesador exige enteros por producto (`validaIntMoneda`) y el mapeo de DE39 `13` falta en la API | TC-V-003 · TC-V-004 | G-P2-07 · BN-05 |
| VE-10 | P2 | Tras una anulación ambigua (`UNKNOWN`) no hay camino de resolución: la venta no se puede volver a anular ni consultar | TC-V-016 | G-P2-08 · G-P0-12 |
| VE-11 | P2 | Corregido: `SaleStatusScreen` sin `OperationModel` avisa que faltan datos y vuelve atrás, en lugar de dibujarse como aprobada | — (latente, cubierto por test de widget) | G-P2-09 |
| VE-12 | P2 | Ciclo PSDK en la pantalla de espera: sin `tearDown` tras el éxito y `dispose()` sin `await` → riesgo de romper la impresión | TC-V-013 · TC-V-018 | G-P2-09 |
| VE-13 | P3 | El terminal id sale de `--dart-define=INSTALLATION_ID` (default `05000001`): todos los APK sin el define reportan la misma terminal | TC-V-008 | G-P0-08 |
| VE-14 | P3 | Fallback silencioso de catálogo/historial y contrato `unit` del catálogo ignorado en la UI | TC-V-006 · TC-V-015 | G-P1-07 |

---

## 3. Fichas de hallazgos

### VE-01 · P0 · La venta por banda se rechaza en la API antes de llegar al procesador

**Síntoma.** Se pasa la tarjeta por banda (flujo principal del producto), la app
llega a "Procesando" y el resultado es "Transacción Rechazada" con el texto
genérico "Venta rechazada por la entidad emisora." **La venta no aparece en el
historial** y el procesador nunca recibe un ISO.

**Evidencia.**
- La API exige `track2` cuando `entry_mode="022"`:
  `api/application/payments/create_transaction.py:97-100`
  (`if entry_mode == "022" and not track2: raise InvalidEntryMode(...)`) y la
  llamada en `:142` pasa **solo** `(entry_mode, track2)` — el `expiration_date`
  que sí llega del POS no se considera, aunque el docstring (`:90-91`) y el
  propio texto del error digan "requiere track2 **o vencimiento**".
- La app **no manda `track2` a propósito**: `sales_cubit.dart:96-97`
  (`entryMode: '022'`, `track2: null`) y `sales_repository.dart:209-211`
  (agrega `track2` solo si no es nulo).
- El único test que cubre la rama usa 022 **sin vencimiento**:
  `api/tests/test_create_transaction.py:370-385`, por eso el gate pasó.

**Causa.** Regresión introducida por la validación de consistencia del
`entry_mode` (commit `70d694c`, 2026-08-16) sobre un flujo que se había
verificado el 2026-08-13 (G-P0-15) enviando PAN + vencimiento y **sin** track2,
justamente porque el track2 de esta terminal trae un PAN distinto al registrado.

**Impacto.** El modo de captura principal del MVP (`docs/alcance.md` §2.1) queda
inoperante y el operador no tiene forma de saber por qué (ver VE-06).

**Cómo se reproduce.** TC-V-002 (banda real o `USE_MSR_MOCK=true`).

**Fix sugerido.** En `_validate_entry_mode`, aceptar el par cuando existe
`track2` **o** `expiration_date` (`if entry_mode == "022" and not track2 and not
expiration_date:`), pasando el vencimiento como tercer argumento. Alternativa
(b): volver a enviar `track2` desde mobile — descartada porque revive el defecto
de PAN distinto (G-P0-15) y el gateway ya manda DE2 siempre + DE35 solo si viene.

---

### VE-02 · P0 · Jerarquía de timeouts invertida (15 s cliente < 35 s servidor)

**Estado.** Corregido en la app (2026-09-23). `registerSale` espera
`kSaleRequestTimeout` (45 s), por encima de los 35 s de la API. Si el cliente
igual no recibe respuesta, el texto es pendiente de confirmación y no invita
a reintentar. TC-V-009 (pausa de 20 s) sigue siendo una prueba manual.

**Síntoma (antes del fix).** Con el procesador lento (16–35 s), la app mostraba
"Tiempo de espera agotado con el procesador de pagos. Reintente." (naranja,
"Error de Conexión") mientras la API seguía trabajando y **podía aprobar y
persistir la venta**.

**Evidencia.**
- Cliente: `kSaleRequestTimeout` en `sales_repository.dart` → 45 s, solo en
  `registerSale`. Antes: `Duration(seconds: 15)`.
- Pantalla: `saleConnectionSubtitle` en `sale_status_screen.dart` usa el
  `userMessage` de la operación. El fallback es
  `kSalePendingConfirmationMessage` (sin «reintente»).
- API: `api/config/settings.py` → `payment_gateway_timeout_seconds = 35.0`.
- Gateway: `payment-gateway/config/settings.py` → connect 5 s + read 30 s
  (hasta 35 s por intento antes de responder 502/503).

**Causa.** Los presupuestos de tiempo se definieron por capa y no se validó que
el cliente espere al menos lo que tarda el servidor.

**Impacto.** El operador veía un error donde pudo haber una aprobación →
reintentaba → doble cobro (agravado por VE-03, que sigue abierto).

**Cómo se reproduce.** TC-V-009 (`docker pause` del contenedor `auth` justo
después de CONFIRMAR y comparar la pantalla contra la fila en Postgres). Con
45 s de espera, una pausa de 20 s debe mostrar el resultado real de la API.

---

### VE-03 · P0 · Idempotencia inutilizada y doble tap en CONFIRMAR

**Síntoma.** (a) Un reintento del operador crea una operación nueva en vez de
repetir la misma; (b) dos toques rápidos en "CONFIRMAR COBRO" pueden enviar dos
ventas.

**Evidencia.**
- Clave nueva por request: `sales_repository.dart:213`
  (`_generateIdempotencyKey()` se llama **dentro** de `registerSale`; ídem
  `:87` en `voidTransaction`).
- Sin guard de reentrada: `sale_review_screen.dart:17-26` (Stateless, sin flag)
  y `sale_review_content.dart:83-103` (botón siempre habilitado);
  `sales_cubit.dart:103` (`sendIsoMessage` sin verificar el estado actual).

**Causa.** La clave se generó como identificador de request y no como
identificador de operación; la pantalla no bloquea el envío.

**Impacto.** El mecanismo de idempotencia del backend (`Idempotency-Key` + replay
`201`/`202`, `transactions_controller.py:159-163`) nunca se ejercita desde la
app, y la ventana de doble tap convive con los timeouts de VE-02.

**Cómo se reproduce.** TC-V-011 (doble tap + verificación de que quedó una sola
fila en `transactions`).

**Fix sugerido.** Generar la clave al confirmar (o al abrir la revisión),
guardarla en el estado y reutilizarla en el reintento; agregar un flag
`isSending` en el cubit y deshabilitar el botón mientras se envía.

---

### VE-04 · P1 · Un resultado ambiguo (`UNKNOWN`) se muestra como rechazo con código fijo

**Síntoma.** Ante un timeout/502/ISO ilegible, la pantalla muestra "Transacción
Rechazada / La terminal reportó un error en la autorización." con
"Código de respuesta: 51 (Fondos insuficientes)": invita a reintentar justo
cuando el backend pide lo contrario.

**Evidencia.**
- API: `api/application/payments/response_messages.py:19-21`
  (`MSG_UNKNOWN = "No pudimos confirmar el pago. No vuelva a intentarlo;
  consulte la operación."`), `create_transaction.py:269-271` (`UNKNOWN`) y
  `transactions_controller.py:153-164` (HTTP **201**).
- App: `sales_repository.dart:240-250` (cualquier 2xx con `status != APPROVED`
  queda `isApproved: false`, `connectionError: false`) → `sales_cubit.dart:149-153`
  (`PaymentResult.declined`) → `sale_status_screen.dart:79-83` (título y
  subtítulo fijos) → `sale_status_content.dart:184-195` (código `51`/`99`
  hardcodeado).

**Causa.** El enum de UI de la venta (`PaymentResult`) no tiene estado "ambiguo"
(el flujo de saldo sí lo tiene) y el mapeo descarta el `status` real de la API.

**Impacto.** Riesgo de doble cobro por reintento y pérdida del procedimiento
correcto ("consultar la operación", `docs/alcance.md` §2.1).

**Cómo se reproduce.** TC-V-012.

**Fix sugerido.** Agregar un estado `unknown` en venta, mapeado desde
`status == "UNKNOWN"` y desde los timeouts locales; copy "No pudimos confirmar
el cobro" con acción "VER OPERACIÓN" (historial) y sin "REINTENTAR". Coordinar
con G-P1-09 (reverso automático).

---

### VE-05 · P1 · La pantalla de resultado no muestra el mensaje del backend

**Síntoma.** Una venta rechazada por "Tarjeta vencida" (DE39 `54`) o "Excede
frecuencia de uso" (`65`) se muestra con el texto genérico y el código `51`.
El motivo real solo se ve entrando al **detalle del historial**.

**Evidencia.**
- `sale_status_screen.dart:73-95`: título y subtítulo se eligen por
  `PaymentResult`, sin usar `operation.userMessage`.
- `sale_status_content.dart`: filas fijas "Nro. Operación / Producto / Monto /
  Tarjeta / Código de respuesta" y `_responseCode()` con valores literales
  (`:184-195`).
- El mensaje **sí** se guarda y se propaga: `sales_cubit.dart:184-189`
  (`errorMessage`), `sale_processing_screen.dart:43` (`OperationModel.userMessage`),
  pero solo se renderiza en `sale_detail_ticket.dart:73-77` y en el ticket
  impreso (`receipt_formatter.dart:48-50`).
- `SaleResponse.errorCode` no lo consume ningún widget del `lib/`
  (grep de `errorCode`: solo `sales_repository`, `sales_cubit`, `sales_state`).

**Causa.** La UI de resultado se diseñó con estados fijos y nunca se conectó al
`user_message` de la API.

**Impacto.** Incumple `docs/alcance.md:63` ("mensajes de error comprensibles a
partir de la respuesta del backend/procesador") y reabre el hallazgo #20 de
`test_cases_hallazgos.md` (marcado *Resuelto* el 2026-07-31).

**Cómo se reproduce.** TC-V-007 (agotar saldo → comparar pantalla vs detalle).

**Fix sugerido.** Mostrar `operation.userMessage` en la pantalla de resultado
(cuando venga) y reemplazar el código hardcodeado por el `processor_response_code`
real, que la API ya devuelve como `status` + mensaje (y que el listado podría
exponer en `TransactionItemResponse`).

---

### VE-06 · P1 · Los errores 400/404/409 de la API se descartan en la app

**Síntoma.** Cualquier validación o conflicto del backend se muestra como "Venta
rechazada por la entidad emisora." / "Anulación rechazada por la entidad
emisora." — sin motivo. Es lo que hace invisible a VE-01 en el terminal.

**Evidencia.**
- La API responde `{"message": "<texto>"}` en los errores de dominio:
  `transactions_controller.py:143-151` (venta) y `:199-212` (anulación).
- La app lee `user_message`:
  - venta: `sales_repository.dart:252-259`
    (`responseData['user_message'] ?? 'Venta rechazada por la entidad emisora.'`);
  - anulación: `sales_repository.dart:123-127`.

**Causa.** Dos nombres distintos para el mismo concepto (`message` en las
respuestas de error, `user_message` en las de negocio) y el cliente asumió que
siempre viene `user_message` (es la observación BN-01 del hub: no hay código de
error estable).

**Impacto.** Diagnóstico imposible en el terminal: "Monto inválido", "Modo banda
(022) requiere track2 o vencimiento", "Idempotency-Key ya usada con otro
request", "La tarjeta no coincide con la de la venta original" y "Solo se pueden
anular transacciones aprobadas" llegan todos como un único texto genérico.

**Cómo se reproduce.** TC-V-003 (cantidad con 3 decimales) y TC-V-014 (formulario
manual) — en ambos casos la pantalla miente sobre la causa.

**Fix sugerido.** En el repositorio, aceptar `user_message` **o** `message`
(`responseData['user_message'] ?? responseData['message'] ?? <fallback>`), y a
mediano plazo exponer un `error_code` estable en API/gateway (BN-01/BN-03/BN-04).

---

### VE-07 · P1 · `expiration_date` no se valida en ninguna capa

**Síntoma.** Un vencimiento incompleto o mal tipeado llega al procesador tal como
se escribió; el rechazo que vuelve (o no) no permite entender qué pasó.

**Evidencia.**
- Esquema API: solo longitud (`api/presentation/schemas/transactions.py:16`,
  `max_length=4`); el caso de uso apenas hace `strip`
  (`create_transaction.py:150-152`).
- Gateway: `_pad_digits(expiration_date, 4)`
  (`payment-gateway/infrastructure/iso/message_builder.py:46-48`) rellena con
  ceros a la izquierda lo que venga → `"12"` se serializa como `0012` (mes 00).
- La app **sí** valida MM/AA y mes 1–12 en el formulario manual
  (`card_fields_container.dart:85-99`), pero por banda el vencimiento viene de la
  banda (`msr_card_data.dart:75-85`) sin validación de rango.

**Causa.** La validación de negocio del vencimiento nunca se implementó en API ni
gateway (el hallazgo #4 de `test_cases_hallazgos.md` la dio por resuelta
citando solo el límite de longitud del esquema).

**Impacto.** Rechazos mal diagnosticados (`54` tarjeta vencida vs `14` tarjeta
inválida) y, en modo manual, dependencia del formato exacto tipeado por el
operador.

**Cómo se reproduce.** TC-V-014 (vencimiento `3/25` → `325`, mes `00` si se
envía `12`).

**Fix sugerido.** Validar en la API `MMYY` (mes 01–12, longitud 4) y coherencia
con el `entry_mode`; devolver 400 con mensaje específico (y mostrarlo, VE-06).

---

### VE-08 · P2 · Sin cota superior de importe: DE4 puede desbordar y desalinear el ISO

**Síntoma.** Una cantidad enorme (o un cliente HTTP malicioso) produce un DE4 de
más de 12 dígitos; el gateway lo empaqueta sin chequear longitud y el autorizador
C parsea por offsets fijos → campos corridos (STAN, terminal, importe).

**Evidencia.**
- Sin máximo: `api/domain/money.py:20-33` (solo `> 0` y escala 2),
  `api/presentation/schemas/transactions.py:11` (`max_length=32`),
  `payment-gateway/presentation/schemas/authorize.py:9` (`gt=0`).
- Sin truncado ni chequeo: `message_builder.py:34` (`f"{amount_minor:012d}"`) y
  `payment-gateway/infrastructure/iso/packer.py:64-65` (escribe DE4 con
  `asc_to_bcd(iso.amount_4)` sin validar tamaño).
- La UI no acota la cantidad: `sale_form_screen.dart:162-192` (sin `maxLength`
  ni `LengthLimitingTextInputFormatter`) y `amount_input_formatter.dart` acepta
  dígitos ilimitados.

**Causa.** Falta de un rango de importe/cantidad acordado con el procesador.

**Impacto.** Ventas con resultado incierto y mensajes ISO potencialmente
ilegibles (el caso extremo de VE-04). En el MVP la probabilidad es baja (requiere
un error grosero de tipeo), pero es verificable por API.

**Cómo se reproduce.** TC-V-005 (cantidad `1234567890123`); revisar `authkig.log`
y la respuesta del procesador.

**Fix sugerido.** Definir y validar un máximo (p. ej. cantidad ≤ 99.999.999,99)
en el esquema de la API **y** en el del gateway, y agregar en el packer una
verificación de tamaño por campo (fallar con `IsoPackError` antes de enviar).

---

### VE-09 · P2 · Decimales de cantidad y mapeo faltante del DE39 `13`

**Síntoma.** Una cantidad con decimales en un producto que el procesador maneja
como entero se rechaza sin explicación; con 3 o más decimales ni siquiera llega
al procesador.

**Evidencia.**
- El procesador exige enteros por producto cuando `validaIntMoneda` aplica:
  `payment_processor/legacy/bin/auth_mycli.c:1627-1638`
  (`tk_int_amount != tk_amount` → `INVALID_AMOUNT`), y ese retorno se serializa
  como DE39 `13`.
- La API **no mapea `13`**: `api/application/payments/response_messages.py:3-15`
  (el gateway sí: `response_mapper.py:9-19`, pero su `user_message` se descarta)
  → el operador ve "Pago rechazado" (BN-04/BN-05).
- Escala: `api/domain/money.py:27` exige exactamente 2 decimales → `1,005` da 400
  "Monto inválido", que la app convierte en texto genérico (VE-06). El formateador
  de la UI permite decimales ilimitados (`amount_input_formatter.dart`).

**Impacto.** El agregado `GRANEL` (m³) necesita decimales y las garrafas/tubos no
los admiten: hoy la app no comunica esa regla ni distingue los motivos.

**Cómo se reproduce.** TC-V-003 (garrafa ×3,5) y TC-V-004 (×1,005).

**Fix sugerido.** Agregar los DE39 faltantes al mapa de la API (empezando por
`13`, `12`, `17`, `19`, `30`, `76`, `89`, `95`), alinear el mapa con el del
gateway y validar la cantidad contra la unidad del producto del catálogo
(`unit`), que hoy la UI ignora (VE-14).

---

### VE-10 · P2 · Tras una anulación ambigua (`UNKNOWN`) no hay camino de resolución

**Síntoma.** Si la anulación queda `UNKNOWN`, la app no puede reintentarla (la
API responde 400) ni confirmar el estado (no hay endpoint de detalle), y el
mensaje que explica esto se pierde en la app (VE-06).

**Evidencia.**
- `api/application/payments/void_transaction.py:100-101`: solo `APPROVED`
  (y `VOIDED` como replay) son anulables → una venta en `UNKNOWN`
  (`:192-199`, `apply_void_result(status=UNKNOWN)`) queda bloqueada.
- No existe `GET /v1/transactions/{transaction_number}`
  (`transactions_controller.py` solo expone `GET ""`, `POST ""` y
  `POST /{nro}/void`) → coincide con G-P0-12 / hallazgo #9.
- La app solo refleja `UNKNOWN` en el historial en memoria
  (`sales_cubit.dart:224-251`) y el resultado de la anulación es un callejón
  (`void_result_screen.dart:36-40`: "No se pudo confirmar" sin acciones).

**Impacto.** El comercio no puede revertir la venta por el canal de la app y
tampoco puede auditarla; requiere intervención manual (BD/procesador).

**Cómo se reproduce.** TC-V-016 (pausar el procesador durante una anulación).

**Fix sugerido.** Permitir reanudar la anulación de una venta `UNKNOWN`
(reintento con la misma `Idempotency-Key` o reverso automático, G-P1-09) y
exponer el detalle/estado por API.

---

### VE-11 · P2 · `SaleStatusScreen` sin argumentos se dibuja como aprobada

**Estado.** Corregido (2026-09-28). Si faltan datos, la pantalla muestra
«No hay datos de la operación disponibles» y hace `maybePop`. Cubierto por
`mobile/test/sale_status_screen_test.dart`.

**Síntoma.** Si la pantalla se abre sin `arguments` (navegación nueva, deep link
o refactor futuro), muestra "¡Transacción Aprobada!" con `Nro. Operación: ---`.

**Evidencia.** `sale_status_screen.dart:35-42` (`_operation` queda en `null` si
los argumentos no son `OperationModel`) y `:66`
(`final PaymentResult result = operation?.result ?? PaymentResult.approved;`).

**Impacto.** Latente: hoy solo la navega `sale_processing_screen.dart:45-49` con
argumentos, pero un cambio futuro (o un test mal armado) haría visible una
aprobación falsa. Comparar con el guard de `sale_detail_screen.dart:27-34`.

**Fix aplicado.** Si faltan argumentos, la pantalla vuelve atrás y muestra un
aviso en lugar de asumir `approved`.

---

### VE-12 · P2 · Ciclo del PSDK en la pantalla de espera (teardown y cancelación)

**Síntoma.** Después de una lectura por banda exitosa, la pantalla de espera
queda montada hasta el final del flujo y su `dispose()` dispara la limpieza del
SDK sin esperar; si el operador reimprime o vuelve a leer en ese momento, puede
recibir "No se pudo inicializar la impresora. Reintente." o un error de lector.

**Evidencia.**
- `sale_waiting_for_card_screen.dart:34-41`: `dispose()` llama `_reader.cancel()`
  (asíncrono) **sin `await`**; la navegación al review es un `push`
  (`:63`), así que la pantalla sigue viva durante todo el flujo.
- `psdk_card_reader.dart:196-199`: `cancel()` = `cancelReadMsr` → `tearDown`.
- La impresión usa el mismo SDK: `receipt_printer.dart:40`
  (`ensureReady(initializeIfNeeded: true)`) llamado desde
  `sale_status_screen.dart:39-41,45-61` (automática) y desde
  `sale_detail_screen.dart:107-122` (reimpresión).

**Impacto.** Fallos intermitentes de impresión/lectura difíciles de reproducir
(solo en el terminal) y sensación de app inestable.

**Cómo se reproduce.** TC-V-013 y TC-V-018 (venta por banda → impresión
automática → REIMPRIMIR → historial → detalle → IMPRIMIR TICKET → nueva venta).

**Fix sugerido.** Hacer la limpieza explícita al terminar la lectura (o al salir
de la pantalla) con `await`/`unawaited` explícito y ordenar el ciclo
lectura → resultado → impresión con un único dueño del SDK.

---

### VE-13 · P3 · Identidad del terminal por `--dart-define` (default `05000001`)

**Síntoma.** Todo APK compilado sin `--dart-define=INSTALLATION_ID=...` se
identifica como la terminal demo: las ventas se autorizan y se listan contra
`05000001` (una sola "caja" lógica para todos los dispositivos).

**Evidencia.** `mobile/lib/features/auth/data/auth_repository.dart:8-20`
(`String.fromEnvironment('INSTALLATION_ID', defaultValue: '05000001')`) usado en
`login` (`:44`) y `register` (`:104`); la API hace `upsert` de esa instalación
(`api/application/auth/login_user.py:53`) y el token la lleva como
`installation_id`, que además filtra el historial
(`transactions_controller.py:62-66`) y es el DE41 que valida el procesador.

**Impacto.** Riesgo operativo de mezclar ventas entre terminales y de fallos
`89` (terminal desconocida) al usar el APK en otro equipo. Ya registrado como
G-P0-08; se relee acá porque condiciona cualquier prueba de venta.

**Cómo se reproduce.** TC-V-008 (APK con `INSTALLATION_ID=99999999` → DE39 `89`).

**Fix sugerido.** Derivar el terminal del dispositivo/configuración persistida
(ver ramas `feature/dynamic-terminal-id`, `feature/front_serial_to_backend`) y
mostrarlo en la UI de login/estado.

---

### VE-14 · P3 · Fallbacks silenciosos y contrato `unit` del catálogo ignorado

**Síntoma.** (a) Si falla la red al cargar catálogo o historial, la app no avisa:
muestra 5 productos hardcodeados o "No hay transacciones registradas." (que el
operador lee como "la venta no se registró"). (b) La unidad de medida se decide
por código (`GRANEL`) en vez de usar el contrato del backend.

**Evidencia.**
- `sales_repository.dart:32-70` (`fetchProducts` con `_defaultProducts()`) y
  `:149-185` (`fetchHistory` → `[]`); consumidores:
  `sale_form_screen.dart:44-73` y `sales_history_screen.dart:44-53,109-125`
  (`history.isEmpty` ⇒ "No hay transacciones registradas.").
- Catálogo con unidad: `api/presentation/controllers/products_controller.py:27-30`
  (`code`, `label`, `unit`) y `packages/catalog/src/solidaridad_catalog/products.py:76-85`
  (`singular`/`plural`); contrato de producto en `docs/alcance.md:188`.
- La UI ignora `unit`: `ProductInfo.fromJson` lee solo `code`/`label`
  (`sale_model.dart:159-164`) y el m³ se decide con `code == 'GRANEL'`
  (`sale_form_screen.dart:36`, `sale_review_content.dart:20-26`).

**Impacto.** Diagnóstico falso durante una caída (hallazgo #23 / G-P1-07) y
etiquetas erróneas si el catálogo cambia.

**Cómo se reproduce.** TC-V-006 (cortar la red y abrir el formulario/historial) y
TC-V-015 (historial paginado).

**Fix sugerido.** Propagar el error (banner + reintento) en lugar del fallback
silencioso y consumir `unit` del catálogo para los textos de cantidad.

---

## 4. Matriz: lo que ve el operador vs lo que pasó realmente

| Resultado real (backend) | HTTP | Lo que muestra hoy la app | Lo que debería mostrar | Traza |
|---|---|---|---|:----:|
| `APPROVED` (`DE39 00`) | 201 | "¡Transacción Aprobada!" + ticket | igual | — |
| `DECLINED` `51` fondos insuficientes | 201 | "Transacción Rechazada / 51 (Fondos insuficientes)" | "Fondos insuficientes" | VE-05 |
| `DECLINED` `54` vencida / `65` frecuencia / `05` / `96`… | 201 | **"51 (Fondos insuficientes)"** (código incorrecto) | el motivo real del DE39 | VE-04 · VE-05 · VE-09 |
| `FAILED` (gateway 503, no conectó) | 201 | "Transacción Rechazada / 51 (Fondos insuficientes)" | "No se pudo procesar el pago. Intente nuevamente." | VE-04 · VE-05 |
| `UNKNOWN` (timeout / 502 / ISO ilegible) | 201 | "Transacción Rechazada / 51 (Fondos insuficientes)" | "No pudimos confirmar el cobro" + VER OPERACIÓN | VE-04 |
| Timeout del cliente a los 45 s (mayor que los 35 s del backend) | — | espera el resultado de la API; si igual corta: pendiente de confirmación, sin invitar a reintentar | igual | VE-02 |
| Validación 400 (`Monto inválido`, `Modo banda (022)…`) | 400 | "Venta rechazada por la entidad emisora." | el `message` de la API | VE-01 · VE-06 |
| 409 `Idempotency-Key ya usada con otro request` | 409 | "Venta rechazada por la entidad emisora." | el `message` de la API | VE-06 |
| 500 sin handler (`text/plain`) | 500 | `jsonDecode` falla → "Ocurrió un error inesperado. Reintente." | error de servidor (BN-02) | BN-02 |
| 401 token expirado | 401 | logout + login | igual | G-P0-17 |
| Anulación `VOIDED` | 200 | "¡Anulación Aprobada!" | igual | — |
| Anulación 400 (tarjeta distinta / no anulable) | 400 | "Anulación rechazada por la entidad emisora." | el `message` de la API | VE-06 · VE-10 |
| Anulación 404 (transacción inexistente) | 404 | "Anulación rechazada por la entidad emisora." | el `message` de la API | VE-06 |

---

## 5. Verificación rápida por capa

```bash
# 0) Stack completo (gateway con ISO real, API, procesador)
make dev

# 1) Gateway directo (saltea API): verifica el ISO y el DE39 del procesador
curl -X POST http://127.0.0.1:8001/v1/authorize -H "Content-Type: application/json" \
  -d '{"card_number":"6063007014007403","expiration_date":"1228","amount_minor":400,
       "product_code":"993","terminal_id":"05000001","stan":"000001","ticket_number":"0001"}'

# 2) API (venta) — con el token del login y una clave nueva por prueba
curl -X POST http://127.0.0.1:8000/v1/transactions \
  -H "Content-Type: application/json" -H "Authorization: Bearer <JWT>" \
  -H "Idempotency-Key: manual-$(date +%s)" \
  -d '{"product":"GARRAFA_10","amount":"4.00","card_number":"6063007014007403",
       "cvv":"878","expiration_date":"1228"}'

# 2b) Caso VE-01 (banda sin track2, con vencimiento) → hoy 400 InvalidEntryMode
curl -X POST http://127.0.0.1:8000/v1/transactions \
  -H "Content-Type: application/json" -H "Authorization: Bearer <JWT>" \
  -H "Idempotency-Key: manual-$(date +%s)" \
  -d '{"product":"GARRAFA_10","amount":"1.00","card_number":"6063007014007403",
       "entry_mode":"022","expiration_date":"1228"}'

# 3) Estado real en Postgres (¿se cobró aunque la app diga error?)
docker exec -i solidaridad-db psql -U solidaridad -d solidaridad -c \
  "select transaction_number,status,processor_response_code,user_message,
          idempotency_key,created_at from transactions order by id desc limit 10;"

# 4) Traza de eventos de la operación
docker exec -i solidaridad-db psql -U solidaridad -d solidaridad -c \
  "select transaction_id,from_status,to_status,event_type,idempotency_key,created_at
     from transaction_status_events order by id desc limit 20;"

# 5) Motor legacy: ventas registradas y código de respuesta
docker exec -i solidaridad-processor-mysql sh -c \
  "MYSQL_PWD=localdev mysql -ukigadmin2 kigsolidario2 -e \
   'select id_operacion,codigo_respuesta,importe,cod_moneda,terminalid from sgas_cup order by id desc limit 10;'"

# 6) Log del autorizador (DE39, PAN, track, montos)
docker logs --tail 200 solidaridad-processor-auth | grep -E "RESPONSE CODE|TRACK II|MONTO A PAGAR"

# 7) Inducir procesador lento (VE-02): pausar el contenedor del autorizador
docker pause solidaridad-processor-auth     # y luego: docker unpause solidaridad-processor-auth
```

> Nota: el contenedor del autorizador se llama `solidaridad-processor-auth` y el
> de MySQL `solidaridad-processor-mysql` (ver `payment_processor/docker-compose.yml`);
> Postgres es `solidaridad-db` (ver `api/docker-compose.yml`).

---

## 6. Decisiones abiertas (requieren definición de producto/técnica)

| # | Decisión | Opciones | Impacto si no se define |
|---|----------|----------|-------------------------|
| D-1 | Criterio de validez de `entry_mode=022` (VE-01) | (a) aceptar `track2` **o** `expiration_date`; (b) enviar `track2` desde mobile | (a) desbloquea la banda con un cambio de una línea; (b) revive el defecto de PAN distinto (G-P0-15) |
| D-2 | Máximo de importe/cantidad por venta y por producto (VE-08/VE-09) | **Cerrado (2026-09-24):** tope único igual a DE4, `9.999.999.999,99`. Un tope por producto queda en VE-09. | sin tope, un error de tipeo puede generar un ISO inválido |
| D-3 | ¿Qué es `amount` en la venta: cantidad o importe? (VE-09) | cantidad con 2 decimales (hoy) vs cantidad entera + precio calculado en el procesador | los textos de UI ("Cantidad de Unidades", m³) y los rechazos del procesador quedan sin regla explícita |
| D-4 | `error_code` estable en API/gateway (VE-06, BN-01/BN-03/BN-04) | agregarlo ahora vs seguir con textos en español | cada cambio de copy rompe el cliente y el diagnóstico en campo |
| D-5 | Estado "ambiguo" en la UI de venta y reverso automático (VE-04, G-P1-09) | agregar `PaymentResult.unknown` + reverso `0400`; o al menos cambiar el copy | reintentos del operador con riesgo de doble cobro |
| D-6 | Política de reintento desde la UI (VE-03, G-P1-02) | mismo `Idempotency-Key` guardada en el estado + botón REINTENTAR; o reenvío automático | idempotencia decorativa y doble tap sin protección |
| D-7 | Identidad del terminal (VE-13, G-P0-08) | `--dart-define` (hoy) vs derivar del dispositivo/configuración persistida | ventas atribuidas a la terminal demo y `89` en equipos nuevos |

---

## 7. Referencias

**Código (fuente de verdad).**
- Venta: `mobile/lib/features/sales/**` (`sales_repository.dart`, `sales_cubit.dart`,
  `sale_review_screen.dart`, `sale_processing_screen.dart`, `sale_status_screen.dart`,
  `sale_status_content.dart`), `mobile/lib/psdk/psdk_card_reader.dart`,
  `mobile/lib/features/sales/data/receipt_printer.dart`.
- API: `api/presentation/controllers/transactions_controller.py`,
  `api/application/payments/{create_transaction,void_transaction,response_messages}.py`,
  `api/infrastructure/payments/http_gateway.py`, `api/domain/{money,exceptions}.py`,
  `api/config/settings.py`.
- Gateway: `payment-gateway/{presentation/schemas/authorize.py,application/payments/authorize_payment.py,infrastructure/iso/{message_builder,packer,response_mapper,tcp_processor}.py,config/settings.py}`.
- Procesador: `payment_processor/legacy/bin/{auth_thread.c,auth_mycli.c}`,
  `payment_processor/legacy/include/auth_kig.h`.

**Pruebas manuales.** [`test_cases_ventas_ui.md`](test_cases_ventas_ui.md)
(serie `TC-V-###`, una por hallazgo de este documento).

**Documentos relacionados.**
- [`errores-backend.md`](errores-backend.md) (contrato común, cadena de
  propagación, matriz de decisión y plantilla de ficha).
- [`errores-api.md`](errores-api.md) · [`errores-gateway.md`](errores-gateway.md) ·
  [`errores-procesador.md`](errores-procesador.md) · [`errores-mobile.md`](errores-mobile.md)
  · [`errores-hallazgos.md`](errores-hallazgos.md) (BN-01…BN-18).
- [`test_cases_mobile.md`](test_cases_mobile.md) · [`test_cases_api.md`](test_cases_api.md) ·
  [`test_cases_gateway.md`](test_cases_gateway.md) · [`test_cases_index.md`](test_cases_index.md) ·
  [`test_cases_hallazgos.md`](test_cases_hallazgos.md).
- [`alcance.md`](alcance.md) (§2.1 flujo de venta, §3 aclaraciones de producto) ·
  [`entry-mode.md`](entry-mode.md) · [`demo-transaccion-aprobada.md`](demo-transaccion-aprobada.md) ·
  [`gaps.md`](gaps.md) (G-P0-19…G-P2-09).







