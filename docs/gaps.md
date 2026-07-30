# Gaps — App Solidaridad

Inventario de brechas entre el [alcance](alcance.md) y el estado del
repositorio. **Actualizar este documento en cada cambio implementado** (ver
`AGENTS.md` en la raíz).

Última revisión: 2026-07-30

> ✅ **Último cambio:** Se agregó `luhn_check_enabled` (default `True`) a `Settings` para permitir desactivar el checksum de Luhn en entorno local (`LUHN_CHECK_ENABLED=false`). Esto permite usar tarjetas de prueba que no pasan el algoritmo de Luhn (ej: `6063 0070 1400 7403`). Ver `api/config/settings.py`, `api/application/payments/create_transaction.py`, `api/presentation/dependencies.py`.

Leyenda de estado: `open` · `partial` · `done`

---

## Resumen

El backend local (API → gateway → procesador) cubre buena parte del corazón de
autorización ISO. La app Flutter sigue el contrato borrador de estimación
(ingreso manual, `/v1/sales/gas`, historial mock) y **no** integra hardware
Verifone (banda + térmica).

---

## P0 — Bloquean MVP operable

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P0-01 | Mobile no usa el contrato vivo de ventas | done | Cliente: `POST /v1/transactions` (migrado desde `/v1/sales/gas`). Payload alineado: `product`, `amount` (string), `card_number`, `cvv`, `expiration_date` (opcional). Ver `mobile/lib/features/sales/data/sales_repository.dart`. |
| G-P0-02 | Auth mobile incompleto vs API | partial | Login/register ya envían `installation_id` y manejan `must_change_password`. Pendiente: change-password sin Bearer. |
| G-P0-03 | Token de venta no enlazado a sesión real | done | `SalesCubit.loadHistory()`, `sendIsoMessage()` y `fetchProducts()` reciben el token JWT desde `AuthCubit`. Ver `mobile/lib/features/sales/presentation/cubit/sales_cubit.dart`, `mobile/lib/features/sales/presentation/screens/sale_review_screen.dart`, `mobile/lib/features/sales/presentation/screens/sale_form_screen.dart`. |
| G-P0-04 | Sin listado/detalle de transacciones en API | done | `GET /v1/transactions` con paginación (limit/offset) implementado, filtrado por terminal (`installation_id`). Frontend reemplazó mock por datos reales. Ver `api/presentation/controllers/transactions_controller.py` y `mobile/lib/features/history/presentation/screens/sales_history_screen.dart`. |
| G-P0-05 | Producto/especie y campos de tarjeta desalineados | done | Mobile: `ProductSelector` con catálogo de `GET /v1/products`. Payload envía `product`, `card_number`, `cvv`, `expiration_date`. Ya no envía `card_holder` ni `terminal_origin`. |
| G-P0-06 | Lectura de banda (Verifone) | open | Solo ingreso por teclado. Sin SDK/plugin/canal nativo MSR. Gateway DE22 fijo manual. |
| G-P0-07 | Impresión de ticket en térmica (Verifone) | open | Solo comprobante en UI (`SaleDetailTicket` / status). Sin API de impresora / SDK. |
| G-P0-08 | `installation_id` desde config de terminal | partial | Se inyecta vía `--dart-define=INSTALLATION_ID=...` en build. Pendiente: lectura runtime desde config del device. |
| G-P0-09 | Android bloquea conexiones HTTP / red a backend local | done | Faltaban `INTERNET` permission y `usesCleartextTraffic="true"` en `AndroidManifest.xml` de main. También se agregó CORS (`CORSMiddleware`) en API para compatibilidad web futura. |
| G-P0-10 | ApiConfig usaba IP fija `10.0.2.2` incompatible con web y dispositivos reales | done | `SalesRepository` ahora usa `ApiConfig.baseUrl` igual que `AuthRepository`. URL hardcodeada a prod reemplazada por la configuración de ambiente (`--dart-define` o detección de plataforma). Ver `mobile/lib/features/sales/data/sales_repository.dart`. |

---

