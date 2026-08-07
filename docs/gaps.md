# Gaps — App Solidaridad

Inventario de brechas entre el [alcance](alcance.md) y el estado del
repositorio. **Actualizar este documento en cada cambio implementado** (ver
`AGENTS.md` en la raíz).

Última revisión: 2026-08-07

> ✅ **Último cambio (2026-08-07):** limpieza de scripts de demo y docs.
> - `payment_processor/Makefile`: nuevo target `make recarga` que aplica
>   `docker/mysql/recarga_demo.sql` contra el contenedor MySQL (ya no se corre
>   SQL a mano).
> - `payment_processor/docker/mysql/recarga_demo.sql`: la recarga de
>   `4111111111111111` pasó de `importe=0.00` a `-100000.00` (negativo) para que
>   el autorizador la detecte como recarga (`obtieneUltimaRecarga()` busca
>   `importe < 0`), y se agregó advertencia de que ese PAN cuelga el autorizador.
> - `docs/demo-transaccion-aprobada.md`: se corrigió la afirmación sobre Luhn
>   (API/gateway no validan Luhn, solo formato numérico y longitud 13–19), el
>   link roto `fix_demo.sql` → `03_fix_demo.sql`, y la sección de recarga ahora
>   usa `make -C payment_processor recarga`.
> - `mobile/lib/features/auth/data/auth_repository.dart`: comentario aclarando
>   que el default `05000001` es un terminal real (GOBIERNO) del demo, no un
>   valor solo de desarrollo.

> ✅ **Último cambio:** tabla append-only `transaction_status_events` en la API
> (CREATED / GATEWAY_RESULT / VOID_RESULT / IDEMPOTENT_HIT). Persistencia
> enganchada en create/update/void e idempotent replay; **sin** exposición
> HTTP todavía.


> ✅ **Transacción aprobada (código 00) de punta a punta (2026-06-08):** el
> bloqueo era que el gateway **no enviaba el DE62 (`numero_comprobante`)**, y el
> autorizador lo usa en `valida_cupon_dup()`/`valida_cupon()` como
> `numero_comprobante = %s` (sin comillas), generando un error de sintaxis SQL.
> Se agregó `field_62` y el bit 62 al bitmap en
> `payment-gateway/infrastructure/iso/message_builder.py`. Ver G-P0-19.
>
> **DE62 = parte numérica del ID de transacción (2026-07-08):** el DE62
> (`numero_comprobante`) dejó de usar el STAN y ahora lleva la sección numérica
> del ID de transacción (`OP-YYMMDD-NNNNNNNN` → `NNNNNNN`). El `transaction_number`
> viaja desde la API (`AuthorizeRequest`) hasta el gateway (`AuthorizeCommand`) y
> se extrae con `_transaction_number()` en
> `payment-gateway/infrastructure/iso/message_builder.py`. Ver G-P0-19.
>
> **Inicialización automática del demo (2026-07-08):** el script de preparación
> de datos de prueba `payment_processor/docker/mysql/fix_demo.sql` se renombró a
> `03_fix_demo.sql` y se montó en `/docker-entrypoint-initdb.d/` desde
> `payment_processor/docker-compose.yml`, junto a `01_schema.sql` y
> `02_seed.sql.gz`. Ahora MySQL lo ejecuta automáticamente en cada corrida en
> limpio (volumen nuevo), sin necesidad de correrlo a mano. Ver G-P0-18.
>
> **Nota de tarjeta de demo:** la tarjeta que aprueba en vivo es
> `6063007014007401` (con saldo en producto 993). El `03_fix_demo.sql` y G-P0-18
> referencian `6063007014007403` (la original de Lillo, que no está dada de alta
> con saldo en el autorizador); mantener `6063007014007401` como la tarjeta de
> referencia para el demo. La API y el gateway **no** validan Luhn (solo formato
> numérico y longitud 13–19), por lo que el rechazo de `6063007014007403` no se
> debe a Luhn.

>
> **Bug conocido (2026-06-08):** la tarjeta `4111111111111111` (VISA de prueba)
> **cuelga el autorizador** en `calcula_saldo_vivo()` (bug del código C) y Docker
> reinicia el contenedor. **No usar para el demo.** Usar siempre
> `6063007014007401`.
>
> **Ajuste de consistencia operativa POS mobile (2026-08-06):**
> `mobile/lib/features/sales/presentation/widgets/sale_review_content.dart` — el
> resumen de cantidad ya no muestra `.0` cuando la cantidad es entera; por
> ejemplo, `2 unidades` en lugar de `2.0 unidades`, preservando decimales reales
> cuando existan.

