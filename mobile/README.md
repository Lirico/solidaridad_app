# GAS Terminal - POS Virtual

Aplicación móvil POS (Point of Sale) virtual desarrollada en Flutter para la gestión de ventas de gas, autenticación de usuarios e historial de operaciones. Conecta con APIs REST en AWS para el procesamiento de transacciones.

---

## 🏗️ Arquitectura

```
mobile/
├── lib/
│   ├── core/                     # Capa transversal compartida
│   │   ├── constants/            # Constantes de la aplicación
│   │   │   └── app_routes.dart   # Definición de rutas de navegación
│   │   ├── formatters/           # Formateadores reutilizables
│   │   │   └── card_formatters.dart
│   │   ├── theme/                # Sistema de estilos centralizado
│   │   │   ├── app_colors.dart      # Paleta de colores
│   │   │   ├── app_spacing.dart     # Constantes de espaciado
│   │   │   ├── app_text_styles.dart # Estilos de texto
│   │   │   └── app_theme.dart       # Tema global de Material
│   │   └── validators/           # Validadores de formularios
│   │       └── auth_validators.dart # Validación de auth (email, password, etc.)
│   │
│   ├── features/                 # Módulos de funcionalidad (Clean Architecture)
│   │   ├── auth/                 # Módulo de autenticación
│   │   │   ├── data/             # Capa de datos
│   │   │   │   └── auth_repository.dart
│   │   │   ├── domain/           # Capa de dominio (modelos)
│   │   │   │   └── auth_model.dart
│   │   │   └── presentation/     # Capa de presentación
│   │   │       ├── cubit/        # State management (Bloc/Cubit)
│   │   │       │   ├── auth_cubit.dart
│   │   │       │   └── auth_state.dart
│   │   │       ├── screens/      # Pantallas
│   │   │       │   ├── login_screen.dart
│   │   │       │   ├── register_screen.dart
│   │   │       │   └── change_password_screen.dart
│   │   │       └── widgets/      # Componentes UI reutilizables
│   │   │           ├── auth_card.dart
│   │   │           ├── auth_header.dart
│   │   │           ├── login_form_fields.dart
│   │   │           ├── register_form_fields.dart
│   │   │           └── change_password_form_fields.dart
│   │   │
│   │   ├── sales/                # Módulo de ventas
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
│   │   │       │   └── sale_status_screen.dart
│   │   │       └── widgets/
│   │   │           ├── card_fields_container.dart
│   │   │           ├── currency_selector.dart
│   │   │           ├── sale_form_header.dart
│   │   │           ├── sale_review_content.dart
│   │   │           ├── sale_review_header.dart
│   │   │           ├── sale_review_widgets.dart
│   │   │           └── sale_status_content.dart
│   │   │
│   │   └── history/              # Módulo de historial
│   │       └── presentation/
│   │           ├── screens/
│   │           │   ├── sales_history_screen.dart
│   │           │   └── sale_detail_screen.dart
│   │           └── widgets/
│   │               └── sale_detail_ticket.dart
│   │
│   └── main.dart                 # Punto de entrada de la aplicación
│
├── test/                         # Tests unitarios y de widgets
├── web/                          # Configuración para Web
├── android/                      # Configuración nativa Android
├── ios/                          # Configuración nativa iOS
├── linux/                        # Configuración nativa Linux
├── macos/                        # Configuración nativa macOS
├── windows/                      # Configuración nativa Windows
└── pubspec.yaml                  # Dependencias y configuración del proyecto
```

### Principios de Arquitectura

- **Clean Architecture** por feature: cada funcionalidad se organiza en capas `data/`, `domain/` y `presentation/`
- **State Management** con `flutter_bloc` (patrón Cubit)
- **Código compartido** en `core/` para temas, validadores y constantes
- **Separación de responsabilidades**: screens se enfocan en layout, widgets encapsulan componentes reutilizables, cubits manejan la lógica de estado

---

## 🚀 Features

