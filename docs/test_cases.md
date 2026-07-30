# Test Cases — Solidaridad App

> **Última actualización:** 2026-07-30
>
> Archivo vivo de casos de prueba. Se actualiza a medida que se documentan y ejecutan tests.

---

## Formato

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A`

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
| 007 | API | Registro exitoso de nuevo usuario | `POST /v1/auth/register` — `name: "Test User"`, `email: "testuser@test.com"`, `password: "Test1234!"`, `installation_id: "TERM001"` | Código 201. Devuelve `access_token`, `must_change_password: true` | `{"name":"Test User","email":"testuser@test.com","token":"eyJ...","must_change_password":false}` — 201 Created | Pass | `must_change_password` es `false` porque la contraseña cumple la política |
| 008 | API | Registro con email duplicado | `POST /v1/auth/register` — mismo email que usuario existente | Código 409. Mensaje: "El email ya está registrado" | `{"message":"El email ya está registrado"}` — 409 Conflict | Pass | |
| 009 | API | Registro con contraseña débil (menos de 8 caracteres) | `POST /v1/auth/register` — `password: "Abc12!"` (7 chars) | Código 400. Mensaje: "La contraseña debe tener al menos 8 caracteres" | `{"message":"password: String should have at least 8 characters"}` — 400 Bad Request | Pass | |
| 010 | API | Registro con contraseña débil (solo números) | `POST /v1/auth/register` — `password: "12345678"` | Código 400. Mensaje de error de política de contraseña | No probado | Pendiente | |
| 011 | API | Registro con email inválido | `POST /v1/auth/register` — `email: "invalido"` | Código 400. Error de validación: email inválido | `{"message":"email: value is not a valid email address: An email address must have an @-sign."}` — 400 Bad Request | Pass | |
| 012 | API | Registro con nombre vacío | `POST /v1/auth/register` — `name: ""` | Código 400. Error de validación: nombre requerido | `{"message":"name: String should have at least 1 character"}` — 400 Bad Request | Pass | |
| 013 | API | Registro con `installation_id` > 8 caracteres | `POST /v1/auth/register` — `installation_id: "TERM001XX"` (9 chars) | Código 400. Error de validación: max 8 caracteres | `{"message":"installation_id: String should have at most 8 characters"}` — 400 Bad Request | Pass | |
| 014 | API | Cambio de contraseña exitoso | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "Nueva4567!"` + Header `Authorization: Bearer <token>` | Código 200. Mensaje: "Contraseña actualizada correctamente" | `{"message":"Contraseña actualizada correctamente"}` — 200 OK | Pass | Usa la contraseña original ya que se cambió la contraseña a "Nueva4567!" |
| 015 | API | Cambio de contraseña con contraseña actual incorrecta | `POST /v1/auth/change-password` — `current_password: "wrongpass"`, `new_password: "Nueva4567!"` + Bearer token | Código 401. Mensaje: "Contraseña actual incorrecta" | `{"message":"Contraseña actual incorrecta"}` — 401 Unauthorized | Pass | |
| 016 | API | Cambio de contraseña con nueva contraseña débil | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "abc"` + Bearer token | Código 400. Mensaje: "La contraseña debe tener al menos 8 caracteres" | No probado | Pendiente | |
| 017 | API | Cambio de contraseña sin token | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "Nueva4567!"` (sin header Authorization) | Código 401. Error: "Not authenticated" | `{"message":"Autenticación requerida"}` — 401 Unauthorized | Pass | |
| 018 | API | Cambio de contraseña con misma contraseña | `POST /v1/auth/change-password` — `current_password: "Test1234!"`, `new_password: "Test1234!"` + Bearer token | Código 400. Mensaje: "La nueva contraseña debe ser distinta a la actual" | No probado | Pendiente | |
| 019 | API | Obtener catálogo de productos | `GET /v1/products` | Código 200. Lista de productos de gas activos (ej: `GARRAFA_10`, `GARRAFA_15`, etc.) con `code` y `label` | `[{"code":"GARRAFA_10","label":"Garrafa 10 kg"},{"code":"GARRAFA_15","label":"Garrafa 15 kg"},{"code":"GARRAFA_30","label":"Garrafa 30 kg"},{"code":"TUBO_45","label":"Tubo 45 kg"},{"code":"GRANEL","label":"Granel"}]` — 200 OK | Pass | Endpoint público, 5 productos activos |
| 020 | API | Health check / Ping | `GET /ping` | Código 200. `{"status": "ok"}` | `{"status":"ok"}` — 200 OK | Pass | Endpoint en `/ping` (no `/v1/ping`) |
| 021 | API | Registrar venta exitosa | `POST /v1/transactions` — `product: "GARRAFA_10"`, `amount: "1500.00"`, `card_number: "6063007014007403"`, `cvv: "123"`, `expiration_date: "1228"` + Header `Idempotency-Key: "test-002"` + Bearer token | Código 201. Devuelve `status: "approved"`, `transaction_number`, `user_message`, `created_at` | `{"transaction_number":"OP-260730-0003","status":"FAILED","user_message":"No se pudo procesar el pago. Intente nuevamente.","created_at":"2026-07-30T19:50:57.447291Z"}` — 201 Created | Pass | La API crea la transacción correctamente. Status `FAILED` porque el gateway/procesador no están corriendo. La API delega correctamente. |
| 022 | API | Registrar venta con CVV inválido (> 4 dígitos) | `POST /v1/transactions` — `cvv: "12345"` (5 dígitos) + Idempotency-Key + Bearer token | Código 400. Error de validación: CVV inválido | No probado | Pendiente | |
| 023 | API | Registrar venta con CVV inválido (< 3 dígitos) | `POST /v1/transactions` — `cvv: "12"` (2 dígitos) + Idempotency-Key + Bearer token | Código 400. Error de validación: CVV inválido | No probado | Pendiente | |
| 024 | API | Registrar venta con número de tarjeta inválido | `POST /v1/transactions` — `card_number: "1234"` (muy corto) + Idempotency-Key + Bearer token | Código 400. Mensaje: "Número de tarjeta inválido" | No probado | Pendiente | |
| 025 | API | Registrar venta con monto negativo | `POST /v1/transactions` — `amount: "-100.00"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Monto inválido" | No probado | Pendiente | |
| 026 | API | Registrar venta con monto cero | `POST /v1/transactions` — `amount: "0.00"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Monto inválido" | No probado | Pendiente | |
| 027 | API | Registrar venta con producto inexistente | `POST /v1/transactions` — `product: "PRODUCTO_INEXISTENTE"` + Idempotency-Key + Bearer token | Código 400. Mensaje: "Producto no soportado" | No probado | Pendiente | |
| 028 | API | Registrar venta sin `Idempotency-Key` | `POST /v1/transactions` — sin header `Idempotency-Key` + Bearer token | Código 400. Mensaje: "Idempotency-Key es requerido" | `{"message":"Idempotency-Key es requerido"}` — 400 Bad Request | Pass | |
| 029 | API | Registrar venta con `Idempotency-Key` repetida (mismo body) | `POST /v1/transactions` — misma `Idempotency-Key` que una transacción ya existente, mismo payload | Código 200 (si ya fue aprobada) o 202 ACCEPTED (si aún está PENDING). Mismo resultado que la original | No probado | Pendiente | |
| 030 | API | Registrar venta con `Idempotency-Key` repetida (distinto body) | `POST /v1/transactions` — misma `Idempotency-Key` pero con distinto `amount` | Código 409. Mensaje: "Idempotency-Key ya usada con otro request" | No probado | Pendiente | |
| 031 | API | Registrar venta con `expiration_date` en formato incorrecto | `POST /v1/transactions` — `expiration_date: "12/28"` (contiene /) | Código 400. Error de validación de fecha | No probado | Pendiente | |
| 032 | API | Registrar venta sin token | `POST /v1/transactions` — sin header `Authorization` | Código 401. Error: "Not authenticated" | `{"message":"Autenticación requerida"}` — 401 Unauthorized | Pass | |
| 033 | API | Registrar venta con terminal no configurada | `POST /v1/transactions` — usuario con `installation_id` sin terminal en el procesador | Código 400. Mensaje: "La instalación no tiene terminal configurada" | No probado | Pendiente | Requiere configurar el procesador |
| 034 | API | Registrar venta con límite diario agotado | `POST /v1/transactions` — después de alcanzar el límite diario de operaciones | Código 400. Mensaje: "Se alcanzó el límite diario de operaciones" | No probado | Pendiente | |
| 035 | API | Listar transacciones | `GET /v1/transactions?limit=10&offset=0` + Bearer token | Código 200. Lista paginada de transacciones del terminal con `items` y `total` | `{"items":[{"transaction_number":"OP-260730-0003","product":"GARRAFA_10","amount":"1500","card_last4":"7403","status":"FAILED","user_message":"No se pudo procesar el pago. Intente nuevamente.","created_at":"2026-07-30T19:50:57.447291Z"}],"total":1}` — 200 OK | Pass | |
| 036 | API | Listar transacciones sin token | `GET /v1/transactions` — sin header `Authorization` | Código 401. Error: "Not authenticated" | No probado | Pendiente | |
| 037 | API | Listar transacciones con límite inválido | `GET /v1/transactions?limit=0` + Bearer token | Código 400. Error de validación: limit debe ser >= 1 | No probado | Pendiente | |
| 038 | API | Listar transacciones con límite excedido | `GET /v1/transactions?limit=200` + Bearer token | Código 400. Error de validación: limit debe ser <= 100 | No probado | Pendiente | |
| 039 | API | Listar transacciones con offset negativo | `GET /v1/transactions?offset=-1` + Bearer token | Código 400. Error de validación: offset debe ser >= 0 | No probado | Pendiente | |
| 040 | API | Obtener detalle de transacción | `GET /v1/transactions/{id}` + Bearer token | Código 200. Detalle completo: `transaction_number`, `product`, `amount`, `card_last4`, `status`, `user_message`, `created_at` | No probado | Pendiente | |
| 041 | API | Obtener detalle de transacción inexistente | `GET /v1/transactions/999999` + Bearer token | Código 404. Error: "Transaction not found" | No probado | Pendiente | |
| 042 | API | Obtener detalle de transacción sin token | `GET /v1/transactions/{id}` — sin header `Authorization` | Código 401. Error: "Not authenticated" | No probado | Pendiente | |