Leyenda de estado: `open` · `partial` · `done`

---

## Resumen

El backend local (API → gateway → procesador) cubre buena parte del corazón de

autorización ISO. La app Flutter sigue el contrato borrador de estimación
(ingreso manual, `/v1/sales/gas`, historial mock) y **no** integra hardware
Verifone (banda + térmica).

---

## P0 — Bloquean MVP operable

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P0-01 | Mobile no usa el contrato vivo de ventas | done | Cliente: `POST /v1/transactions` (migrado desde `/v1/sales/gas`). Payload alineado: `product`, `amount` (string), `card_number`, `cvv`, `expiration_date` (opcional). Ver `mobile/lib/features/sales/data/sales_repository.dart`. |
| G-P0-02 | Auth mobile incompleto vs API | partial | Login/register ya envían `installation_id` y manejan `must_change_password`. Pendiente: change-password sin Bearer. |
| G-P0-03 | Token de venta no enlazado a sesión real | done | `SalesCubit.loadHistory()`, `sendIsoMessage()` y `fetchProducts()` reciben el token JWT desde `AuthCubit`. Ver `mobile/lib/features/sales/presentation/cubit/sales_cubit.dart`, `mobile/lib/features/sales/presentation/screens/sale_review_screen.dart`, `mobile/lib/features/sales/presentation/screens/sale_form_screen.dart`. |
| G-P0-04 | Sin listado/detalle de transacciones en API | done | `GET /v1/transactions` con paginación (limit/offset) implementado, filtrado por terminal (`installation_id`). Frontend reemplazó mock por datos reales. Ver `api/presentation/controllers/transactions_controller.py` y `mobile/lib/features/history/presentation/screens/sales_history_screen.dart`. |
| G-P0-05 | Producto/especie y campos de tarjeta desalineados | done | Mobile: `ProductSelector` con catálogo de `GET /v1/products`. Payload envía `product`, `card_number`, `cvv`, `expiration_date`. Ya no envía `card_holder` ni `terminal_origin`. |
| G-P0-06 | Lectura de banda (Verifone) | open | Solo ingreso por teclado. Sin SDK/plugin/canal nativo MSR. Gateway DE22 fijo manual. |
| G-P0-07 | Impresión de ticket en térmica (Verifone) | open | Solo comprobante en UI (`SaleDetailTicket` / status). Sin API de impresora / SDK. |
| G-P0-08 | `installation_id` desde config de terminal | partial | Se inyecta vía `--dart-define=INSTALLATION_ID=...` en build. **2026-06-08:** el default pasó de `dev-term` a `05000001` en `mobile/lib/features/auth/data/auth_repository.dart` (el terminal `dev-term` no existe en `terminales` del autorizador → código 89). **2026-08-07:** se aclaró el comentario del default para indicar que `05000001` es un terminal real (GOBIERNO) del demo, no un valor solo de desarrollo. Pendiente: lectura runtime desde config del device. |

