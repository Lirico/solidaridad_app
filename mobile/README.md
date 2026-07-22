<p align="center">
  <img src="assets/solidaridad_logo.png" alt="Solidaridad Logo" width="450">
</p>

<h1 align="center">GAS Terminal — Solidaridad</h1>

<p align="center">
  <strong>Aplicación Flutter para terminal Verifone</strong><br>
  Captura por banda magnética, ingreso manual como fallback, impresión de ticket térmico.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44+-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12+-blue?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Android-target-green?logo=android" alt="Android">
  <img src="https://img.shields.io/badge/Platform-Verifone-orange" alt="Verifone">
</p>

---

## 📋 Índice

- [Descripción](#-descripción)
- [Arquitectura](#-arquitectura)
- [Flujo de navegación](#-flujo-de-navegación)
- [Features](#-features)
- [Sistema de estilos](#-sistema-de-estilos)
- [Dependencias](#-dependencias)
- [Configuración y ejecución](#-configuración-y-ejecución)
- [Build arguments](#-build-arguments)
- [API REST](#-api-rest)
- [Calidad de código](#-calidad-de-código)
- [Contribución](#-contribución)

---

## 📖 Descripción

Aplicación POS (Point of Sale) para terminales **Verifone Android**, desarrollada en Flutter. Gestiona ventas de gas autorizadas contra el procesador legacy vía mensajería ISO8583 a través de la API cloud y el gateway de pagos del ecosistema Solidaridad.

| Aspecto | Detalle |
|---------|---------|
| **Captura principal** | Lectura de banda magnética |
| **Captura fallback** | Ingreso manual de tarjeta |
| **Comprobante principal** | Ticket impreso en térmica |
| **Comprobante secundario** | Pantalla / historial |
| **Producto** | Catálogo de gas del backend |
| **Target** | Android (terminal Verifone) |

> ⚠️ **Estado actual:** la app implementa el flujo completo con ingreso manual y conexión a API local. La integración con hardware Verifone (banda + térmica) está planificada.

---

## 🏗️ Arquitectura

```
mobile/
├── lib/
│   ├── core/                          # Capa transversal compartida
│   │   ├── config/
│   │   │   └── api_config.dart        # Detección de plataforma + --dart-define
│   │   ├── constants/
│   │   │   └── app_routes.dart        # Definición de rutas de navegación
│   │   ├── formatters/
│   │   │   └── card_formatters.dart   # Formateo de números de tarjeta
│   │   ├── theme/
│   │   │   ├── app_colors.dart        # Paleta de colores
│   │   │   ├── app_spacing.dart       # Constantes de espaciado
│   │   │   ├── app_text_styles.dart   # Estilos de texto
│   │   │   └── app_theme.dart         # Tema global de Material
│   │   ├── validators/
│   │   │   └── auth_validators.dart   # Validación de formularios de auth
│   │   └── widgets/
│   │       ├── splash_screen.dart     # Pantalla de bienvenida con logo
│   │       └── loading_screen.dart    # Pantalla de carga / transición
│   │
│   ├── features/                      # Módulos funcionales (Clean Architecture)
│   │   ├── auth/                      # Autenticación
│   │   │   ├── data/
│   │   │   │   └── auth_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_model.dart
│   │   │   └── presentation/
│   │   │       ├── cubit/
│   │   │       │   ├── auth_cubit.dart
│   │   │       │   └── auth_state.dart
│   │   │       ├── screens/
│   │   │       │   ├── login_screen.dart
│   │   │       │   ├── register_screen.dart
│   │   │       │   └── change_password_screen.dart
│   │   │       └── widgets/
│   │   │           ├── auth_card.dart
│   │   │           ├── auth_header.dart
│   │   │           ├── login_form_fields.dart
│   │   │           ├── register_form_fields.dart
│   │   │           └── change_password_form_fields.dart
│   │   │
│   │   ├── sales/                     # Ventas
│   │   │   ├── data/
│   │   │   │   └── sales_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── sale_model.dart
│   │   │   └── presentation/
│   │   │       ├── cubit/
│   │   │       │   ├── sales_cubit.dart
│   │   │       │   └── sales_state.dart
│   │   │       ├── screens/
│   │   │       │   ├── sale_form_screen.dart
│   │   │       │   ├── sale_review_screen.dart
│   │   │       │   ├── sale_processing_screen.dart
│   │   │       │   └── sale_status_screen.dart
│   │   │       └── widgets/
│   │   │           ├── card_fields_container.dart
│   │   │           ├── currency_selector.dart
│   │   │           ├── sale_form_header.dart
│   │   │           ├── sale_review_header.dart
│   │   │           ├── sale_review_widgets.dart
│   │   │           └── sale_status_content.dart
│   │   │
│   │   └── history/                   # Historial de operaciones
│   │       └── presentation/
│   │           ├── screens/
│   │           │   ├── sales_history_screen.dart
│   │           │   └── sale_detail_screen.dart
│   │           └── widgets/
│   │               ├── sales_history_header.dart
│   │               └── sale_detail_ticket.dart
│   │
│   └── main.dart                      # Punto de entrada + providers
│
├── test/                              # Tests unitarios y de widgets
│   └── widget_test.dart
├── web/                               # Configuración web
├── android/                           # Configuración nativa Android
├── ios/                               # Configuración nativa iOS
├── linux/                             # Configuración nativa Linux
├── macos/                             # Configuración nativa macOS
├── windows/                           # Configuración nativa Windows
└── pubspec.yaml                       # Dependencias y configuración
```

### Principios de Arquitectura

- **Clean Architecture** por feature: cada funcionalidad se organiza en capas `data/`, `domain/` y `presentation/`.
- **State Management** con `flutter_bloc` (patrón Cubit).
- **Código compartido** en `core/` para temas, validadores y constantes.
- **Separación de responsabilidades**: screens se enfocan en layout, widgets encapsulan componentes reutilizables, cubits manejan la lógica de estado.

---

## 🧭 Flujo de navegación

```
SplashScreen (2s)
    ↓
LoadingScreen
    ↓
Login ──→ Register
    ↓
ChangePassword (si must_change_password)
    ↓
SaleForm ──→ SaleReview ──→ SaleProcessing ──→ SaleStatus
    ↓                                                      ↓
SalesHistory ←────────────────────────────────────── (vuelve a SaleForm)
    ↓
SaleDetail
```

| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Splash | `/splash` | Pantalla de bienvenida con logo (2 segundos) |
| Loading | `/loading` | Transición / carga inicial |
| Login | `/login` | Inicio de sesión con usuario/correo y contraseña |
| Register | `/register` | Creación de nueva cuenta |
| Change Password | `/change_password` | Actualización de contraseña obligada |
| Sale Form | `/sales_form` | Ingreso de datos de venta (moneda, monto, tarjeta) |
| Sale Review | `/sale_review` | Confirmación de datos antes de enviar |
| Sale Processing | `/sale_processing` | Pantalla de espera durante el envío |
| Sale Status | `/sale_status` | Resultado de la transacción (aprobada/rechazada/error) |
| Sales History | `/sales_history` | Listado de operaciones realizadas |
| Sale Detail | `/sale_detail` | Ticket completo de una operación |

---

## 🚀 Features

### Autenticación (`auth/`)

| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Login | `/login` | Inicio de sesión con usuario/correo y contraseña. Envía `installation_id` |
| Registro | `/register` | Creación de nueva cuenta |
| Cambio de contraseña | `/change_password` | Actualización forzada si `must_change_password` es `true` |

**Validaciones de formulario:**

| Campo | Regla |
|-------|-------|
| **Nombre** | Obligatorio, mínimo 3 caracteres |
| **Email** | Formato válido (`usuario@dominio.com`) |
| **Contraseña** | 8–20 caracteres, al menos 1 mayúscula, 1 número y 1 carácter especial (`.`, `!`, `@`, etc.) |
| **Confirmar** | Debe coincidir con la contraseña |

### Ventas (`sales/`)

| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Formulario de venta | `/sales_form` | Ingreso de datos: moneda, monto, tarjeta, titular |
| Revisión | `/sale_review` | Confirmación visual antes de enviar al backend |
| Procesando | `/sale_processing` | Espera con spinner mientras se procesa la operación |
| Estado | `/sale_status` | Resultado: aprobada ✅ / rechazada ❌ / error de conexión ⚠️ |

### Historial (`history/`)

| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Historial | `/sales_history` | Listado cronológico de operaciones realizadas |
| Detalle | `/sale_detail` | Ticket completo expandido de una operación |

> **Nota:** el historial actual es _mock_ (datos locales en `SalesCubit`). Cuando la API exponga `GET /v1/transactions` se integrará con el backend.

---

## 🎨 Sistema de Estilos

El proyecto utiliza un sistema de estilos centralizado para garantizar consistencia visual y facilitar la escalabilidad.

### Colores (`AppColors`)

| Constante | Color | Uso |
|-----------|-------|-----|
| `primaryBlue` | `#1A4F9C` | Header, botones principales |
| `primaryOrange` | `#E67E22` | Acentos, alertas comerciales, splash |
| `scaffoldBackground` | `#F4F6F9` | Fondo de pantallas |
| `cardBackground` | `#FFFFFF` | Fondos de cards y formularios |
| `textPrimary` | `black87` | Textos principales |
| `textWhite` | `white` | Texto sobre fondo azul |
| `inputBorder` | `#CED4DA` | Borde de inputs |
| `inputBorderEnabled` | `#E2E8F0` | Borde de inputs habilitados |

### Espaciado (`AppSpacing`)

| Constante | Valor | Uso típico |
|-----------|-------|------------|
| `xs` | 8 | Espaciado mínimo entre elementos |
| `sm` | 10 | Padding interno pequeño |
| `md` | 16 | Espaciado entre secciones |
| `lg` | 20 | Espaciado entre campos de formulario |
| `xl` | 24 | Padding de cards y contenedores |
| `xxl` | 40 | Espaciado antes de botones principales |

### Textos (`AppTextStyles`)

| Estilo | Font Size | Weight | Uso |
|--------|-----------|--------|-----|
| `headerTitle` | 26 | Bold | Título "GAS" en el header |
| `headerSubtitle` | 18 | Light | Subtítulo "TERMINAL" en el header |
| `screenTitle` | 20 | Bold | Títulos de pantalla |
| `formLabel` | 14 | W500 | Labels de campos de formulario |
| `linkButton` | 14 | W500 | Botones de navegación (texto) |

---

## 📦 Dependencias

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `flutter_bloc` | ^9.1.1 | State management con patrón BLoC/Cubit |
| `http` | ^1.6.0 | Cliente HTTP para comunicación con API REST |
| `cupertino_icons` | ^1.0.8 | Iconos iOS |
| `flutter_lints` | ^6.0.0 | Lints y buenas prácticas de código |

**SDK:** Dart ^3.12.2 / Flutter 3.44.4

---

## 🛠️ Configuración y Ejecución

### Requisitos

- Flutter SDK 3.44.4 o superior
- Dart SDK 3.12.2 o superior
- Android SDK (para build APK)

### Instalación

```bash
# Desde la raíz del monorepo
cd mobile

# Instalar dependencias
flutter pub get

# Ejecutar en modo desarrollo (elige dispositivo en el menú)
flutter run
```

### Build de producción

```bash
cd mobile

# Android APK Release
flutter build apk --release

# iOS (no es target primario)
flutter build ios --release

# Web (solo testing local)
flutter build web
```

---

## ⚙️ Build Arguments

La app acepta overrides en tiempo de compilación vía `--dart-define`.

| Variable | Default | Descripción |
|----------|---------|-------------|
| `API_BASE_URL` | Auto-detectado | URL base de la API (ej: `http://192.168.1.100:8000/v1`) |
| `INSTALLATION_ID` | `dev-term` | ID de terminal (hasta 8 caracteres) |

```bash
# Ejemplo: apuntar a servidor en red local
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1

# Ejemplo con installation_id custom
flutter run --dart-define=INSTALLATION_ID=TERM01A

# Build de producción con ambos
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.solidaridad-prod.aws.com/v1 \
  --dart-define=INSTALLATION_ID=TERM01A
```

### Detección automática de `API_BASE_URL`

Cuando **no** se pasa `--dart-define=API_BASE_URL`, el sistema detecta la plataforma:

| Plataforma | URL por defecto |
|------------|-----------------|
| **Web** | `http://localhost:8000/v1` |
| **Android emulador** | `http://10.0.2.2:8000/v1` (loopback del host) |
| **Android real / iOS** | `http://localhost:8000/v1` |

> Para un dispositivo real en la misma red WiFi, **siempre** pasar `--dart-define=API_BASE_URL=http://<IP_DEL_PC>:8000/v1`.

---

## 🌐 API REST

Para levantar todo el backend local desde la raíz del monorepo:

```bash
make dev
```

Ver requisitos, datos demo y puertos en el [README principal](../README.md#levantar-el-backend-local-para-mobile).

### Endpoints

| Método | Endpoint | Descripción | ¿Implementado en app? |
|--------|----------|-------------|-----------------------|
| `POST` | `/v1/auth/login` | Inicio de sesión | ✅ |
| `POST` | `/v1/auth/register` | Registro de usuario | ✅ |
| `POST` | `/v1/auth/change-password` | Cambio de contraseña | ✅ |
| `POST` | `/v1/transactions` | Registro de venta de gas | ⚠️ `SalesRepository` envía a `/v1/sales/gas` — pendiente de alinear |
| `GET` | `/v1/products` | Catálogo de productos | ❌ No integrado |
| `GET` | `/v1/transactions` | Listado de transacciones | ❌ Historial es mock |

> ⚠️ **Inconsistencia conocida:** `SalesRepository` (`/v1/sales/gas`) y la API real (`/v1/transactions`) usan endpoints distintos. Pendiente de unificar (ver gap [G-P0-01](../docs/gaps.md#p0--bloquean-mvp-operable) en `docs/gaps.md`).

---

## 🧪 Calidad de Código

```bash
cd mobile

# Análisis estático
flutter analyze

# Ejecutar tests
flutter test
```

El proyecto sigue las reglas de linting recomendadas por `flutter_lints`. No se permiten errores ni warnings en el análisis estático.

---

## 🤝 Contribución

1. Crear un feature branch desde `dev`: `git checkout -b feature/nombre-feature`
2. Realizar los cambios siguiendo la arquitectura del proyecto
3. Ejecutar `flutter analyze` y `flutter test` antes del commit
4. Crear Pull Request hacia `dev`

---

<p align="center">
  <sub>Proyecto privado — Todos los derechos reservados &copy; Solidaridad</sub>
</p>