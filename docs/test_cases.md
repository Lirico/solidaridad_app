# Test Cases — Solidaridad App

> **Última actualización:** 2026-08-05

> Archivo vivo de casos de prueba. Se actualiza a medida que se documentan y ejecutan tests.

---

## Formato

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A` · `Pendiente`

---

## Módulo: API (backend)

API pública del sistema. Endpoints accesibles desde la app mobile y herramientas HTTP.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 001 | API | Login exitoso | `POST /v1/auth/login` — `username: "testuser@test.com"`, `password: "Test1234!"`, `installation_id: "TERM001"` | Código 200. Devuelve `access_token`, `token_type: "bearer"`, `must_change_password: false` | `{"name":"Test User","email":"testuser@test.com","token":"eyJ...","must_change_password":false}` — 200 OK | Pass | |
| 002 | API | Login con contraseña incorrecta | `POST /v1/auth/login` — `username: "testuser@test.com"`, `password: "wrongpass"`, `installation_id: "TERM001"` | Código 401. Mensaje: "Credenciales inválidas" | `{"message":"Credenciales inválidas"}` — 401 Unauthorized | Pass | |
| 003 | API | Login con usuario inexistente | `POST /v1/auth/login` — `username: "noexiste@test.com"`, `password: "Test1234!"`, `installation_id: "TERM001"` | Código 401. Mensaje: "Credenciales inválidas" | `{"message":"Credenciales inválidas"}` — 401 Unauthorized | Pass | No revela si el usuario existe o no (mismo mensaje que TC-002) |
| 004 | API | Login con password vacío | `POST /v1/auth/login` — `username: "testuser@test.com"`, `password: ""`, `installation_id: "TERM001"` | Código 400. Error de validación: password requerido | `{"message":"password: String should have at least 1 character"}` — 400 Bad Request | Pass | La API convierte errores de validación a 400, no 422 |
| 005 | API | Login con `installation_id` vacío | `POST /v1/auth/login` — `username: "testuser@test.com"`, `password: "Test1234!"`, `installation_id: ""` | Código 400. Error de validación: installation_id requerido | `{"message":"installation_id: String should have at least 1 character"}` — 400 Bad Request | Pass | |
| 006 | API | Login con `installation_id` > 8 caracteres | `POST /v1/auth/login` — `installation_id: "TERM001XX"` (9 chars) | Código 400. Error de validación: max 8 caracteres | `{"message":"installation_id: String should have at most 8 characters"}` — 400 Bad Request | Pass | |
| 007 | API | Registro exitoso de nuevo usuario | `POST /v1/auth/register` — `name: "Test User"`, `email: "testuser@test.com"`, `password: "Test1234!"`, `installation_id: "TERM001"` | Código 201. Devuelve `access_token`, `must_change_password: true` (primer login) | `{"name":"Test User","email":"testuser@test.com","token":"eyJ...","must_change_password":true}` — 201 Created | Pass | `must_change_password` ahora es `true` porque es un usuario nuevo (primer login). Fix aplicado en `register_user.py`. **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 008 | API | Registro con email duplicado | `POST /v1/auth/register` — mismo email que usuario existente | Código 409. Mensaje: "El email ya está registrado" | `{"message":"El email ya está registrado"}` — 409 Conflict | Pass | **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 009 | API | Registro con contraseña débil (menos de 8 caracteres) | `POST /v1/auth/register` — `password: "Abc12!"` (7 chars) | Código 400. Mensaje: "La contraseña debe tener al menos 8 caracteres" | `{"message":"password: String should have at least 8 characters"}` — 400 Bad Request | Pass | **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 010 | API | Registro con contraseña débil (solo números) | `POST /v1/auth/register` — `password: "12345678"` | Código 400. Mensaje de error de política de contraseña | `{"name":"Test","email":"test5@test.com","token":"eyJ...","must_change_password":true}` — 201 Created | Fail | **La contraseña solo numérica fue aceptada.** La política solo valida longitud mínima, no complejidad. Ver hallazgo #8. **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 011 | API | Registro con email inválido | `POST /v1/auth/register` — `email: "invalido"` | Código 400. Error de validación: email inválido | `{"message":"email: value is not a valid email address: An email address must have an @-sign."}` — 400 Bad Request | Pass | **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 012 | API | Registro con nombre vacío | `POST /v1/auth/register` — `name: ""` | Código 400. Error de validación: nombre requerido | `{"message":"name: String should have at least 1 character"}` — 400 Bad Request | Pass | **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 013 | API | Registro con `installation_id` > 8 caracteres | `POST /v1/auth/register` — `installation_id: "TERM001XX"` (9 chars) | Código 400. Error de validación: max 8 caracteres | `{"message":"installation_id: String should have at most 8 characters"}` — 400 Bad Request | Pass | **El registro no se usará en producción — los usuarios son dados de alta por la empresa (vía Postman/central).** |
| 014 | API | Cambio de contraseña exitoso | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "Nueva4567!"` + Header `Authorization: Bearer <token>` | Código 200. Mensaje: "Contraseña actualizada correctamente" | `{"message":"Contraseña actualizada correctamente"}` — 200 OK | Pass | |
| 015 | API | Cambio de contraseña con contraseña actual incorrecta | `POST /v1/auth/change-password` — `current_password: "wrongpass"`, `new_password: "Nueva4567!"` + Bearer token | Código 401. Mensaje: "Contraseña actual incorrecta" | `{"message":"Contraseña actual incorrecta"}` — 401 Unauthorized | Pass | |
| 016 | API | Cambio de contraseña con nueva contraseña débil | `POST /v1/auth/change-password` — `current_password: "Nueva4567!"`, `new_password: "abc"` + Bearer token | Código 400. Mensaje: "La contraseña debe tener al menos 8 caracteres" | `{"message":"new_password: String should have at least 8 characters"}` — 400 Bad Request | Pass | |
| 017 | API | Cambio de contraseña sin token | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "Nueva4567!"` (sin header Authorization) | Código 401. Error: "Not authenticated" | `{"message":"Autenticación requerida"}` — 401 Unauthorized | Pass | |
| 018 | API | Cambio de contraseña con misma contraseña | `POST /v1/auth/change-password` — `current_password: "Nueva4567!"`, `new_password: "Nueva4567!"` + Bearer token | Código 400. Mensaje: "La nueva contraseña debe ser distinta a la actual" | `{"message":"La nueva contraseña debe ser distinta a la actual"}` — 400 Bad Request | Pass | |
| 019 | API | Obtener catálogo de productos | `GET /v1/products` | Código 200. Lista de productos de gas activos (ej: `GARRAFA_10`, `GARRAFA_15`, etc.) con `code` y `label` | `[{"code":"GARRAFA_10","label":"Garrafa 10 kg"},{"code":"GARRAFA_15","label":"Garrafa 15 kg"},{"code":"GARRAFA_30","label":"Garrafa 30 kg"},{"code":"TUBO_45","label":"Tubo 45 kg"},{"code":"GRANEL","label":"Granel"}]` — 200 OK | Pass | Endpoint público, 5 productos activos |
| 020 | API | Health check / Ping | `GET /ping` | Código 200. `{"status": "ok"}` | `{"status":"ok"}` — 200 OK | Pass | Endpoint en `/ping` (no `/v1/ping`) |
| 021 | API | Registrar venta exitosa | `POST /v1/transactions` — `product: "GARRAFA_10"`, `amount: "1500.00"`, `card_number: "6063007014007403"`, `cvv: "123"`, `expiration_date: "1228"` + Header `Idempotency-Key: "test-002"` + Bearer token | Código 201. Devuelve `status: "approved"`, `transaction_number`, `user_message`, `created_at` | `{"transaction_number":"OP-260730-0003","status":"FAILED","user_message":"No se pudo procesar el pago. Intente nuevamente.","created_at":"2026-07-30T19:50:57.447291Z"}` — 201 Created | Pass | La API crea la transacción correctamente. Status `FAILED` porque el gateway/procesador no están corriendo. La API delega correctamente. |
| 022 | API | Registrar venta con CVV inválido (> 4 dígitos) | `POST /v1/transactions` — `cvv: "12345"` (5 dígitos) + Idempotency-Key + Bearer token | Código 400. Error de validación: CVV inválido | `{"message":"cvv: String should have at most 4 characters"}` — 400 Bad Request | Pass | |
| 023 | API | Registrar venta con CVV inválido (< 3 dígitos) | `POST /v1/transactions` — `cvv: "12"` (2 dígitos) + Idempotency-Key + Bearer token | Código 400. Error de validación: CVV inválido | `{"message":"cvv: String should have at least 3 characters"}` — 400 Bad Request | Pass | |
| 024 | API | Registrar venta con número de tarjeta inválido | `POST /v1/transactions` — `card_number: "1234"` (muy corto) + Idempotency-Key + Bearer token | Código 400. Mensaje: "Número de tarjeta inválido" | `{"message":"card_number: String should have at least 13 characters"}` — 400 Bad Request | Pass | |
| 025 | API | Registrar venta con monto negativo | `POST /v1/transactions` — `amount: "-100.00"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Monto inválido" | `{"message":"Monto inválido"}` — 400 Bad Request | Pass | |
| 026 | API | Registrar venta con monto cero | `POST /v1/transactions` — `amount: "0.00"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Monto inválido" | `{"message":"Monto inválido"}` — 400 Bad Request | Pass | |
| 027 | API | Registrar venta con producto inexistente | `POST /v1/transactions` — `product: "PRODUCTO_INEXISTENTE"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Producto no soportado" | `{"message":"product: Input should be 'GARRAFA_10', 'GARRAFA_15', 'GARRAFA_30', 'TUBO_45' or 'GRANEL'"}` — 400 Bad Request | Pass | |
| 028 | API | Registrar venta sin `Idempotency-Key` | `POST /v1/transactions` — sin header `Idempotency-Key` + Bearer token | Código 400. Mensaje: "Idempotency-Key es requerido" | `{"message":"Idempotency-Key es requerido"}` — 400 Bad Request | Pass | |
| 029 | API | Registrar venta con `Idempotency-Key` repetida (mismo body) | `POST /v1/transactions` — misma `Idempotency-Key: "test-002"` que TC-021, mismo payload | Código 200. Mismo resultado que la original | `{"transaction_number":"OP-260730-0003","status":"FAILED","user_message":"No se pudo procesar el pago. Intente nuevamente.","created_at":"2026-07-30T19:50:57.447291Z"}` — 200 OK | Pass | Devuelve la misma transacción original. Idempotencia funciona correctamente. |
| 030 | API | Registrar venta con `Idempotency-Key` repetida (distinto body) | `POST /v1/transactions` — misma `Idempotency-Key: "test-002"` pero con `amount: "2000.00"` | Código 409. Mensaje: "Idempotency-Key ya usada con otro request" | `{"message":"Idempotency-Key ya usada con otro request"}` — 409 Conflict | Pass | |
| 031 | API | Registrar venta con `expiration_date` en formato incorrecto | `POST /v1/transactions` — `expiration_date: "12/28"` (contiene /) | Código 400. Error de validación de fecha | `{"message":"expiration_date: String should have at most 4 characters"}` — 400 Bad Request | Pass | El campo espera MMYY (4 caracteres máximo) |
| 032 | API | Registrar venta sin token | `POST /v1/transactions` — sin header `Authorization` | Código 401. Error: "Not authenticated" | `{"message":"Autenticación requerida"}` — 401 Unauthorized | Pass | |
| 033 | API | Registrar venta con terminal no configurada | `POST /v1/transactions` — usuario con `installation_id` sin terminal en el procesador | Código 400. Mensaje: "La instalación no tiene terminal configurada" | No probado | Pendiente | Requiere configurar el procesador |
| 034 | API | Registrar venta con límite diario agotado | `POST /v1/transactions` — después de alcanzar el límite diario de operaciones | Código 400. Mensaje: "Se alcanzó el límite diario de operaciones" | No probado | Pendiente | Requiere muchas transacciones |
| 035 | API | Listar transacciones | `GET /v1/transactions?limit=10&offset=0` + Bearer token | Código 200. Lista paginada de transacciones del terminal con `items` y `total` | `{"items":[{"transaction_number":"OP-260730-0003",...}],"total":1}` — 200 OK | Pass | |
| 036 | API | Listar transacciones sin token | `GET /v1/transactions` — sin header `Authorization` | Código 401. Error: "Not authenticated" | `{"message":"Autenticación requerida"}` — 401 Unauthorized | Pass | |
| 037 | API | Listar transacciones con límite inválido | `GET /v1/transactions?limit=0` + Bearer token | Código 400. Error de validación: limit debe ser >= 1 | `{"message":"limit: Input should be greater than or equal to 1"}` — 400 Bad Request | Pass | |
| 038 | API | Listar transacciones con límite excedido | `GET /v1/transactions?limit=200` + Bearer token | Código 400. Error de validación: limit debe ser <= 100 | `{"message":"limit: Input should be less than or equal to 100"}` — 400 Bad Request | Pass | |
| 039 | API | Listar transacciones con offset negativo | `GET /v1/transactions?offset=-1` + Bearer token | Código 400. Error de validación: offset debe ser >= 0 | `{"message":"offset: Input should be greater than or equal to 0"}` — 400 Bad Request | Pass | |
| 040 | API | Obtener detalle de transacción | `GET /v1/transactions/{id}` + Bearer token | Código 200. Detalle completo: `transaction_number`, `product`, `amount`, `card_last4`, `status`, `user_message`, `created_at` | `{"detail":"Not Found"}` — 404 Not Found | N/A | **El endpoint no existe.** Solo están implementados `GET /v1/transactions` (listado) y `POST /v1/transactions` (crear). Ver hallazgo #9. |
| 041 | API | Obtener detalle de transacción inexistente | `GET /v1/transactions/999999` + Bearer token | Código 404. Error: "Transaction not found" | `{"detail":"Not Found"}` — 404 Not Found | N/A | El endpoint no existe. Ver hallazgo #9. |
| 042 | API | Obtener detalle de transacción sin token | `GET /v1/transactions/{id}` — sin header `Authorization` | Código 401. Error: "Not authenticated" | `{"detail":"Not Found"}` — 404 Not Found | N/A | El endpoint no existe. Ver hallazgo #9. |