| G-P0-09 | Android bloquea conexiones HTTP / red a backend local | done | Faltaban `INTERNET` permission y `usesCleartextTraffic="true"` en `AndroidManifest.xml` de main. También se agregó CORS (`CORSMiddleware`) en API para compatibilidad web futura. |
| G-P0-10 | ApiConfig usaba IP fija `10.0.2.2` incompatible con web y dispositivos reales | done | `SalesRepository` ahora usa `ApiConfig.baseUrl` igual que `AuthRepository`. URL hardcodeada a prod reemplazada por la configuración de ambiente (`--dart-define` o detección de plataforma). Ver `mobile/lib/features/sales/data/sales_repository.dart`. |
| G-P0-11 | Política de contraseñas débil (solo valida longitud, no complejidad) | open | TC-010: contraseña `"12345678"` (solo números) fue aceptada en registro. La política solo valida mínimo 8 caracteres. No requiere mayúsculas, minúsculas, números ni símbolos. Ver hallazgo #8 en `docs/test_cases.md`. |
| G-P0-16 | `must_change_password` no se forzaba en registros nuevos | done | **Fix aplicado (2026-08-03):** `register_user.py` seteaba `must_change_password=False` siempre, impidiendo forzar el cambio de contraseña en el primer login. Se corrigió a `True` en `api/application/auth/register_user.py` línea 62. Tests actualizados en `test_register_user.py` y `test_auth_register_http.py`. Ver hallazgo #6 en `docs/test_cases.md`. |
| G-P0-12 | Endpoint de detalle de transacción no implementado | open | `GET /v1/transactions/{id}` no existe. Solo hay listado (`GET /v1/transactions`) y creación (`POST /v1/transactions`). La app mobile podría necesitarlo para mostrar detalle desde el historial. Ver hallazgo #9 en `docs/test_cases.md`. |
| G-P0-13 | Tests automatizados del gateway fallan por código 96 | done | **Fix aplicado (2026-08-04):** los tests `test_authorize_http_approved_mock` y `test_authorize_http_declined_mock` ahora fuerzan el `MockIsoProcessor` vía `dependency_overrides` en `payment-gateway/tests/test_authorize_http.py`, haciéndolos deterministas independientemente del `.env` local (`ISO_TRANSPORT=tcp`). `make check` pasa: lint ✓, typecheck ✓, 34 tests ✓, cobertura 98.75% ✓. Ver hallazgo #20 en `docs/test_cases.md`. |
| G-P0-14 | Procesador no setea DE39 (código de respuesta) en varios escenarios | open | El procesador C solo setea `respcode_39` en algunos casos (ej: código 05 para TRANS_DENY). En otros escenarios (monto $100, terminal inválida, tarjeta sin saldo, tarjeta vencida) el DE39 queda vacío. El gateway interpreta DE39 vacío como código 96 (`response_mapper.py` línea 22: `code = (iso.respcode_39 or "").strip() or "96"`). Esto causa que el gateway devuelva `FAILED` en lugar de `DECLINED` con el código correcto. Requiere fix en `auth_thread.c` para asegurar que DE39 siempre tenga un código de respuesta válido. |
| G-P0-15 | Flujo completo app → API → gateway → procesador funciona en dispositivo real | done | TC-067 (venta rechazada) mostró "Transacción Rechazada" con código 51 (Fondos Insuficientes) en Motorola ZY22FSJKKV. La app se compiló con `--dart-define=API_BASE_URL=http://192.168.0.4:8000/v1`. El problema de conexión del hallazgo #18 era específico del emulador (IP `10.0.2.2`). El ANR del hallazgo #17 tampoco se reproduce en dispositivo real. Ver hallazgo #21 en `docs/test_cases.md`. |

| G-P0-17 | App mobile no maneja tokens expirados (401) | done | **Fix aplicado (2026-08-05):** `SalesRepository` y `AuthRepository` detectan 401 y propagan `SessionExpiredException` / `sessionExpired=true`. Los cubits emiten `SalesSessionExpired` / `AuthSessionExpired` y las pantallas (`SaleProcessingScreen`, `SalesHistoryScreen`, `SaleFormScreen`, `ChangePasswordScreen`) hacen logout y redirigen a login limpiando la pila. Ver hallazgo #22 y TC-060 en `docs/test_cases.md`. |
| G-P0-18 | Transacción de demo siempre rechazada por comercio inválido en autorizador | done | **Fix aplicado (2026-06-08):** el terminal `05000001` (installation_id de la app) tenía `cod_comercio='000000'` en `terminales`, que no existe en `sgas_comercio`, por lo que `valida_comercio()` rechazaba siempre (`COMER_DES_SUP`). Se corrigió a `012502` (GOBIERNO, `situacion='V'`). Además se dio saldo (2000) y recarga (4000) a la tarjeta `6063007014007403` (Lillo) en producto `993` para que `venta_cupon()` apruebe ventas de hasta $200. Cambios en seed `payment_processor/docker/mysql/02_seed.sql.gz` y script `payment_processor/docker/mysql/03_fix_demo.sql`. **2026-07-08:** `03_fix_demo.sql` se monta en `/docker-entrypoint-initdb.d/` desde `docker-compose.yml`, por lo que se aplica automáticamente en cada corrida en limpio (reconstruir con `make reset`); ya no se corre a mano. |

