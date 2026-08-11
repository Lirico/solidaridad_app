# Hallazgos / Descubrimientos — Solidaridad App

> **Última actualización:** 2026-08-06
>
> Archivo vivo de descubrimientos y hallazgos de las pruebas. Se actualiza a medida que se documentan y ejecutan tests.
>
> Este archivo es parte de la separación de `docs/test_cases_index.md`. Ver el [índice](test_cases_index.md).

---

## Descubrimientos / Hallazgos

| # | Fecha | Módulo | Descubrimiento | Implicancia | Estado | Referencia |
|---|-------|--------|----------------|-------------|--------|------------|
| 1 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta.** Se probó con `card_number: "4111111111111112"` (Luhn inválido) y la API lo aceptó y creó la transacción. | **Reevaluado (2026-08-06):** Luhn no aplica a las tarjetas del programa, que usan dígito verificador MOD-TDF. Se conserva validación numérica y de longitud. | Invalidado | TC-024 |
| 2 | 2026-07-30 | API | **La API no valida el CVV en el backend.** Se probó con `cvv: "12345"` (5 dígitos) y la API lo rechazó por validación de esquema (max 4), pero no hay validación de negocio del CVV (3-4 dígitos). | El CVV se valida solo por longitud en el esquema, no por regla de negocio. | Resuelto | TC-022, TC-023 |
| 3 | 2026-07-30 | API | **La API no valida el monto mínimo.** Se probó con `amount: "0.00"` y la API lo rechazó con "Monto inválido". | La validación de monto funciona correctamente. | Resuelto | TC-026 |
| 4 | 2026-07-30 | API | **La API no valida la fecha de expiración de la tarjeta.** Se probó con `expiration_date: "12/28"` y la API lo rechazó por validación de esquema (max 4 caracteres), pero no hay validación de negocio de la fecha (MMYY). | La fecha se valida solo por longitud en el esquema, no por regla de negocio. | Resuelto | TC-031 |
| 5 | 2026-07-30 | API | **La API no valida el formato del monto.** Se probó con `amount: "-100.00"` y la API lo rechazó con "Monto inválido". | La validación de monto funciona correctamente. | Resuelto | TC-025 |
| 6 | 2026-07-30 | API | **La API no valida el formato del número de tarjeta.** Se probó con `card_number: "1234"` y la API lo rechazó por validación de esquema (min 13 caracteres). | La validación de longitud funciona correctamente. | Resuelto | TC-024 |
| 7 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta (confirmado).** Se probó con `card_number: "4111111111111112"` (Luhn inválido) y la API lo aceptó y creó la transacción. | **Reevaluado (2026-08-06):** Luhn no aplica a las tarjetas MOD-TDF del programa. | Invalidado | TC-024 |
| 8 | 2026-07-30 | API | **La política de contraseñas solo valida longitud mínima (8 caracteres), no complejidad.** Se probó con `password: "12345678"` (solo números) y fue aceptada. | Riesgo de seguridad: contraseñas débiles. Se debe implementar política de complejidad (mayúsculas, minúsculas, números, símbolos). | Abierto | TC-010 |
| 9 | 2026-07-30 | API | **El endpoint `GET /v1/transactions/{id}` no existe.** Solo están implementados `GET /v1/transactions` (listado) y `POST /v1/transactions` (crear). | No se puede obtener el detalle de una transacción individual. La app mobile podría necesitarlo para el detalle desde historial. | Abierto | TC-040, TC-041, TC-042 |
| 10 | 2026-07-30 | API | **La API no valida el formato del CVV en el backend.** Se probó con `cvv: "12"` (2 dígitos) y la API lo rechazó por validación de esquema (min 3 caracteres). | La validación de longitud funciona correctamente. | Resuelto | TC-023 |
| 11 | 2026-07-30 | Gateway | **El mock del gateway no valida la terminal.** Se probó con `terminal_id: "INVALIDO"` y el mock devolvió APPROVED. | El mock no replica la validación del procesador real. Solo afecta pruebas locales. | Resuelto | TC-046 |
| 12 | 2026-07-30 | Gateway | **El procesador real rechaza terminales de prueba con código 89.** Se probó con `terminal_id: "TERM001"` y el procesador devolvió DECLINED con código 89 (terminal desconocida). | Las terminales de prueba no están dadas de alta en la base del procesador. Se debe dar de alta la terminal para probar aprobaciones. | Abierto | TC-044 |
| 13 | 2026-07-30 | API | **La API no valida el checksum de Luhn en el número de tarjeta (confirmado por segunda vez).** Se probó con `card_number: "4111111111111112"` y la API lo aceptó. | **Reevaluado (2026-08-06):** Luhn no aplica a las tarjetas MOD-TDF del programa. | Invalidado | TC-024 |
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
| 25 | 2026-08-04 | POC Verifone | **VCL (Verifone Common Library) enmascara datos de tarjetas en el MSR.** Al leer banda magnética real (mock OFF), el SDK devuelve `ERR_EXECUTION` con PAN y tracks llenos de `FF` (0xFF). `hasClearData: false`. Los tags de transacción (`fetchTxnTags`) también vienen enmascarados. | **Actualizado (2026-08-05):** en pruebas posteriores, los datos llegaron **en claro** (no hasheados). El MSR devuelve `ERR_EXECUTION` pero los tags de transacción (`fetchTxnTags`) contienen PAN, track1 y track2 en claro. VCL no enmascara estos datos en esta configuración. | Resuelto | TC-088, TC-091 |
| 26 | 2026-08-05 | API | **Falta de cobertura de tests para la rama `skip_luhn`/`luhn_check_enabled` en `create_transaction.py`.** | **Invalidado (2026-08-06):** se eliminó la validación Luhn y su flag en todas las capas aplicables. API y gateway aceptan el PAN MOD-TDF del POC `6063001014007403` y siguen rechazando PAN no numérico o fuera de longitud. | Invalidado | TC-024 |
| 27 | 2026-08-05 | POC Verifone | **Bug de decodificación de track2 BCD a ASCII en `PsdkBridge.kt`.** El campo `tags.track2` se mostraba con caracteres corruptos (`"\u00060\u0007..."`) porque se intentaba convertir bytes BCD directamente a ASCII con `bytesAsAscii()`. El track2 en BCD empaqueta dos dígitos decimales por byte (ej: `B6063007014007403D3012F8`). | **Resuelto (2026-08-05):** se agregó la función `bytesAsBcdAscii()` que decodifica cada nibble correctamente: `0xB`→`;` (sentinel inicio), `0xD`→`=` (separador), `0xF`→`?` (sentinel fin), dígitos `0-9`→dígitos ASCII. Ahora `track2` se muestra legible: `;6063007014007403=3012?8`. | Resuelto | TC-092 |

---

### Decisión vigente sobre el PAN (2026-08-06)

Las tarjetas del programa usan dígito verificador MOD-TDF, no Luhn. Por eso API
y gateway validan que el PAN sea numérico y tenga entre 13 y 19 dígitos, pero no
aplican checksum Luhn. Los tests cubren el PAN del POC `6063001014007403`.
