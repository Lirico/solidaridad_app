# POC Verifone (V660P)

App Flutter semilla para integrar el **PaymentSDK** de Verifone en terminal V660P.

## Qué hay armado

- Contador de smoke-test UI.
- Bridge Android ↔ Dart (`MethodChannel` + `EventChannel`).
- AAR **PaymentSDK-4.1.0-sdi** en `android/app/libs/` (`SdiManager`: impresora / MSR).
- API Dart: [`lib/psdk/psdk_bridge.dart`](lib/psdk/psdk_bridge.dart)

### Métodos Dart listos

| Método | Acción nativa |
|--------|----------------|
| `initialize()` | `PaymentSdk.create` + `initialize(listener)` |
| `getStatus()` | snapshot (`created` / `initialized` / `sdiReady`) |
| `getDeviceInfo()` | `PaymentSdk.getDeviceInformation()` |
| `readMsr(timeoutSec:)` | `SdiMsr.read` + `SdiData.fetchTxnTags` (POC: sin enmascarar) |
| `printHtml(html)` | `SdiPrinter.printHTML` (ticket térmico) |
| `tearDown()` | `PaymentSdk.tearDown()` |
| `statusEvents` | stream de `handleStatus` |

En la UI:

- Switch **Mock solo lectura de banda** → solo `readMsr` usa el fixture
  [`lib/psdk/psdk_msr_mock.dart`](lib/psdk/psdk_msr_mock.dart). Init, status,
  device info, tear down e impresión son siempre PSDK nativo.
- **Venta mock** → respuesta tipo API (`SaleResponseMock`) → `ReceiptData`
  (simula backend; no es mock de hardware).
- **Ver ticket** → texto plano en log (`ReceiptFormatter`).
- **Imprimir ticket** → `printHtml` → térmica real (requiere Init + `sdiReady`).

Flujo en V660P sin whitelist: **Init PSDK** → **Venta mock** → **Imprimir ticket**.
Leer banda (mock) es opcional para inspeccionar el payload.

## AARs

Ver [`android/app/libs/README.md`](android/app/libs/README.md).

Activo: `PaymentSDK-4.1.0-sdi.aar` (package `com.verifone.sdi.payment_sdk`).

## Correr en el V660P

```bash
cd poc_verifone
flutter pub get
flutter devices
flutter run -d <device_id>
```

En la UI: **Init PSDK** → esperar event con `success` / `sdiReady` → **Status** / **Device info**.

## Estructura del bridge

```
Dart PsdkBridge
    │ MethodChannel / EventChannel
    ▼
Kotlin PsdkBridge  →  PaymentSDK (SDI AAR)  →  V660P
```