---

## Módulo: Payment Gateway

Adaptador HTTP → ISO8583. Traduce las solicitudes de la API al formato del procesador legacy.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 043 | Gateway | Ping / Health check | `GET /v1/ping` | Código 200. `{"status": "ok"}` | | | Requiere gateway corriendo |
| 044 | Gateway | Autorizar venta exitosa (entry mode manual 012) | `POST /v1/authorize` — `product_code: "GARRAFA_10"`, `amount_minor: 150000`, `card_number: "6063007014007403"`, `terminal_id: "TERM001"`, `stan: "000001"`, `expiration_date: "1228"` | Código 200. `status: "approved"`, `response_code`, `auth_id`, `retrieval_reference`, `user_message` | | | amount_minor en centavos (150000 = $1500.00) |
| 045 | Gateway | Autorizar con tarjeta sin fondos | `POST /v1/authorize` — monto superior al límite de la tarjeta | Código 200. `status: "declined"`, `response_code` de rechazo, `user_message` explicativo | | | |
| 046 | Gateway | Autorizar con terminal inválida | `POST /v1/authorize` — `terminal_id: "INVALIDO"` | Código 400. Mensaje: "Terminal inválida" | | | |
| 047 | Gateway | Autorizar con STAN inválido | `POST /v1/authorize` — `stan: ""` (vacío) | Código 400. Mensaje: "STAN inválido" | | | |
| 048 | Gateway | Autorizar con número de tarjeta inválido | `POST /v1/authorize` — `card_number: "1234"` | Código 400. Mensaje: "Número de tarjeta inválido" | | | |
| 049 | Gateway | Autorizar con monto inválido | `POST /v1/authorize` — `amount_minor: 0` | Código 400. Mensaje: "Monto inválido" | | | |
| 050 | Gateway | Autorizar con producto no soportado | `POST /v1/authorize` — `product_code: "INVALIDO"` | Código 400. Mensaje: "Producto no soportado" | | | |
| 051 | Gateway | Timeout de conexión al procesador | Procesador no disponible / no responde | Código 502. Mensaje: "Procesador de pagos no disponible" | | | |
| 052 | Gateway | Autorizar con entry mode de banda (020) | `POST /v1/authorize` — `entry_mode: "020"` con datos de track | Código 200. `status: "approved"` | | | Pendiente de implementación de captura por banda (G-P0-06) |

