# 🔌 Rama 1 — Port del Bridge PSDK de Verifone

> **Estado:** ✅ Completada · **Commit:** `53d5177` · **Rama:** `feature/psdk-bridge-port`
> **Fecha:** 2026-11-08

---

## 🎯 Resumen ejecutivo (en 30 segundos)

La app de ventas (`mobile/`) **solo podía cobrar escribiendo la tarjeta a mano**.
El terminal físico Verifone (donde se pasa la tarjeta por la banda magnética) ya
tenía su SDK integrado en un proyecto de prueba (`poc_verifone/`), pero **no en
la app real**.

Esta Rama 1 **copió todo lo necesario del proyecto de prueba al proyecto real**,
para que la app "aprenda" a hablar con el terminal. Todavía no se usa para
cobrar (eso viene en las Ramas 2, 3 y 4), pero **la base ya está lista**.

---

## 🧩 El problema (contexto)

Imaginá que tenés dos proyectos:

| Proyecto | Qué es | Tiene el SDK de Verifone |
|----------|--------|:------------------------:|
| `poc_verifone/` | Prueba de concepto (laboratorio) | ✅ Sí |
| `mobile/` | La app real de ventas | ❌ No |

El SDK de Verifone es el **puente** entre tu app y el hardware del terminal.
Sin él, la app no puede leer la banda magnética ni imprimir tickets.

**Objetivo de la Rama 1:** llevar el SDK (y todo el código que lo usa) del POC
a la app real, sin romper nada.

---

## 📞 La analogía del "teléfono y el cable"

Para que una persona pueda llamar por teléfono necesita un **cable** y saber
**qué número marcar**. Lo mismo pasa acá:

| Pieza | Analogía | Archivo real |
|-------|----------|--------------|
| **Bridge Kotlin** | El cable que toca el hardware | `PsdkBridge.kt` |
| **MainActivity** | El enchufe que conecta el cable | `MainActivity.kt` |
| **Facade Dart** | El control remoto (traductor) | `psdk_bridge.dart` |
| **Mock** | Una tarjeta falsa de prueba | `psdk_msr_mock.dart` |
| **`.aar` / `.jar`** | El manual del teléfono (SDK) | `libs/` |
| **`build.gradle.kts`** | La lista de ingredientes | `build.gradle.kts` |
| **`AndroidManifest.xml`** | Los permisos | `AndroidManifest.xml` |

---

## 📁 Archivos copiados del POC al mobile

### 1. `PsdkBridge.kt` — el "cable" del lado Android

- **Lenguaje:** Kotlin (nativo de Android).
- **Qué hace:** habla directamente con el hardware del terminal: lee la banda
  (`readMsr`), imprime tickets (`printHtml`), inicializa el SDK, etc.
- **Ruta destino:**
  `mobile/android/app/src/main/kotlin/com/solidaridad/poc_verifone/PsdkBridge.kt`
- **Por qué:** sin esto, la app no tiene forma de tocar el terminal.

> 💡 **Nota:** se mantuvo el package original `com.solidaridad.poc_verifone`
> para no romper los imports que ya existían en el POC.

### 2. `MainActivity.kt` — el "enchufe"

- **Qué es:** el punto de entrada de la app Android.
- **Qué cambió:** ahora registra el bridge (los canales `MethodChannel` y
  `EventChannel`) cuando la app arranca.
- **Ruta destino:**
  `mobile/android/app/src/main/kotlin/com/example/solidaridad_app/MainActivity.kt`
- **Por qué:** el bridge existe, pero nadie lo "enchufaba". Ahora la app lo
  conecta al arrancar.

### 3. `psdk_bridge.dart` — el "control remoto" del lado Flutter

- **Lenguaje:** Dart (el lenguaje de tu app).
- **Qué hace:** es un **traductor**. Tu app Flutter dice "leé la banda" en Dart,
  y este archivo se lo pasa al bridge Kotlin.
- **Ruta destino:** `mobile/lib/psdk/psdk_bridge.dart`
- **Por qué:** Flutter y Kotlin son idiomas distintos; este archivo los une.

### 4. `psdk_msr_mock.dart` — el "simulador"

- **Qué es:** una **tarjeta falsa de prueba** con datos de laboratorio.
- **Ruta destino:** `mobile/lib/psdk/psdk_msr_mock.dart`
- **Por qué:** permite probar el flujo de lectura de banda **sin tener el
  terminal físico a mano**.

### 5. Los binarios del SDK — el "manual del teléfono"

