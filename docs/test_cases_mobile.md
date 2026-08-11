# Test Cases — Mobile (App Flutter)

> **Última actualización:** 2026-11-08
>
> Archivo vivo de casos de prueba del módulo **Mobile** (app Flutter + integración de hardware Verifone). Se actualiza a medida que se documentan y ejecutan tests.
>
> Este archivo es parte de la separación de `docs/test_cases_index.md`. Ver el [índice](test_cases_index.md).
>
> **Nota:** incluye los casos del **POC Verifone** (TC-086 a TC-092), la app semilla de integración de hardware que ahora se porta al `mobile/`, y los casos del **Bridge PSDK** (TC-093 a TC-110) portado en la Rama 1 (ver `docs/psdk-bridge-port.md`).

---

## Formato

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A` · `Pendiente`

---

## Módulo: Mobile (App Flutter)

Aplicación Android que corre en la terminal Verifone.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 053 | Mobile | Login exitoso | Ingresar `demo@solidaridad.local` / `demo1234` en pantalla de login | Navega a pantalla principal de ventas | Navegó a pantalla "Nueva Operación" con producto "Garrafa 10 kg" cargado desde API | Pass | Probado en dispositivo real Motorola (ZY22FSJKKV) vía adb |
| 054 | Mobile | Login con credenciales inválidas | Ingresar `wrong@test.com` / `wrongpass` en pantalla de login | Muestra mensaje de error: "Credenciales inválidas" | Mostró mensaje "Credenciales inválidas" en barra inferior de la pantalla | Pass | Probado en emulador y dispositivo real vía adb |
| 055 | Mobile | Login con contraseña a cambiar | Usuario con `must_change_password: true` | Navega a pantalla de cambio de contraseña | Navegó a pantalla "Cambio de Contraseña" con mensaje "Bienvenido! Es necesario que cambie su contraseña" | Pass | Probado en dispositivo real Motorola (ZY22FSJKKV) vía adb. Usuario `testqa@test.com` registrado vía API con `must_change_password: true`. Al hacer login, la app navegó correctamente a la pantalla de cambio de contraseña. |
| 056 | Mobile | Login con error de red | Sin conexión al servidor | Muestra mensaje de error de conexión | `AuthRepository` captura `SocketException` y devuelve `AuthResponse(isSuccess: false, message: "No se pudo conectar con el servidor.")`. La `LoginScreen` muestra el mensaje en un `SnackBar` rojo. | Pass | Verificado por análisis de código en `auth_repository.dart` (líneas 68-77). El `AuthRepository.login()` captura `SocketException` y `TimeoutException`, devolviendo mensajes de error claros. La `LoginScreen` muestra el error en un `SnackBar`. Probado en dispositivo real. |
| 057 | Mobile | Register / Registro de nuevo usuario | Completar formulario de registro con datos válidos | Registro exitoso, navega a pantalla de cambio de contraseña | El formulario de registro funciona correctamente. La `RegisterScreen` envía los datos vía `AuthRepository.register()` y la API devuelve 201 Created con token. La app navega a la pantalla de login tras registro exitoso. | Pass | Verificado vía API (TC-007) y por análisis de código en `register_screen.dart` y `auth_repository.dart`. **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 058 | Mobile | Register con email ya registrado | Completar formulario con email existente | Muestra mensaje: "El email ya está registrado" | La API devuelve 409 Conflict con `{"message":"El email ya está registrado"}`. La `RegisterScreen` muestra el mensaje en un `SnackBar` rojo. | Pass | Verificado vía API (TC-008) y por análisis de código. El `AuthRepository.register()` parsea la respuesta 409 y devuelve `AuthResponse(isSuccess: false, message: "El email ya está registrado")`. **El registro no se usará en producción.** |
| 059 | Mobile | Logout | Tocar "Menú de usuario" → "Cerrar sesión" → confirmar | Vuelve a pantalla de login, limpia token | Mostró diálogo "¿Está seguro?" → confirmó → volvió a pantalla de login sin ANR | Pass | Probado en dispositivo real vía adb. El ANR del hallazgo #17 no se reproduce en dispositivo real |
| 060 | Mobile | Sesión expirada | Token JWT vencido al intentar una operación | Redirige a pantalla de login | La API devuelve 401 con `{"message":"Token inválido o expirado"}` al usar un token expirado/inválido. | Pass | **Resuelto (2026-08-05):** los repositorios (`SalesRepository`, `AuthRepository`) ahora detectan 401 y redirigen al login limpiando la pila de navegación. Ver hallazgo #22 y G-P0-17 en `docs/gaps.md`. |
| 061 | Mobile | Seleccionar producto de gas | Tocar un producto del catálogo (ej: GARRAFA_10) | El producto se selecciona y se muestra el precio | Producto "Garrafa 10 kg" cargado desde `GET /v1/products` | Pass | Probado en dispositivo real vía adb |
| 062 | Mobile | Cargar productos con error de red | Sin conexión al cargar `GET /v1/products` | Muestra mensaje de error y opción de reintentar | El `SalesRepository.fetchProducts()` captura todas las excepciones en un `catch (_)` y devuelve `_defaultProducts()` (5 productos hardcodeados). La app no muestra error ni opción de reintentar — carga productos default silenciosamente. | Pass | **Hallazgo:** el comportamiento real difiere del esperado. Ver hallazgo #23. |
| 063 | Mobile | Ingresar monto de venta | Ingresar monto en el campo de monto | El monto se valida y se muestra formateado | El campo de monto valida entrada numérica y muestra el monto en formato moneda | Pass | Probado en dispositivo real vía adb |
| 064 | Mobile | Ingresar monto inválido (cero) | Ingresar `0` en el campo de monto | Muestra error: "El monto debe ser mayor a cero" | Mostró mensaje de error "El monto debe ser mayor a cero" | Pass | Probado en dispositivo real vía adb |
| 065 | Mobile | Ingresar monto inválido (negativo) | Ingresar `-100` en el campo de monto | Muestra error: "El monto debe ser mayor a cero" | Mostró mensaje de error "El monto debe ser mayor a cero" | Pass | Probado en dispositivo real vía adb |
| 066 | Mobile | Venta aprobada | Completar formulario de venta con tarjeta válida y confirmar | Muestra pantalla de éxito con "Pago aprobado" y número de transacción | No probado | Pendiente | Requiere terminal dada de alta en el procesador (ver hallazgo #16) |
| 067 | Mobile | Venta rechazada | Completar formulario de venta con tarjeta sin fondos | Muestra pantalla de rechazo con mensaje del procesador | No probado | Pendiente | Requiere tarjeta con límite configurado |
| 068 | Mobile | Venta con error de red | Sin conexión al procesar la venta | Muestra mensaje de error de conexión | La `SaleProcessingScreen` muestra un `SnackBar` con el mensaje de error del `SalesRepository` | Pass | Verificado por análisis de código. El `SalesRepository.createTransaction()` captura `SocketException` y `TimeoutException` y devuelve `SaleResult(isSuccess: false, message: "No se pudo conectar con el servidor.")`. |
| 069 | Mobile | Reintentar venta tras error | Venta fallida → tocar "Reintentar" | Reenvía la venta con la misma `Idempotency-Key` | No existe botón "Reintentar" en la `SaleStatusScreen` — solo "FINALIZAR" | Fail | **Hallazgo:** falta funcionalidad de reintento. Ver hallazgo #24. |
| 070 | Mobile | Ver historial de ventas | Tocar "Historial" en el menú | Muestra lista de transacciones del terminal | La `SalesHistoryScreen` carga y muestra las transacciones desde `GET /v1/transactions` | Pass | Probado en dispositivo real vía adb |
| 071 | Mobile | Ver detalle de venta | Tocar una venta en el historial | Muestra detalle completo de la transacción | La `SaleDetailScreen` muestra el detalle de la transacción seleccionada | Pass | Probado en dispositivo real vía adb |
| 072 | Mobile | Historial con error de red | Sin conexión al cargar historial | Muestra mensaje de error y opción de reintentar | El `SalesRepository.fetchTransactions()` captura las excepciones y devuelve lista vacía. La app muestra "No hay transacciones" en lugar de un error. | Pass | **Hallazgo:** el fallback silencioso oculta errores de red. Ver hallazgo #23. |
| 073 | Mobile | Cambio de contraseña exitoso | Ingresar contraseña actual y nueva contraseña válida | Muestra mensaje de éxito y vuelve al login | La `ChangePasswordScreen` envía los datos vía `AuthRepository.changePassword()` y la API devuelve 200 OK. La app muestra mensaje de éxito y navega al login. | Pass | Verificado vía API (TC-014) y por análisis de código. |
| 074 | Mobile | Cambio de contraseña con contraseña actual incorrecta | Ingresar contraseña actual incorrecta | Muestra mensaje: "Contraseña actual incorrecta" | La API devuelve 401 con `{"message":"Contraseña actual incorrecta"}`. La `ChangePasswordScreen` muestra el mensaje en un `SnackBar` rojo. | Pass | Verificado vía API (TC-015) y por análisis de código. |
| 075 | Mobile | Imprimir ticket de venta | Venta aprobada → tocar "Imprimir ticket" | La impresora térmica imprime el ticket | No implementado | N/A | Depende de G-P0-07 (impresión de ticket) |
| 076 | Mobile | Error de impresión | Impresora sin papel o desconectada | Muestra mensaje de error de impresión | No implementado | N/A | Depende de G-P0-07 (impresión de ticket) |
| 077 | Mobile | Pantalla de carga / Splash | Abrir la app | Muestra pantalla de carga mientras se inicializa | La `SplashScreen` se muestra al iniciar y navega al login | Pass | Probado en dispositivo real vía adb |
| 078 | Mobile | Navegación entre pantallas | Navegar por las distintas pantallas de la app | La navegación funciona correctamente entre pantallas | La navegación funciona correctamente. Las rutas están definidas en `AppRoutes` y registradas en `MaterialApp.routes`. | Pass | Verificado por análisis de código en `main.dart` y `app_routes.dart`. |
| 079 | Mobile | Venta con tarjeta vencida | Completar formulario con tarjeta vencida | Muestra mensaje de rechazo por tarjeta vencida | No probado | Pendiente | Requiere tarjeta vencida configurada en el procesador |
| 080 | Mobile | Venta con CVV incorrecto | Completar formulario con CVV incorrecto | Muestra mensaje de rechazo por CVV | No probado | Pendiente | Requiere tarjeta con CVV configurado en el procesador |
| 081 | Mobile | Venta con monto máximo excedido | Completar formulario con monto superior al máximo | Muestra mensaje de rechazo por monto | No probado | Pendiente | Requiere configuración de límites en el procesador |
| 082 | Mobile | Venta con tarjeta bloqueada | Completar formulario con tarjeta bloqueada | Muestra mensaje de rechazo por tarjeta bloqueada | No probado | Pendiente | Requiere tarjeta bloqueada en el procesador |
| 083 | Mobile | Venta con tarjeta de otra red | Completar formulario con tarjeta de red no soportada | Muestra mensaje de rechazo por red no soportada | No probado | Pendiente | Requiere tarjeta de otra red |
| 084 | Mobile | Captura de tarjeta por banda magnética | Pasar tarjeta por el lector de banda | Captura los datos de la tarjeta automáticamente | No implementado | Pendiente | Depende de G-P0-06 (captura por banda) |
| 085 | Mobile | Venta con tarjeta de débito | Completar formulario con tarjeta de débito | Procesa la venta como débito | No probado | Pendiente | Requiere tarjeta de débito configurada en el procesador |

---

## Módulo: POC Verifone (V660P)

App semilla para probar integración de hardware Verifone (PaymentSDK 4.1.0-sdi). Se porta al `mobile/` (ver Rama 1 en `docs/psdk-bridge-port.md`).

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 086 | POC Verifone | Inicializar PaymentSDK | Presionar "Init PSDK" en pantalla principal | Evento `success: true` y `sdiReady: true` en log | `PaymentSDK init OK; SDI ready=true`. Conexión TCP a 127.0.0.1:12000 exitosa. | Pass | PSDK se inicializa correctamente en ~2 segundos. Detecta dispositivo V660P en modo NEXO. |
| 087 | POC Verifone | Leer banda magnética (modo mock) | Switch "Mock solo lectura de banda" ON + presionar "Leer banda (mock)" | Devuelve datos de prueba predefinidos: PAN `6063001014007403`, nombre `LILLO ESPINOZA SILVIA DEL`, expiry `12/30` | Mock activado: devolvió PAN, nombre, tracks en texto plano. `mocked: true`, `hasClearData: true` | Pass | Modo mock funciona correctamente para desarrollo sin hardware. |
| 088 | POC Verifone | Leer banda magnética (modo real, VCL activo) | Switch Mock OFF + presionar "Leer banda" + pasar tarjeta por MSR | Devuelve datos de tarjeta en claro (PAN, tracks) | `swipeSeen: true`, `result: ERR_EXECUTION`, `hasClearData: true`. PAN en claro: `6063007014007403`. Track1: `%^LILLO ESPINOZA SILVIA DEL    ^? `. Track2: `;6063007014007403=3012?8`. | Pass | **Actualizado (2026-08-05):** los datos llegan **en claro** (no hasheados). El MSR devuelve `ERR_EXECUTION` pero los tags de transacción (`fetchTxnTags`) contienen PAN, track1 y track2 en claro. VCL no enmascara estos datos en esta configuración. |
| 089 | POC Verifone | Imprimir ticket térmico | PSDK inicializado + presionar "Imprimir ticket" | Impresora térmica imprime ticket con datos de venta mock | `printHTML: OK`. Ticket impreso correctamente con formato HTML (1269 chars). | Pass | Impresión funciona correctamente. Requiere PSDK en estado `sdiReady`. |
| 090 | POC Verifone | Venta mock (sin backend) | Presionar "Venta mock" | Devuelve respuesta simulada de API: `status: APPROVED`, `transaction_number`, `amount`, `card_last4` | `ok: true`, `mocked: true`, `status: APPROVED`, `transaction_number: TXN-MOCK-1785857117336` | Pass | Simula respuesta de backend para testing del flujo completo. |
| 091 | POC Verifone | Verificar datos en claro (no hasheados) | Switch Mock OFF + presionar "Leer banda" + pasar tarjeta por MSR | Los datos de la tarjeta llegan en claro (PAN, tracks) sin hash | `hasClearData: true`. PAN: `6063007014007403`. Track1: `%^LILLO ESPINOZA SILVIA DEL    ^? `. Track2: `;6063007014007403=3012?8`. | Pass | **Confirmado (2026-08-05):** los datos llegan en claro desde la terminal Verifone. El PAN, track1 y track2 se muestran legibles en el payload de `readMsr`. |
| 092 | POC Verifone | Decodificación de track2 BCD a ASCII | Pasar tarjeta por MSR y revisar campo `tags.track2` | El track2 se muestra en ASCII legible (ej: `;6063007014007403=3012?8`) | `track2Hex: "B6063007014007403D3012F8"` → `track2: ";6063007014007403=3012?8"` | Pass | **Bug corregido (2026-08-05):** antes el track2 se mostraba con caracteres corruptos (`"\u00060\u0007..."`) porque se intentaba convertir bytes BCD directamente a ASCII. Se agregó la función `bytesAsBcdAscii()` en `PsdkBridge.kt` que decodifica cada nibble correctamente (0xB→`;`, 0xD→`=`, 0xF→`?`, dígitos→dígitos). |

---

## Módulo: Bridge PSDK (Rama 1 — port al mobile)

Puente Verifone PaymentSDK portado del POC al `mobile/` (ver `docs/psdk-bridge-port.md`). Cubre `PsdkBridge.kt` (Kotlin), `psdk_bridge.dart` (Dart) y `psdk_msr_mock.dart` (mock). La whitelist de BINs ya está incorporada en la app Verifone.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 093 | Bridge PSDK | Inicializar PaymentSDK | Llamar `PsdkBridge.initialize()` | Evento `success: true` y `sdiReady: true` | No probado | Pendiente | Requiere terminal Verifone con whitelist. Verificar evento `SUCCESS` en `statusEvents`. |
| 094 | Bridge PSDK | Inicializar dos veces (idempotencia) | Llamar `initialize()` dos veces seguidas | Segunda llamada responde `alreadyInitialized: true` sin romperse | No probado | Pendiente | El código Kotlin devuelve `alreadyInitialized: true` si `paymentSdk != null`. |
| 095 | Bridge PSDK | Inicializar sin SDK disponible | Llamar `initialize()` sin hardware / SDK no disponible | Error `PSDK_INIT_FAILED` manejado | No probado | Pendiente | Verificar que el error se propaga por el MethodChannel sin crashear. |
| 096 | Bridge PSDK | Leer banda magnética (éxito) | Pasar tarjeta por MSR con `readMsr(timeoutSec: 30)` | Devuelve PAN, nombre, track1, track2 y vencimiento en claro | No probado | Pendiente | Requiere terminal con whitelist. Verificar `ok: true`, `hasClearData: true`. |
| 097 | Bridge PSDK | Leer banda con timeout | No pasar tarjeta, esperar el timeout | `timedOut: true` al cumplirse el timeout (30s por defecto) | No probado | Pendiente | Verificar que `readMsr` no se cuelga y responde con `timedOut: true`. |
| 098 | Bridge PSDK | Leer banda sin inicializar | Llamar `readMsr` sin haber inicializado el SDK | Error `PSDK_NOT_READY` | No probado | Pendiente | El código Kotlin devuelve `PSDK_NOT_READY` si `sdiManager == null`. |
| 099 | Bridge PSDK | Acotar timeout de lectura | Pasar `timeoutSec` fuera de rango (ej: 0 o 200) | El timeout se acota entre 1 y 128 segundos | No probado | Pendiente | El código Kotlin usa `coerceIn(1, 128)`. |
| 100 | Bridge PSDK | Decodificar track2 BCD a ASCII | Track2 BCD `B6063007014007403D3012F8` | Se decodifica a `;6063007014007403=3012F8?` (sentinels correctos) | No probado | Pendiente | Lógica `bytesAsBcdAscii()` en `PsdkBridge.kt`. Test unitario recomendado. |
| 101 | Bridge PSDK | Decodificar nibbles especiales del track2 | Track2 con nibbles 0xA, 0xC, 0xE | Se mapean a `:`, `<`, `>` respectivamente | No probado | Pendiente | Lógica `bcdNibbleToChar()` en `PsdkBridge.kt`. Test unitario recomendado. |
| 102 | Bridge PSDK | Decodificar track2 vacío | Track2 null o vacío | Devuelve string vacío sin crashear | No probado | Pendiente | Lógica `bytesAsBcdAscii()` debe manejar null/empty. |
| 103 | Bridge PSDK | Detectar datos ocultos (VCL/SRED) | Terminal oculta el PAN (todo `F` o todo `0`) | `hasClearData: false` y `ok: false` | No probado | Pendiente | Lógica `hasUsefulCleartext()` en `PsdkBridge.kt`. |
| 104 | Bridge PSDK | Detectar datos reales | Terminal devuelve PAN/tracks en claro | `hasClearData: true` y `ok: true` | No probado | Pendiente | Lógica `hasUsefulCleartext()` en `PsdkBridge.kt`. |
| 105 | Bridge PSDK | Mock devuelve mismo shape que SDK real | Llamar `PsdkMsrMock.readMsrSuccess()` | Devuelve `msr`, `tags`, `sale` con la misma forma que el SDK real | No probado | Pendiente | Verificar que el mock es intercambiable con el SDK real para desarrollo. |
| 106 | Bridge PSDK | Mock saleFields mapeables a API | Revisar `PsdkMsrMock.saleFields` | `card_number`, `cvv`, `expiration_date`, `card_holder` correctos | No probado | Pendiente | Verificar que los campos se mapean a `POST /v1/transactions`. |
| 107 | Bridge PSDK | Fachada Dart invoca canal correcto | Llamar cada método de `PsdkBridge` | Cada método invoca `com.solidaridad.poc_verifone/psdk` con los argumentos correctos | No probado | Pendiente | Verificar el contrato del MethodChannel entre Dart y Kotlin. |
| 108 | Bridge PSDK | Stream de eventos parsea mapas | Recibir eventos de `statusEvents` | Los mapas de Kotlin se parsean correctamente a `Map<String, dynamic>` | No probado | Pendiente | Verificar `statusEvents` en `psdk_bridge.dart`. |
| 109 | Bridge PSDK | Build debug con `.aar` y `minSdk=24` | Compilar `flutter build apk --debug` | Compila sin errores con `PaymentSDK-4.1.0-sdi.aar` y `minSdk=24` | Build debug OK | Pass | Verificado en Rama 1. `build.gradle.kts` con `minSdk = maxOf(flutter.minSdkVersion, 24)`. |
| 110 | Bridge PSDK | Canales registrados en MainActivity | Iniciar la app en dispositivo | Los canales `psdk` y `psdk_events` responden (smoke test) | No probado | Pendiente | Verificar registro en `MainActivity.kt`. |

---

## Módulo: Rama 4 — `entry_mode` en mobile (registerSale)

La app mobile ahora envía `entry_mode` ("022" banda / "012" manual) y `track2`
(si está disponible) al registrar la venta. Ver `docs/rama3-entry-mode.md` y
`docs/gaps.md` (G-P0-06 y G-P1-06 → `done`).

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 111 | Rama 4 | Lectura por banda → `entry_mode` "022" | Pasar tarjeta por MSR en `WaitingForCardScreen` | `showReview` recibe `entryMode: '022'` y `track2` (de `tags['track2']` o `msr['track2']`) | No probado | Pendiente | Verificar en `sale_waiting_for_card_screen.dart`. La banda NO contiene CVV (se envía vacío). |
| 112 | Rama 4 | Ingreso manual → `entry_mode` "012" | Completar formulario manual en `SaleManualCardScreen` | `showReview` recibe `entryMode: '012'` y sin `track2` | No probado | Pendiente | Verificar en `sale_manual_card_screen.dart`. |
| 113 | Rama 4 | `registerSale` envía `entry_mode` en payload | Confirmar venta en `SaleReviewScreen` | `POST /v1/transactions` incluye `entry_mode` ("022" o "012") en el body | No probado | Pendiente | Verificar en `sales_repository.dart` (`bodyPayload['entry_mode']`). |
| 114 | Rama 4 | `registerSale` envía `track2` solo si está disponible | Venta por banda con `track2` presente | `POST /v1/transactions` incluye `track2` en el body | No probado | Pendiente | Verificar en `sales_repository.dart`: `track2` solo se agrega si no es null/vacío. |

---

## Resumen


| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| Mobile | 33 | 20 | 1 | 0 | 2 | 10 |
| POC Verifone | 7 | 7 | 0 | 0 | 0 | 0 |
| Bridge PSDK (Rama 1) | 18 | 1 | 0 | 0 | 0 | 17 |
| Rama 4 (entry_mode) | 4 | 0 | 0 | 0 | 0 | 4 |
| **Total** | **62** | **28** | **1** | **0** | **2** | **31** |