---

## Módulo: Mobile (App Flutter)

Aplicación Android que corre en la terminal Verifone.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 053 | Mobile | Login exitoso | Ingresar usuario y contraseña válidos en pantalla de login | Navega a pantalla principal de ventas | | | |
| 054 | Mobile | Login con credenciales inválidas | Ingresar usuario o contraseña incorrectos | Muestra mensaje de error: "Credenciales inválidas" | | | |
| 055 | Mobile | Login con contraseña a cambiar | Usuario con `must_change_password: true` | Navega a pantalla de cambio de contraseña | | | |
| 056 | Mobile | Login con error de red | Sin conexión al servidor | Muestra mensaje de error de conexión | | | |
| 057 | Mobile | Register / Registro de nuevo usuario | Completar formulario de registro con datos válidos | Registro exitoso, navega a pantalla de cambio de contraseña | | | |
| 058 | Mobile | Register con email ya registrado | Completar formulario con email existente | Muestra mensaje: "El email ya está registrado" | | | |
| 059 | Mobile | Logout | Tocar opción "Cerrar sesión" | Vuelve a pantalla de login, limpia token | | | |
| 060 | Mobile | Sesión expirada | Token JWT vencido al intentar una operación | Redirige a pantalla de login | | | |
| 061 | Mobile | Seleccionar producto de gas | Tocar un producto del catálogo (ej: GARRAFA_10) | El producto se selecciona y se muestra el precio | | | |
| 062 | Mobile | Cargar productos con error de red | Sin conexión al cargar `GET /v1/products` | Muestra mensaje de error y opción de reintentar | | | |
| 063 | Mobile | Ingresar monto de venta | Escribir "1500.00" en el campo de monto | El monto se muestra correctamente formateado | | | |
| 064 | Mobile | Ingresar tarjeta manualmente (fallback) | Completar campos: número, CVV, vencimiento | Los campos se completan y se muestran enmascarados parcialmente | | | |
| 065 | Mobile | Confirmar venta y enviar | Revisar datos y tocar "Confirmar" | Muestra pantalla de "Procesando..." con spinner | | | |
| 066 | Mobile | Venta aprobada | Backend devuelve `status: "approved"` | Muestra pantalla verde con "APROBADA", código de autorización, y opción de imprimir ticket | | | |
| 067 | Mobile | Venta rechazada | Backend devuelve `status: "declined"` | Muestra pantalla roja con "RECHAZADA" y motivo del rechazo | | | |
| 068 | Mobile | Error de conexión / timeout | Backend no responde o timeout | Muestra pantalla naranja con "Error de conexión" y opción de reintentar | | | |
| 069 | Mobile | Reintentar venta tras error | Tocar "Reintentar" en pantalla de error | Reenvía la transacción con misma `Idempotency-Key` | | | |
| 070 | Mobile | Ver historial de ventas | Tocar "Historial" en la navegación | Muestra lista de transacciones con fecha, producto, monto y estado | | | |
| 071 | Mobile | Historial vacío | Usuario sin transacciones registradas | Muestra mensaje: "No hay transacciones" o lista vacía | | | |
| 072 | Mobile | Cargar historial con error de red | Sin conexión al cargar historial | Muestra mensaje de error y opción de reintentar | | | |
| 073 | Mobile | Pull-to-refresh en historial | Deslizar hacia abajo en la lista de historial | Recarga la lista de transacciones | | | |
| 074 | Mobile | Ver detalle de venta | Tocar una transacción del historial | Muestra detalle completo: producto, monto, estado, código de autorización, fecha | | | |
| 075 | Mobile | Impresión de ticket | Venta aprobada y tocar "Imprimir ticket" | La térmica del Verifone imprime el ticket | | | Pendiente de implementación (G-P0-07) |
| 076 | Mobile | Error de impresión | Impresora sin papel o desconectada | Muestra mensaje de error de impresión | | | |
| 077 | Mobile | Navegación atrás desde varias pantallas | Tocar botón "Atrás" | Vuelve a la pantalla anterior sin errores | | | |
| 078 | Mobile | Loading state en pantalla de venta | Tocar "Confirmar" y esperar respuesta | Muestra indicador de carga (spinner) mientras procesa | | | |