- **Qué son:** los archivos compilados que Verifone entrega (`PaymentSDK-4.1.0-sdi.aar`
  y su `-javadoc.jar`).
- **Ruta destino:** `mobile/android/app/libs/`
- **Por qué:** sin estos archivos, el código Kotlin no compila porque no
  encuentra las clases de Verifone.

---

## ⚙️ Cambios en `build.gradle.kts` (la "lista de ingredientes")

Este archivo configura cómo se compila la app Android. Se le hicieron 4 cambios:

| Cambio | Qué hace | Por qué |
|--------|----------|---------|
| `minSdk = maxOf(flutter.minSdkVersion, 24)` | Exige Android 7.0+ | El SDK de Verifone **requiere** API 24 o superior |
| `implementation(files("libs/PaymentSDK-4.1.0-sdi.aar"))` | Incluye el SDK | Sin esto, Gradle no sabe que existe el `.aar` |
| `proguardFiles(...)` en `release` | Reglas de ofuscación | Evita que el compilador de producción "rompa" las clases del SDK |
| Dependencias de soporte (appcompat, material, gson, etc.) | Librerías auxiliares | El SDK las necesita para funcionar |

---

## 🔐 Permisos en `AndroidManifest.xml`

Android pide permisos para que la app pueda usar el hardware. Se agregaron:

| Permiso | Para qué sirve |
|---------|----------------|
| `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE` | Conectividad de red |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` | Conexión Bluetooth con el terminal |
| `ACCESS_FINE_LOCATION` | Requerido por Bluetooth en Android |
| `READ_PHONE_STATE` | Identificación del dispositivo |
| `SEND_VERILYTICS_KPI` | Telemetría de Verifone |
| `USB_PERMISSION` | Conexión USB con el terminal |
| `<uses-feature usb.host>` | Declara que la app puede usar USB host |

---

## ✅ Cómo se verificó que funcionó

Se corrieron dos chequeos y ambos pasaron:

```bash
# 1. Revisa que el código Dart no tenga errores
flutter analyze
# Resultado: No issues found!

# 2. Compila la app completa para Android
flutter build apk --debug
# Resultado: √ Built build\app\outputs\flutter-apk\app-debug.apk
```

> El hecho de que **compile** confirma que el SDK se integró correctamente y que
> el código Kotlin del bridge es válido.

---

## 🚧 Qué NO se hizo todavía (y qué viene)

La Rama 1 **solo copió el "cable"**. Ahora la app "sabe hablar" con el terminal,
pero todavía nadie le dice que lo haga. El plan completo es de **4 ramas**:

| Rama | Qué hace | Estado |
|------|----------|:------:|
| **Rama 1** | Portar el bridge PSDK | ✅ Hecha |
| **Rama 2** | Conectar `WaitingForCardScreen` al PSDK + navegación "Tarjeta" | ⏳ Pendiente |
| **Rama 3** | Gateway con `entry_mode` dinámico + API con `entry_mode`/`track2` | ⏳ Pendiente |
| **Rama 4** | Mobile `registerSale` con `entry_mode` + actualizar `docs/gaps.md` | ⏳ Pendiente |

---

## 📖 Glosario

| Término | Qué significa (en simple) |
|---------|---------------------------|
| **PSDK** | Payment SDK — el kit de desarrollo de Verifone para hablar con el terminal |
| **SDI** | El protocolo interno de Verifone que usa el PSDK |
| **`.aar`** | Paquete de Android que contiene código + recursos (como un `.zip` con código) |
| **`.jar`** | Paquete de Java con código compilado |
| **MethodChannel** | Canal de comunicación Flutter → Android (llamadas de ida y vuelta) |
| **EventChannel** | Canal de comunicación Android → Flutter (eventos en vivo) |
| **MSR** | Magnetic Stripe Reader — el lector de banda magnética |
| **Bridge** | Código que conecta dos mundos (Flutter y el hardware) |
| **POC** | Proof of Concept — prueba de concepto / laboratorio |

---

## 🔗 Referencias

- Código del bridge: `mobile/android/app/src/main/kotlin/com/solidaridad/poc_verifone/PsdkBridge.kt`
- Facade Dart: `mobile/lib/psdk/psdk_bridge.dart`
- Mock de prueba: `mobile/lib/psdk/psdk_msr_mock.dart`
- SDK: `mobile/android/app/libs/`
- Config Android: `mobile/android/app/build.gradle.kts`
- Permisos: `mobile/android/app/src/main/AndroidManifest.xml`
- Registro de avance: [`docs/gaps.md`](gaps.md) (gap G-P0-06 → `partial`)