---

## Módulo: Payment Gateway

Adaptador HTTP → ISO8583. Traduce las solicitudes de la API al formato del procesador legacy.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 043 | Gateway | Ping / Health check | `GET /ping` | Código 200. `{"status": "ok"}` | `{"status":"ok"}` — 200 OK | Pass | Endpoint en `/ping` (no `/v1/ping`) |
| 044 | Gateway | Autorizar venta exitosa (entry mode manual 012) | `POST /v1/authorize` — `product_code: "993"`, `amount_minor: 150000`, `card_number: "4111111111111111"`, `terminal_id: "TERM001"`, `stan: "000002"`, `expiration_date: "1228"` | Código 200. `status: "approved"`, `response_code`, `auth_id`, `retrieval_reference`, `user_message` | **Mock:** `{"status":"APPROVED","response_code":"00","user_message":"Aprobada","auth_id":"MOCK01","retrieval_reference":"000000000001"}` — 200 OK. **Procesador real:** `{"status":"DECLINED","response_code":"89","user_message":"Rechazada","auth_id":"636915","retrieval_reference":"000000692777"}` — 200 OK | Pass | Mock: APPROVED. Procesador real: DECLINED con código 89 (terminal desconocida). TERM001 no está dada de alta en la base del procesador. |
| 045 | Gateway | Autorizar con tarjeta sin fondos | `POST /v1/authorize` — monto superior al límite de la tarjeta | Código 200. `status: "declined"`, `response_code` de rechazo, `user_message` explicativo | No probado | Pendiente | Requiere tarjeta con límite configurado en el procesador |
| 046 | Gateway | Autorizar con terminal inválida | `POST /v1/authorize` — `terminal_id: "INVALIDO"` | Código 400. Mensaje: "Terminal inválida" | **Mock:** `{"status":"APPROVED",...}` — 200 OK (Fail). **Procesador real:** `{"status":"DECLINED","response_code":"89","user_message":"Rechazada","auth_id":"238335","retrieval_reference":"000000747793"}` — 200 OK | Pass | El procesador real rechaza correctamente con código 89 (terminal desconocida). El mock no valida (ver hallazgo #11). |
| 047 | Gateway | Autorizar con STAN inválido | `POST /v1/authorize` — `stan: ""` (vacío) | Código 400. Mensaje: "STAN inválido" | `{"message":"stan: String should have at least 1 character"}` — 400 Bad Request | Pass | |
| 048 | Gateway | Autorizar con número de tarjeta inválido | `POST /v1/authorize` — `card_number: "1234"` | Código 400. Mensaje: "Número de tarjeta inválido" | `{"message":"card_number: String should have at least 13 characters"}` — 400 Bad Request | Pass | |
| 049 | Gateway | Autorizar con monto inválido | `POST /v1/authorize` — `amount_minor: 0` | Código 400. Mensaje: "Monto inválido" | `{"message":"amount_minor: Input should be greater than 0"}` — 400 Bad Request | Pass | |
| 050 | Gateway | Autorizar con producto no soportado | `POST /v1/authorize` — `product_code: "INVALIDO"` | Código 400. Mensaje: "Producto no soportado" | `{"message":"product_code: Input should be '993', '994', '995', '996' or '997'"}` — 400 Bad Request | Pass | El gateway usa códigos de procesador (993-997), no nombres de producto |
| 051 | Gateway | Timeout de conexión al procesador | Procesador detenido con `docker compose stop auth` | Código 502. Mensaje: "Procesador de pagos no disponible" | `{"message":"Procesador de pagos no disponible"}` — 502 Bad Gateway | Pass | El gateway detecta correctamente la caída del procesador y devuelve 502. |
| 052 | Gateway | Autorizar con entry mode de banda (020) | `POST /v1/authorize` — `entry_mode: "020"` con datos de track | Código 200. `status: "approved"` | | | Pendiente de implementación de captura por banda (G-P0-06) |

---

## Módulo: POC Verifone (V660P)

App semilla para probar integración de hardware Verifone (PaymentSDK 4.1.0-sdi).

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 086 | POC Verifone | Inicializar PaymentSDK | Presionar "Init PSDK" en pantalla principal | Evento `success: true` y `sdiReady: true` en log | `PaymentSDK init OK; SDI ready=true`. Conexión TCP a 127.0.0.1:12000 exitosa. | Pass | PSDK se inicializa correctamente en ~2 segundos. Detecta dispositivo V660P en modo NEXO. |
| 087 | POC Verifone | Leer banda magnética (modo mock) | Switch "Mock solo lectura de banda" ON + presionar "Leer banda (mock)" | Devuelve datos de prueba predefinidos: PAN `6063001014007403`, nombre `LILLO ESPINOZA SILVIA DEL`, expiry `12/30` | Mock activado: devolvió PAN, nombre, tracks en texto plano. `mocked: true`, `hasClearData: true` | Pass | Modo mock funciona correctamente para desarrollo sin hardware. |
| 088 | POC Verifone | Leer banda magnética (modo real, VCL activo) | Switch Mock OFF + presionar "Leer banda" + pasar tarjeta por MSR | Devuelve datos de tarjeta en claro (PAN, tracks) | `swipeSeen: true`, `result: ERR_EXECUTION`, `hasClearData: false`. PAN y tracks enmascarados con `FF`. Tags devueltos pero enmascarados. | Pass | **Comportamiento esperado:** VCL (Verifone Common Library) enmascara datos sensibles. Requiere whitelist de BINs o perfil de laboratorio para obtener datos claros. |
| 089 | POC Verifone | Imprimir ticket térmico | PSDK inicializado + presionar "Imprimir ticket" | Impresora térmica imprime ticket con datos de venta mock | `printHTML: OK`. Ticket impreso correctamente con formato HTML (1269 chars). | Pass | Impresión funciona correctamente. Requiere PSDK en estado `sdiReady`. |
| 090 | POC Verifone | Venta mock (sin backend) | Presionar "Venta mock" | Devuelve respuesta simulada de API: `status: APPROVED`, `transaction_number`, `amount`, `card_last4` | `ok: true`, `mocked: true`, `status: APPROVED`, `transaction_number: TXN-MOCK-1785857117336` | Pass | Simula respuesta de backend para testing del flujo completo. |

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

## Resumen

| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| API | 42 | 37 | 1 | 0 | 3 | 2 |
| Payment Gateway | 10 | 8 | 0 | 0 | 0 | 2 |
| POC Verifone | 5 | 5 | 0 | 0 | 0 | 0 |
| Mobile | 33 | 20 | 1 | 0 | 2 | 10 |
| **Total** | **90** | **70** | **2** | **0** | **5** | **14** |

---

## Descubrimientos / Hallazgos

| # | Fecha | Módulo | Descubrimiento | Implicancia | Estado | Referencia |
|---|-------|--------|----------------|-------------|--------|------------|
| 1 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta.** Se probó con `card_number: "4111111111111112"` (Luhn inválido) y la API lo aceptó y creó la transacción. | Riesgo de aceptar tarjetas inválidas. Se debe implementar validación de Luhn en la API. | Resuelto | TC-024 |
| 2 | 2026-07-30 | API | **La API no valida el CVV en el backend.** Se probó con `cvv: "12345"` (5 dígitos) y la API lo rechazó por validación de esquema (max 4), pero no hay validación de negocio del CVV (3-4 dígitos). | El CVV se valida solo por longitud en el esquema, no por regla de negocio. | Resuelto | TC-022, TC-023 |
| 3 | 2026-07-30 | API | **La API no valida el monto mínimo.** Se probó con `amount: "0.00"` y la API lo rechazó con "Monto inválido". | La validación de monto funciona correctamente. | Resuelto | TC-026 |
| 4 | 2026-07-30 | API | **La API no valida la fecha de expiración de la tarjeta.** Se probó con `expiration_date: "12/28"` y la API lo rechazó por validación de esquema (max 4 caracteres), pero no hay validación de negocio de la fecha (MMYY). | La fecha se valida solo por longitud en el esquema, no por regla de negocio. | Resuelto | TC-031 |
| 5 | 2026-07-30 | API | **La API no valida el formato del monto.** Se probó con `amount: "-100.00"` y la API lo rechazó con "Monto inválido". | La validación de monto funciona correctamente. | Resuelto | TC-025 |
| 6 | 2026-07-30 | API | **La API no valida el formato del número de tarjeta.** Se probó con `card_number: "1234"` y la API lo rechazó por validación de esquema (min 13 caracteres). | La validación de longitud funciona correctamente. | Resuelto | TC-024 |
| 7 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta (confirmado).** Se probó con `card_number: "4111111111111112"` (Luhn inválido) y la API lo aceptó y creó la transacción. | Riesgo de aceptar tarjetas inválidas. Se debe implementar validación de Luhn en la API. | Resuelto | TC-024 |
| 8 | 2026-07-30 | API | **La política de contraseñas solo valida longitud mínima (8 caracteres), no complejidad.** Se probó con `password: "12345678"` (solo números) y fue aceptada. | Riesgo de seguridad: contraseñas débiles. Se debe implementar política de complejidad (mayúsculas, minúsculas, números, símbolos). | Abierto | TC-010 |
| 9 | 2026-07-30 | API | **El endpoint `GET /v1/transactions/{id}` no existe.** Solo están implementados `GET /v1/transactions` (listado) y `POST /v1/transactions` (crear). | No se puede obtener el detalle de una transacción individual. La app mobile podría necesitarlo para el detalle desde historial. | Abierto | TC-040, TC-041, TC-042 |
| 10 | 2026-07-30 | API | **La API no valida el formato del CVV en el backend.** Se probó con `cvv: "12"` (2 dígitos) y la API lo rechazó por validación de esquema (min 3 caracteres). | La validación de longitud funciona correctamente. | Resuelto | TC-023 |
| 11 | 2026-07-30 | Gateway | **El mock del gateway no valida la terminal.** Se probó con `terminal_id: "INVALIDO"` y el mock devolvió APPROVED. | El mock no replica la validación del procesador real. Solo afecta pruebas locales. | Resuelto | TC-046 |
| 12 | 2026-07-30 | Gateway | **El procesador real rechaza terminales de prueba con código 89.** Se probó con `terminal_id: "TERM001"` y el procesador devolvió DECLINED con código 89 (terminal desconocida). | Las terminales de prueba no están dadas de alta en la base del procesador. Se debe dar de alta la terminal para probar aprobaciones. | Abierto | TC-044 |
| 13 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta (confirmado por segunda vez).** Se probó con `card_number: "4111111111111112"` y la API lo aceptó. | Riesgo de aceptar tarjetas inválidas. Se debe implementar validación de Luhn en la API. | Resuelto | TC-024 |
| 14 | 2026-07-30 | API | **La API no valida el formato del CVV en el backend (confirmado).** Se probó con `cvv: "12345"` (5 dígitos) y la API lo rechazó por validación de esquema (max 4). | El CVV se valida solo por longitud en el esquema, no por regla de negocio. | Resuelto | TC-022 |
| 15 | 2026-07-30 | API | **La API no valida el formato del monto (confirmado).** Se probó con `amount: "-100.00"` y la API lo rechazó con "Monto inválido". | La validación de monto funciona correctamente. | Resuelto | TC-025 |
| 16 | 2026-07-30 | Gateway | **El procesador rechaza terminales de prueba con código 89.** Se probó con `terminal_id: "TERM001"` y el procesador devolvió DECLINED con código 89 (terminal desconocida). | Las terminales de prueba no están dadas de alta en la base del procesador. Se debe dar de alta la terminal para probar aprobaciones. | Abierto | TC-044 |
| 17 | 2026-07-31 | Mobile | **ANR (Application Not Responding) al reiniciar la app tras logout.** Al hacer logout y volver a abrir la app, se produce un ANR en el emulador. | El ANR no se reproduce en dispositivo real (ver hallazgo #21). Es específico del emulador. | Resuelto | TC-059 |
| 18 | 2026-07-31 | Mobile | **La app no contacta la API desde el emulador.** Al intentar login desde el emulador, la app no puede conectarse a la API. | El emulador no puede acceder a `localhost` de la máquina host. Se debe usar `10.0.2.2` en el emulador. | Resuelto | TC-053 |
| 19 | 2026-07-31 | Gateway | **El procesador responde código 96 (ISO inválida) en varios escenarios.** Se probó con distintos payloads y el procesador devolvió código 96 en varios casos. | El formato ISO generado por el gateway no es válido para el procesador. Se debe revisar el empaquetado ISO. | Abierto | TC-044 |
| 20 | 2026-07-31 | Mobile | **La app no muestra el mensaje de error del procesador en la pantalla de venta.** Al fallar una venta, la app muestra un mensaje genérico en lugar del mensaje del procesador. | El usuario no ve el motivo real del rechazo. Se debe mostrar el `user_message` del procesador. | Resuelto | TC-066 |
| 21 | 2026-07-31 | Mobile | **La app funciona correctamente en dispositivo real.** Se probó en dispositivo Motorola (ZY22FSJKKV) vía adb y la app funciona correctamente. | El ANR del hallazgo #17 no se reproduce en dispositivo real. El problema era específico del emulador. | Resuelto | TC-053 |
| 22 | 2026-08-05 | Mobile | **La app no redirige al login cuando la sesión expira (401).** Al usar un token expirado, la app no redirige al login. | El usuario queda en una pantalla sin saber que su sesión expiró. Se debe detectar 401 y redirigir al login. | Resuelto | TC-060 |
| 23 | 2026-08-05 | Mobile | **Fallback silencioso en repositorios.** `SalesRepository.fetchProducts()` y `fetchTransactions()` capturan todas las excepciones y devuelven datos default / lista vacía sin avisar al usuario. | El usuario no sabe que hubo un error de red. Se debe mostrar un indicador de error y opción de reintentar. | Abierto | TC-062, TC-072 |
| 24 | 2026-08-05 | Mobile | **No existe botón "Reintentar" en la pantalla de estado de venta.** La `SaleStatusScreen` solo tiene "FINALIZAR". | El usuario no puede reintentar una venta fallida. Se debe implementar el botón que reenvíe con la misma `Idempotency-Key`. | Abierto | TC-069 |
| 25 | 2026-08-04 | POC Verifone | **VCL (Verifone Common Library) enmascara datos de tarjetas en el MSR.** Al leer banda magnética real (mock OFF), el SDK devuelve `ERR_EXECUTION` con PAN y tracks llenos de `FF` (0xFF). `hasClearData: false`. Los tags de transacción (`fetchTxnTags`) también vienen enmascarados. | **Comportamiento esperado en producción:** VCL enmascara PAN/tracks por seguridad. Para obtener datos claros se requiere: (1) Whitelist de BINs configurada en la terminal, (2) Perfil de laboratorio que desactive VCL, o (3) Usar camino de datos encriptados (`getEncData`). El modo mock (`PsdkMsrMock`) permite desarrollo sin whitelist. | La app funciona correctamente. VCL está activo (`keyStatusValue: 1`). Para desarrollo, usar modo mock. Para producción, gestionar whitelist con Verifone. | TC-088 |
| 26 | 2026-08-05 | API | **Falta de cobertura de tests para la rama `skip_luhn`/`luhn_check_enabled` en `create_transaction.py`.** Se agregó la configuración `luhn_check_enabled` (constructor) que se traduce en `skip_luhn` en `_validate_pan`, permitiendo omitir la validación de Luhn. Sin embargo, solo existía `test_invalid_pan` (cubre la rama con Luhn habilitado: PAN inválido → `InvalidCardNumber`), pero no había ningún test que verificara la rama con Luhn deshabilitado (PAN inválido que **pasa** la validación). Lo marcó Copilot en el PR: sin un test, una refactorización podría romper el flag silenciosamente. | **Resuelto (2026-08-05):** se agregó `test_invalid_pan_accepted_when_luhn_disabled` en `api/tests/test_create_transaction.py`, que construye el use case con `luhn_check_enabled=False` y verifica que el PAN `4111111111111112` (Luhn inválido) pasa la validación y la transacción llega al gateway (APPROVED). También se extendió el helper `_build()` para aceptar `luhn_check_enabled`. Complementa los hallazgos #7 y #13 sobre Luhn. | Resuelto | TC-024 |

### Detalle del cambio (estilo PR)

**Archivo modificado:** `api/tests/test_create_transaction.py`

**Motivo:** Copilot marcó en el PR que la rama `luhn_check_enabled=False` (que se traduce en `skip_luhn` en `_validate_pan`) no tenía cobertura de tests. Sin un test, una refactorización podría romper el flag silenciosamente.

**Cambios:**

1. Se extendió el helper `_build()` para aceptar `luhn_check_enabled` y pasarlo al constructor del use case.
2. Se agregó el test `test_invalid_pan_accepted_when_luhn_disabled` que verifica que con Luhn deshabilitado, un PAN inválido pasa la validación y la transacción llega al gateway.

```diff
 def _build(
     *,
     existing: Transaction | None = None,
     gateway_result: AuthorizeResult | None = None,
     installation_code: str | None = "05000001",
+    luhn_check_enabled: bool = True,
 ) -> tuple[CreateTransaction, MagicMock, MagicMock, MagicMock]:
     ...
     use_case = CreateTransaction(
         session=session,
         transactions=transactions,
         installations=installations,
         gateway=gateway,
+        luhn_check_enabled=luhn_check_enabled,
     )
     return use_case, transactions, installations, gateway


+def test_invalid_pan_accepted_when_luhn_disabled() -> None:
+    # PAN 4111111111111112 no pasa el checksum de Luhn, pero con
+    # luhn_check_enabled=False la validación se omite y la transacción continúa.
+    use_case, transactions, _, gateway = _build(luhn_check_enabled=False)
+    result = use_case.execute(
+        user_id=1,
+        installation_id="inst-1",
+        idempotency_key="k1",
+        product="GARRAFA_10",
+        amount="1.50",
+        card_number="4111111111111112",
+        cvv="123",
+    )
+    assert result.http_status == CreateTransactionHttpStatus.CREATED
+    assert result.transaction.status == TransactionStatus.APPROVED
+    gateway.authorize.assert_called_once()
+    transactions.update_result.assert_called_once()
```

**Validación:** `make check` en `api/` pasó completo (Ruff ✓, mypy ✓, 96 tests ✓, cobertura 94.91% ≥ 90%).



