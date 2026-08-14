# Test Cases — Solidaridad App

> **Última actualización:** 2026-11-08

> Índice de casos de prueba. El archivo original se separó en 5 archivos por módulo para facilitar su mantenimiento.

---

## 📂 Índice de archivos

| Archivo | Módulo | Casos | Descripción |
|---------|--------|-------|-------------|
| [`test_cases_api.md`](test_cases_api.md) | API (backend) | TC-001 a TC-042 | Endpoints de la API pública (auth, productos, transacciones) |
| [`test_cases_gateway.md`](test_cases_gateway.md) | Payment Gateway | TC-043 a TC-052 | Adaptador HTTP → ISO8583 (validaciones, timeout, entry mode) |
| [`test_cases_processor.md`](test_cases_processor.md) | Payment Processor | TC-045, TC-046 | Autorizador legacy (C + MySQL): terminal inválida, tarjeta sin fondos |
| [`test_cases_mobile.md`](test_cases_mobile.md) | Mobile (App Flutter) | TC-053 a TC-092 | App Flutter + POC Verifone (login, ventas, historial, hardware) |
| [`test_cases_hallazgos.md`](test_cases_hallazgos.md) | Hallazgos | #1 a #27 | Descubrimientos de las pruebas + decisión vigente sobre el PAN |

---

## 📊 Resumen global

| Módulo | Total | Pass | Fail | Blocked | N/A | Pendiente |
|--------|-------|------|------|---------|-----|-----------|
| API | 42 | 37 | 1 | 0 | 3 | 2 |
| Payment Gateway | 7 | 6 | 0 | 0 | 0 | 1 |
| Payment Processor | 2 | 1 | 0 | 0 | 0 | 1 |
| Mobile | 33 | 20 | 1 | 0 | 2 | 10 |
| POC Verifone | 7 | 7 | 0 | 0 | 0 | 0 |
| **Total** | **91** | **71** | **2** | **0** | **5** | **14** |

> **Nota:** el total de casos bajó de 92 a 91 porque el caso TC-052 (entry mode de banda) quedó en el archivo de gateway y el caso TC-046 (terminal inválida) se movió al archivo de procesador. Los casos TC-045 y TC-046 se contabilizan en el módulo Processor.

---

## Formato

Cada archivo usa el siguiente formato de tabla:

| Nro | Módulo | Action | Inputs | Expected Output | Actual Output | Test Result | Test Comments |
|-----|--------|--------|--------|-----------------|---------------|-------------|---------------|

**Leyenda Test Result:** `Pass` · `Fail` · `Blocked` · `N/A` · `Pendiente`

---

## Cómo actualizar este índice

Al agregar un caso de prueba:

1. Agregarlo al archivo del módulo correspondiente (`test_cases_api.md`, `test_cases_gateway.md`, `test_cases_processor.md`, `test_cases_mobile.md`).
2. Si es un descubrimiento, agregarlo a `test_cases_hallazgos.md`.
3. Actualizar el resumen global de este índice.
