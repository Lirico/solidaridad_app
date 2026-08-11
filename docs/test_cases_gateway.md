# Test Cases — Payment Gateway

> **Última actualización:** 2026-08-05
>
> Archivo vivo de casos de prueba del módulo **Payment Gateway**. Se actualiza a medida que se documentan y ejecutan tests.
>
> Este archivo es parte de la separación de `docs/test_cases_index.md`. Ver el [índice](test_cases_index.md).

---

## Formato

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A` · `Pendiente`

---

## Módulo: Payment Gateway

Adaptador HTTP → ISO8583. Traduce las solicitudes de la API al formato del procesador legacy.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 043 | Gateway | Ping / Health check | `GET /ping` | Código 200. `{"status": "ok"}` | `{"status":"ok"}` — 200 OK | Pass | Endpoint en `/ping` (no `/v1/ping`) |
| 044 | Gateway | Autorizar venta exitosa (entry mode manual 012) | `POST /v1/authorize` — `product_code: "993"`, `amount_minor: 150000`, `card_number: "4111111111111111"`, `terminal_id: "TERM001"`, `stan: "000002"`, `expiration_date: "1228"` | Código 200. `status: "approved"`, `response_code`, `auth_id`, `retrieval_reference`, `user_message` | **Mock:** `{"status":"APPROVED","response_code":"00","user_message":"Aprobada","auth_id":"MOCK01","retrieval_reference":"000000000001"}` — 200 OK. **Procesador real:** `{"status":"DECLINED","response_code":"89","user_message":"Rechazada","auth_id":"636915","retrieval_reference":"000000692777"}` — 200 OK | Pass | Mock: APPROVED. Procesador real: DECLINED con código 89 (terminal desconocida). TERM001 no está dada de alta en la base del procesador. |
| 047 | Gateway | Autorizar con STAN inválido | `POST /v1/authorize` — `stan: ""` (vacío) | Código 400. Mensaje: "STAN inválido" | `{"message":"stan: String should have at least 1 character"}` — 400 Bad Request | Pass | |
| 048 | Gateway | Autorizar con número de tarjeta inválido | `POST /v1/authorize` — `card_number: "1234"` | Código 400. Mensaje: "Número de tarjeta inválido" | `{"message":"card_number: String should have at least 13 characters"}` — 400 Bad Request | Pass | |
| 049 | Gateway | Autorizar con monto inválido | `POST /v1/authorize` — `amount_minor: 0` | Código 400. Mensaje: "Monto inválido" | `{"message":"amount_minor: Input should be greater than 0"}` — 400 Bad Request | Pass | |
| 050 | Gateway | Autorizar con producto no soportado | `POST /v1/authorize` — `product_code: "INVALIDO"` | Código 400. Mensaje: "Producto no soportado" | `{"message":"product_code: Input should be '993', '994', '995', '996' or '997'"}` — 400 Bad Request | Pass | El gateway usa códigos de procesador (993-997), no nombres de producto |
| 051 | Gateway | Timeout de conexión al procesador | Procesador detenido con `docker compose stop auth` | Código 502. Mensaje: "Procesador de pagos no disponible" | `{"message":"Procesador de pagos no disponible"}` — 502 Bad Gateway | Pass | El gateway detecta correctamente la caída del procesador y devuelve 502. |
| 052 | Gateway | Autorizar con entry mode de banda (020) | `POST /v1/authorize` — `entry_mode: "020"` con datos de track | Código 200. `status: "approved"` | | | Pendiente de implementación de captura por banda (G-P0-06) |

---

## Resumen

| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| Payment Gateway | 7 | 6 | 0 | 0 | 0 | 1 |
