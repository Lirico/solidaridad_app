# Gaps — App Solidaridad

Inventario de brechas entre el [alcance](alcance.md) y el estado del
repositorio. **Actualizar este documento en cada cambio implementado** (ver
`AGENTS.md` en la raíz).

Última revisión: 2026-07-18

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
| G-P0-01 | Mobile no usa el contrato vivo de ventas | open | Cliente: `POST /v1/sales/gas` (`mobile/.../sales_repository.dart`). API: `POST /v1/transactions`. |
| G-P0-02 | Auth mobile incompleto vs API | partial | Login/register ya envían `installation_id` y manejan `must_change_password`. Pendiente: change-password sin Bearer. |
| G-P0-03 | Token de venta no enlazado a sesión real | open | `SalesCubit` usa token mock; no consume el JWT de auth. |
| G-P0-04 | Sin listado/detalle de transacciones en API | open | Solo `POST /v1/transactions`. PDF/alcance piden listado y detalle. Historial mobile = mock. |
| G-P0-05 | Producto/especie y campos de tarjeta desalineados | open | Mobile: ARS/USD y no envía CVV/expiry. API: enum productos gas + `cvv`/`expiration_date` requeridos. |
| G-P0-06 | Lectura de banda (Verifone) | open | Solo ingreso por teclado. Sin SDK/plugin/canal nativo MSR. Gateway DE22 fijo manual. |
| G-P0-07 | Impresión de ticket en térmica (Verifone) | open | Solo comprobante en UI (`SaleDetailTicket` / status). Sin API de impresora / SDK. |
| G-P0-08 | `installation_id` desde config de terminal | partial | Se inyecta vía `--dart-define=INSTALLATION_ID=...` en build. Pendiente: lectura runtime desde config del device. |

---

## P1 — Fase 0 / robustez incompleta

| ID | Gap | Estado | Evidencia / notas |
|----|-----|--------|-------------------|
| G-P1-01 | Usuario habilitado / altas solo desde central | open | Register abierto; sin flag de habilitación ni política de provisión central en prod. |
| G-P1-02 | Reintentos e idempotencia en mobile | open | API usa `Idempotency-Key` y estados `PENDING`/`UNKNOWN`; mobile no reintenta con la misma clave ni maneja 202. |
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
| Catálogo `GET /v1/products` | Implementado en `api/` |
| Gateway `POST /v1/authorize` → ISO → authkig/mock | Implementado en `payment-gateway/` |
| Procesador valida terminal vigente (DE41) | `payment_processor` / authkig |
| UI mobile de login, venta, review, status, historial (mock) | `mobile/` — UI presente; contrato/backend incompletos (ver P0) |
| `installation_id` unificado a terminal id (8 chars) en API | Modelo/seed alineados; falta wiring desde device (G-P0-08) |
| Base URL / ambientes en mobile | `ApiConfig` con `--dart-define` en `mobile/lib/core/config/api_config.dart` |
| RegisterScreen conectado al backend | `mobile/lib/features/auth/presentation/screens/register_screen.dart` usa `BlocConsumer` + `AuthCubit.register()` |

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