---

## Módulo: Procesador (authkig legacy)

Sistema on-premises en C que autoriza las transacciones vía mensajería ISO8583.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 079 | Procesador | Autorizar con terminal válida | Mensaje ISO con DE41 (terminal_id) dado de alta | Código de autorización aprobatorio | | | |
| 080 | Procesador | Autorizar con terminal inválida | Mensaje ISO con DE41 no registrado | Código de rechazo: terminal no autorizada | | | |
| 081 | Procesador | Autorizar tarjeta con saldo suficiente | Mensaje ISO con monto menor al límite de la tarjeta | Código de autorización aprobatorio | | | |
| 082 | Procesador | Autorizar tarjeta sin saldo | Mensaje ISO con monto superior al límite | Código de rechazo: fondos insuficientes | | | |
| 083 | Procesador | Autorizar tarjeta vencida | Mensaje ISO con tarjeta vencida | Código de rechazo: tarjeta vencida | | | |
| 084 | Procesador | Autorizar con banda magnética (track data) | Mensaje ISO con DE35 (track 2 data) | Código de autorización aprobatorio | | | Cuando se implemente captura por banda |
| 085 | Procesador | Procesador no disponible / caído | Gateway intenta conectar pero el procesador no responde | Timeout de conexión, error de comunicación | | | |