| G-P0-19 | Gateway no enviaba DE62 (`numero_comprobante`) → error SQL en autorizador | done | **Fix aplicado (2026-06-08):** el gateway no empaquetaba el DE62, y el autorizador lo usa en `valida_cupon_dup()`/`valida_cupon()` como `numero_comprobante = %s` (sin comillas), generando error de sintaxis SQL (`near 'AND tipo_mensaje = '0200'...'`) y respuesta 96. Se agregó `field_62` y el bit 62 al bitmap en `payment-gateway/infrastructure/iso/message_builder.py` (`build_purchase_request`). **2026-07-08:** el DE62 dejó de usar el STAN y ahora lleva la parte numérica del ID de transacción (`OP-YYMMDD-NNNNNNNN` → `NNNNNNN`), propagado desde la API (`AuthorizeRequest.transaction_number`) hasta el gateway (`AuthorizeCommand.transaction_number`) y extraído con `_transaction_number()`. `make check` pasa en API (96 tests, 94.92%) y gateway (34 tests, 98.76%). |




---


## P1 — Fase 0 / robustez incompleta

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P1-01 | Usuario habilitado / altas solo desde central | done | Decisión de producto: los usuarios son dados de alta únicamente por la empresa (vía Postman/central). El formulario de registro de la app mobile no se usará en producción. El endpoint `POST /v1/auth/register` se mantiene para que la empresa pueda registrar usuarios vía Postman. Ver comentarios en TC-007 a TC-013 y TC-057/TC-058 en `docs/test_cases.md`. |
| G-P1-02 | Reintentos e idempotencia en mobile | partial | API usa `Idempotency-Key` y estados `PENDING`/`UNKNOWN`. Mobile genera y envía `Idempotency-Key` (timestamp+random) en cada `POST /v1/transactions`. **Pendiente:** (1) reintentar con la misma clave ante timeout/error idempotente — la `SaleStatusScreen` solo tiene botón "FINALIZAR", no "Reintentar" (hallazgo #24); (2) manejar status 202 (ACCEPTED). Falta botón "Reintentar" en `sale_status_content.dart` que reenvíe con la misma `Idempotency-Key`. Ver TC-069 en `docs/test_cases.md`. |
| G-P1-03 | Logs de auditoría en gateway (sin datos sensibles) | open | Falta capa de audit/masking de request-response. |
| G-P1-07 | Fallback silencioso en errores de red de mobile | open | `SalesRepository.fetchProducts()` devuelve productos default hardcodeados ante cualquier excepción. `SalesRepository.fetchHistory()` devuelve lista vacía. Ningún repositorio muestra mensaje de error ni opción de reintentar al usuario. TC-062 y TC-072 esperaban "mensaje de error y opción de reintentar", pero la app usa fallback silencioso. Considerar agregar indicador visual cuando se usan datos fallback. Ver hallazgo #23 en `docs/test_cases.md`. |
| G-P1-04 | Deploy AWS + conectividad on-prem | open | Solo stack local (`make dev`). Sin IaC/deploy ni IP fija documentada en repo. |
| G-P1-05 | Base URL / ambientes en mobile | done | `ApiConfig` con `--dart-define=API_BASE_URL=...`; default apunta a localhost. |
| G-P1-06 | Entry mode ISO acorde al modo de captura | open | DE22 fijo `012` (manual). Falta track/swipe cuando haya banda. |
| G-P1-08 | UI mobile de anulación | open | Backend `POST /v1/transactions/{tn}/void` listo; la app aún no ofrece flujo de anulación con reingreso de tarjeta. |
| G-P1-09 | Reverso automático (MTI `0400`) ante `UNKNOWN`/timeout | open | Fuera del alcance de la anulación de comercio. El procesador soporta `reverso()`; gateway/API no lo exponen. |
| G-P1-10 | Historial de estados de transacción (audit trail) | partial | Tabla `transaction_status_events` + escritura en `TransactionRepository` (`CREATED`, `GATEWAY_RESULT`, `VOID_RESULT`, `IDEMPOTENT_HIT`). Migración `20260807_0006`. **Pendiente:** exposición API/detalle (cuando se priorice; no en esta etapa). Distinto de G-P1-03 (audit ISO del gateway). |

---

## P2 — Post-MVP / mejoras

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P2-01 | UX: manual solo como fallback | open | Hoy el manual es el único flujo. |
| G-P2-02 | Track2 en authorize cuando hay swipe | open | Packer puede soportar DE35 en tests; el builder de purchase no envía track desde swipe. |
| G-P2-03 | App usuario + QR | open | Módulo posterior del PDF; no iniciado. |
| G-P2-04 | Web de observabilidad | open | Módulo posterior del PDF; no iniciado. |
| G-P2-05 | OCR / NFC / iOS | open | Extras del PDF; fuera del MVP Verifone Android. |

---

## Ya cubierto (referencia)

Para no reabrir gaps resueltos, mantener aquí lo cerrado con evidencia breve.

| Ítem | Notas |
|------|-------|
| Auth API (login / register / change-password + JWT) | Implementado en `api/` |
| `POST /v1/transactions` + persistencia + llamada a gateway | Implementado en `api/` |
| `POST /v1/transactions/{tn}/void` (anulación con reingreso de tarjeta) | Implementado en `api/`; status `VOIDED`; DE62 ticket = sufijo de `transaction_number` |
| `GET /v1/transactions` (listado paginado por terminal) | Implementado en `api/` |
| Catálogo `GET /v1/products` | Implementado en `api/` con auth Bearer; cada producto incluye `code`, `label` y el objeto `unit` con textos `singular` y `plural`. |
| Gateway `POST /v1/authorize` → ISO → authkig/mock | Implementado en `payment-gateway/` |
| Gateway `POST /v1/void` → ISO anulación (`0200`/`020000`) | Implementado en `payment-gateway/` |
| Procesador caído ≠ resultado ambiguo | Gateway: `ProcessorUnreachable` (fallo de connect) → 503; `ProcessorUnavailable` (falla tras enviar el ISO) → 502. API: 503 → `FAILED`, 502 → `UNKNOWN`. Ver `payment-gateway/infrastructure/iso/tcp_processor.py` y `api/infrastructure/payments/http_gateway.py`. |
| Validación de PAN compatible con tarjetas MOD-TDF | API y gateway validan únicamente formato numérico y longitud (13–19); no aplican Luhn. Cubierto con el PAN del POC `6063001014007403`. |
| Procesador valida terminal vigente (DE41) | `payment_processor` / authkig |
| UI mobile de login, venta, review, status, historial (mock) | `mobile/` — login y nueva venta con tamaños de inputs, selector y botón ajustados a operación POS Verifone; contrato/backend incompletos (ver P0) |
| `installation_id` unificado a terminal id (8 chars) en API | Modelo/seed alineados; falta wiring desde device (G-P0-08) |
| Base URL / ambientes en mobile | `ApiConfig` con `--dart-define` en `mobile/lib/core/config/api_config.dart` |
| RegisterScreen conectado al backend | `mobile/lib/features/auth/presentation/screens/register_screen.dart` usa `BlocConsumer` + `AuthCubit.register()` |
| Status screen con 3 estados (aprobado/rechazado/error conexión POSNET) | `PaymentResult` enum + `connectionError` flag en `SaleResponse`; naranja para pérdida de conectividad POSNET |
| ProductSelector con catálogo del backend | `ProductSelector` widget consume `GET /v1/products` y muestra productos de gas (GARRAFA_10, etc.) en vez de ARS/USD. Payload de venta envía `product`. |
| Token de venta enlazado a sesión real | `sendIsoMessage()`, `fetchProducts()` y `loadHistory()` usan el token JWT desde `AuthCubit`. Ver `mobile/lib/features/sales/presentation/cubit/sales_cubit.dart`, `mobile/lib/features/sales/presentation/screens/sale_review_screen.dart`, `mobile/lib/features/sales/presentation/screens/sale_form_screen.dart`. |
| Manejo de tokens expirados (401) en mobile | `SalesRepository`/`AuthRepository` detectan 401 y propagan `SessionExpiredException`/`sessionExpired=true`; cubits emiten `SalesSessionExpired`/`AuthSessionExpired`; pantallas hacen logout y redirigen a login. Ver G-P0-17. |
| Status history append-only (persistencia) | Tabla `transaction_status_events`; eventos en create/gateway/void e `IDEMPOTENT_HIT` en replay. Sin API. Ver G-P1-10. |


---

## Cómo actualizar este archivo

Al implementar un cambio:

1. Marcar el gap correspondiente (`open` → `partial` o `done`).
2. Ajustar la columna de evidencia (archivos, endpoints, comportamiento).
3. Si se cierra por completo, mover un resumen a **Ya cubierto** y dejar la fila
   en `done` o eliminarla si preferís historial mínimo.
4. Si aparece un gap nuevo descubierto en la implementación, agregarlo con ID
   nuevo (`G-P0-xx` / `G-P1-xx` / `G-P2-xx`) y prioridad coherente.
5. Actualizar la fecha de **Última revisión**.
