# Test Cases — Payment Processor (legacy)

> **Última actualización:** 2026-08-05
>
> Archivo vivo de casos de prueba del módulo **Payment Processor** (autorizador legacy en C + MySQL). Se actualiza a medida que se documentan y ejecutan tests.
>
> Este archivo es parte de la separación de `docs/test_cases_index.md`. Ver el [índice](test_cases_index.md).

---

## Formato

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A` · `Pendiente`

---

## Módulo: Payment Processor

Autorizador legacy (C + MySQL). Recibe el ISO8583 del gateway y decide si la transacción se aprueba o rechaza.

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|
| 045 | Processor | Autorizar con tarjeta sin fondos | `POST /v1/authorize` — monto superior al límite de la tarjeta | Código 200. `status: "declined"`, `response_code` de rechazo, `user_message` explicativo | No probado | Pendiente | Requiere tarjeta con límite configurado en el procesador |
| 046 | Processor | Autorizar con terminal inválida | `POST /v1/authorize` — `terminal_id: "INVALIDO"` | Código 400. Mensaje: "Terminal inválida" | **Mock:** `{"status":"APPROVED",...}` — 200 OK (Fail). **Procesador real:** `{"status":"DECLINED","response_code":"89","user_message":"Rechazada","auth_id":"238335","retrieval_reference":"000000747793"}` — 200 OK | Pass | El procesador real rechaza correctamente con código 89 (terminal desconocida). El mock no valida (ver hallazgo #11). |

---

## Resumen

| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| Payment Processor | 2 | 1 | 0 | 0 | 0 | 1 |