## P1 — Fase 0 / robustez incompleta

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P1-01 | Usuario habilitado / altas solo desde central | open | Register abierto; sin flag de habilitación ni política de provisión central en prod. |
| G-P1-02 | Reintentos e idempotencia en mobile | partial | API usa `Idempotency-Key` y estados `PENDING`/`UNKNOWN`. Mobile genera y envía `Idempotency-Key` (timestamp+random) en cada `POST /v1/transactions`. **Pendiente:** reintentar con la misma clave ante timeout/error idempotente, manejar status 202 (ACCEPTED). |
| G-P1-03 | Logs de auditoría en gateway (sin datos sensibles) | open | Falta capa de audit/masking de request-response. |
| G-P1-04 | Deploy AWS + conectividad on-prem | open | Solo stack local (`make dev`). Sin IaC/deploy ni IP fija documentada en repo. |
| G-P1-05 | Base URL / ambientes en mobile | done | `ApiConfig` con `--dart-define=API_BASE_URL=...`; default apunta a localhost. |
| G-P1-06 | Entry mode ISO acorde al modo de captura | open | DE22 fijo `012` (manual). Falta track/swipe cuando haya banda. |

---

## P2 — Post-MVP / mejoras

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P2-01 | UX: manual solo como fallback | open | Hoy el manual es el único flujo. |
| G-P2-02 | Track2 en authorize cuando hay swipe | open | Packer puede soportar DE35 en tests; el builder de purchase no envía track desde swipe. |
| G-P2-03 | App usuario + QR | open | Módulo posterior del PDF; no iniciado. |
| G-P2-04 | Web de observabilidad | open | Módulo posterior del PDF; no iniciado. |
| G-P2-05 | OCR / NFC / iOS | open | Extras del PDF; fuera del MVP Verifone Android. |

---

## Ya cubierto (referencia)

Para no reabrir gaps resueltos, mantener aquí lo cerrado con evidencia breve.

| Ítem | Notas |
|------|-------|
| Auth API (login / register / change-password + JWT) | Implementado en `api/` |
| `POST /v1/transactions` + persistencia + llamada a gateway | Implementado en `api/` |
| `GET /v1/transactions` (listado paginado por terminal) | Implementado en `api/` |
| Catálogo `GET /v1/products` | Implementado en `api/` |
| Gateway `POST /v1/authorize` → ISO → authkig/mock | Implementado en `payment-gateway/` |
| Procesador valida terminal vigente (DE41) | `payment_processor` / authkig |
| UI mobile de login, venta, review, status, historial (mock) | `mobile/` — UI presente; contrato/backend incompletos (ver P0) |
| `installation_id` unificado a terminal id (8 chars) en API | Modelo/seed alineados; falta wiring desde device (G-P0-08) |
| Base URL / ambientes en mobile | `ApiConfig` con `--dart-define` en `mobile/lib/core/config/api_config.dart` |
| RegisterScreen conectado al backend | `mobile/lib/features/auth/presentation/screens/register_screen.dart` usa `BlocConsumer` + `AuthCubit.register()` |
| Status screen con 3 estados (aprobado/rechazado/error conexión POSNET) | `PaymentResult` enum + `connectionError` flag en `SaleResponse`; naranja para pérdida de conectividad POSNET |
| ProductSelector con catálogo del backend | `ProductSelector` widget consume `GET /v1/products` y muestra productos de gas (GARRAFA_10, etc.) en vez de ARS/USD. Payload de venta envía `product`. |
| Token de venta enlazado a sesión real | `sendIsoMessage()`, `fetchProducts()` y `loadHistory()` usan el token JWT desde `AuthCubit`. Ver `mobile/lib/features/sales/presentation/cubit/sales_cubit.dart`, `mobile/lib/features/sales/presentation/screens/sale_review_screen.dart`, `mobile/lib/features/sales/presentation/screens/sale_form_screen.dart`. |

---

## Cómo actualizar este archivo

Al implementar un cambio:

1. Marcar el gap correspondiente (`open` → `partial` o `done`).
2. Ajustar la columna de evidencia (archivos, endpoints, comportamiento).
3. Si se cierra por completo, mover un resumen a **Ya cubierto** y dejar la fila
   en `done` o eliminarla si preferís historial mínimo.
4. Si aparece un gap nuevo descubierto en la implementación, agregarlo con ID
   nuevo (`G-P0-xx` / `G-P1-xx` / `G-P2-xx`) y prioridad coherente.
5. Actualizar la fecha de **Última revisión**.