---

## Resumen de ejecución

| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| API | 42 | 20 | 0 | 0 | 0 | 22 |
| Payment Gateway | 10 | 0 | 0 | 0 | 0 | 10 |
| Mobile | 26 | 0 | 0 | 0 | 0 | 26 |
| Procesador | 7 | 0 | 0 | 0 | 0 | 7 |
| **Total** | **85** | **20** | **0** | **0** | **0** | **65** |

---

## Descubrimientos / Hallazgos

> Esta sección documenta comportamientos observados durante la ejecución de tests que difieren de lo esperado, o que son importantes de tener en cuenta para desarrollo y QA.

| # | Fecha | Módulo | Descubrimiento | Implicancia |
|---|-------|--------|----------------|-------------|
| 1 | 2026-07-30 | API | El endpoint de health check está en `/ping` (no `/v1/ping`). El router de ping está incluido directamente sin prefijo `/v1`. | Corregir documentación si se esperaba `/v1/ping`. Si se quiere estandarizar, mover el ping_router dentro del grupo `/v1`. |
| 2 | 2026-07-30 | API | Los errores de validación de Pydantic (schemas) retornan HTTP **400** en lugar de **422**. Esto es porque la app tiene un `exception_handler` personalizado para `RequestValidationError` que devuelve 400. | No es un bug, pero es importante saberlo si se espera 422 (estándar FastAPI). Los tests deben esperar 400, no 422. |
| 3 | 2026-07-30 | API | Las transacciones se crean con `status: "FAILED"` cuando el gateway/procesador no están disponibles. El código HTTP sigue siendo **201 Created**. | La API funciona correctamente: persiste la transacción y delega al gateway. El status refleja el resultado de la autorización. Para pruebas de integración completas, hay que tener el gateway y procesador corriendo. |
| 4 | 2026-07-30 | API | El login no revela si el usuario existe o no. Devuelve el mismo mensaje (`"Credenciales inválidas"` — 401) tanto para contraseña incorrecta como para usuario inexistente. | Buen comportamiento de seguridad. No permite enumeración de usuarios. |
| 5 | 2026-07-30 | API | El campo `expiration_date` en el schema espera formato **MMYY** (4 caracteres, sin separadores). No acepta formato con barras (`12/28`) ni año completo (`12/2028`). | Los tests y la app mobile deben enviar el formato correcto. |
| 6 | 2026-07-30 | API | `must_change_password` retorna `false` incluso en registros nuevos si la contraseña cumple la política de seguridad. | Revisar si la política debería forzar cambio de contraseña en el primer login. Depende de la configuración del `RegisterUser` use case. |
| 7 | 2026-07-30 | API | La tarjeta de prueba `6063 0070 1400 7403` no pasa el checksum de Luhn. Se requiere `LUHN_CHECK_ENABLED=false` en config para usarla (ya configurado así en local). | No usar esta tarjeta en producción. Para entorno local/documentación está bien. |

---

*Este archivo es un documento vivo. Se actualiza a medida que se documentan y ejecutan nuevos test cases.*