### Autenticación (`auth/`)
| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Login | `/login` | Inicio de sesión con usuario/correo y contraseña |
| Registro | `/register` | Creación de nueva cuenta |
| Cambio de contraseña | `/change_password` | Actualización de contraseña |

**Validaciones de formulario:**
- **Nombre**: obligatorio, mínimo 3 caracteres
- **Email**: formato válido (`usuario@dominio.com`)
- **Contraseña**: 8-20 caracteres, al menos 1 mayúscula, 1 número y 1 caracter especial (`.`, `!`, `@`, etc.)
- **Confirmar contraseña**: debe coincidir con el campo contraseña

### Ventas (`sales/`)
| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Formulario de venta | `/sales_form` | Ingreso de datos de venta (moneda, monto, tarjeta) |
| Revisión | `/sale_review` | Confirmación de datos antes de enviar |
| Estado | `/sale_status` | Resultado de la transacción (aprobada/rechazada) |

### Historial (`history/`)
| Pantalla | Ruta | Descripción |
|----------|------|-------------|
| Historial | `/sales_history` | Listado de operaciones realizadas |
| Detalle | `/sale_detail` | Ticket completo de una operación |

---

## 🎨 Sistema de Estilos

El proyecto utiliza un sistema de estilos centralizado para garantizar consistencia visual y facilitar la escalabilidad.

### Colores (`AppColors`)

| Constante | Color | Uso |
|-----------|-------|-----|
| `primaryBlue` | `#1A4F9C` | Header, botones principales |
| `primaryOrange` | `#E67E22` | Acentos, alertas comerciales |
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

## 📦 Dependencias Principales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `flutter_bloc` | ^9.1.1 | State management con patrón BLoC/Cubit |
| `http` | ^1.6.0 | Cliente HTTP para comunicación con API REST |
| `cupertino_icons` | ^1.0.8 | Iconos iOS |
| `flutter_lints` | ^6.0.0 | Lints y buenas prácticas de código |

SDK: Dart ^3.12.2 / Flutter 3.44.4

---

## 🛠️ Configuración y Ejecución

### Requisitos
- Flutter SDK 3.44.4 o superior
- Dart SDK 3.12.2 o superior

### Instalación

```bash
# Desde la raíz del monorepo
cd mobile

# Instalar dependencias
flutter pub get

# Ejecutar en modo desarrollo
flutter run
```

### Build de producción

```bash
cd mobile

# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web
```

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

## 🌐 API REST

Para levantar todo el backend local desde la raíz del monorepo:

```bash
make dev
```

Ver requisitos, datos demo y puertos en el
[README principal](../README.md#levantar-el-backend-local-para-mobile).

La URL base se encuentra configurada actualmente en los repositorios:

- `mobile/lib/features/auth/data/auth_repository.dart` — Endpoints de autenticación
- `mobile/lib/features/sales/data/sales_repository.dart` — Endpoints de ventas

Para probar desde Android Emulator, el entorno mobile debe usar
`http://10.0.2.2:8000/v1`; para iOS Simulator,
`http://127.0.0.1:8000/v1`. La URL incluida actualmente en el código apunta a
producción.

**Endpoints esperados:**
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/v1/auth/login` | Inicio de sesión |
| POST | `/v1/auth/register` | Registro de usuario |
| POST | `/v1/auth/change-password` | Cambio de contraseña |
| POST | `/v1/sales/gas` | Registro de venta de gas |

> **Estado local actual:** autenticación está disponible, pero
> `/v1/sales/gas` todavía no está implementado en la API local. El gateway y el
> autorizador pueden probarse por separado; ver el README principal.

---

## 🤝 Contribución

1. Crear un feature branch desde `dev`: `git checkout -b feature/nombre-feature`
2. Realizar los cambios siguiendo la arquitectura del proyecto
3. Ejecutar `flutter analyze` y `flutter test` antes del commit
4. Crear Pull Request hacia `dev`

---

## 📄 Licencia

Proyecto privado - Todos los derechos reservados.