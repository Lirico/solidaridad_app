# Alcance — App Solidaridad (Terminal Comercio)

Documento de alcance funcional y de producto. Combina lo definido en la estimación
*App Solidaridad - Terminal Virtual Comercio* (Fase 0 y módulos posteriores) con el
ajuste de producto posterior: despliegue sobre **terminales Verifone físicas**.

Fuente original de estimación: discusión comercial/técnica preliminar (PDF).
Este documento es la referencia viva en el repositorio.

---

## 1. Contexto y pivot de producto

### Diseño original (estimación Fase 0)

La Fase 0 se planteó como MVP de **urgencia operativa**: ventas de gas desde una
**app móvil de comercio** sin depender de nuevas terminales físicas. El backend en
la nube actúa como terminal virtual e integra contra el procesador existente
mediante mensajería ISO.

En ese diseño, la captura de tarjeta era **ingreso manual** y el comprobante se
mostraba **en pantalla**.

### Decisión actual

El negocio decantó por **terminales Verifone**. En ese hardware no tiene sentido
entregar solo el flujo de celular del MVP:

- La justificación del dispositivo es **lectura de banda magnética** e
  **impresión de ticket** en térmica.
- El ingreso manual pasa a ser **fallback**, no el flujo principal.
- El comprobante en pantalla puede permanecer como respaldo operativo; el
  entregable principal de comprobante es el **ticket impreso**.

El backend (API → gateway ISO → procesador) sigue siendo la columna vertebral;
el cambio de producto impacta sobre todo la **capa de app / nativa** y el
**modo de entrada** hacia el mensaje ISO.

---

## 2. Alcance prioritario (MVP operable en Verifone)

Objetivo: app Android (Flutter) en terminal Verifone para venta de gas,
autorizada por el procesador existente vía ISO, con captura por banda e
impresión de ticket.

### 2.1 Aplicación mobile (comercio)

- App Android en Flutter, orientada a operación de venta en terminal.
- Login de usuario y cambio de contraseña.
- Identificador de terminal (`installation_id` / terminal id, 8 caracteres)
  configurado en el dispositivo; el operador no lo inventa por operación.
  **2026-08-19:** el `installation_id` ya no es un valor mockeado/hardcodeado
  en la app. En el arranque, `TerminalProvisioner` (`mobile/lib/core/terminal/
  terminal_provisioner.dart`) llama a `POST /v1/terminals/resolve` enviando el
  `logical_device_id` físico del terminal y recibe el `installation_id`
  provisionado en la central, que persiste en `SharedPreferences` y se envía en
  login/register (viaja en el token JWT; la transacción usa el `installation_id`
  del token, no del body). El `logical_device_id` se lee del hardware Verifone
  vía el bridge PSDK: `TerminalProvisioner` inicializa el SDK
  (`PsdkBridge.initialize()`) y luego `PsdkBridge.getDeviceInfo()` (campo
  `logicalDeviceId`); si no hay hardware o el init/lectura falla, se cae al
  define `kLogicalDeviceId` (`--dart-define=LOGICAL_DEVICE_ID`, default
  `V660P-DEMO-0001`) como respaldo de lab.


- Pantalla inicial simple orientada a la venta.
- Flujo de venta de gas:
  - selección de producto/especie (catálogo de gas);
  - ingreso de cantidad/importe según contrato vigente;
  - **lectura de banda** como flujo principal;
  - **ingreso manual** como fallback;
  - confirmación previa antes de enviar;
  - envío al backend;
  - visualización de resultado (aprobada / rechazada / error de
    comunicación o procesamiento).
- Mensajes de error comprensibles a partir de la respuesta del backend/procesador.
- **Impresión de ticket** en la térmica del Verifone al completar la operación
  (cuando corresponda).
- Comprobante en pantalla (respaldo / reimpresión visual).
- Listado básico de transacciones y detalle/comprobante.
- Manejo básico de carga, errores y reintentos (incluida idempotencia).
- Build Android instalable en el modelo de terminal acordado.

**Fuera de alcance de branding/UX avanzada** (igual que la estimación): no se
incluye branding propio, logo, tipografía de marca, design system ni iteraciones
visuales fuera de lo funcional acordado. UI estándar Material, priorizando
claridad operativa.

### 2.2 Backend / API pública

- API pública segura para la app.
- Autenticación, sesión por token, cambio de contraseña.
- Validación de usuario habilitado (según política de altas).
- **Provisión de usuarios centralizada**: los usuarios (empleados) son dados
  de alta únicamente por la empresa; no se usa el registro desde la app. El
  endpoint `POST /v1/auth/register` se mantiene como utilidad para que la
  empresa registre usuarios vía Postman/central.
- Terminal origen: el `installation_id` del login es el terminal id que se
  envía al procesador; la **alta/vigencia de terminal** la valida el procesador.
  **2026-08-19:** se agregó `POST /v1/terminals/resolve` que mapea el
  `logical_device_id` físico del terminal al `installation_id` provisionado en
  la central (tabla `terminal_devices`, migración `20260819_0007`, seed local).
  La app lo llama en el arranque para obtener el terminal id real (no mockeado).

- Endpoint de registro de venta (contrato actual: `POST /v1/transactions`).
- Endpoint de anulación de venta aprobada:
  `POST /v1/transactions/{transaction_number}/void`, con reingreso de tarjeta
  (sin persistir PAN) e `Idempotency-Key`.
- Validación de datos mínimos: producto/especie, importe/cantidad, datos de
  tarjeta requeridos según modo de entrada, terminal origen.
- Persistencia de la transacción, delegación al gateway, normalización de
  estados (`aprobada` / `rechazada` / `anulada` / `error` / `timeout` /
  equivalentes).
- Traducción de códigos técnicos a mensajes claros para la app.
- Endpoints de listado básico y detalle/comprobante.
- Logs básicos de auditoría y soporte (sin almacenar datos sensibles completos
  de tarjeta). Incluye historial append-only de estados de transacción en
  Postgres (`transaction_status_events`); sin exposición HTTP en esta etapa.
- Ambientes y deploy (objetivo: AWS, con conectividad segura al procesador
  on-premises).

### 2.3 Gateway de pagos / mensajería ISO

- Construcción y envío del mensaje ISO de venta al procesador.
- Construcción y envío del mensaje ISO de anulación (`0200` / `020000`).
- Parseo de respuesta e interpretación de aprobación / rechazo / error.
- Timeouts y errores de comunicación.
- Respuesta normalizada hacia la API.
- Registro técnico request/response para soporte, sin PAN/CVV/track completos.
- Entry mode coherente con la captura real (manual vs banda / track cuando
  aplique).

### 2.4 Procesador existente (on-premises)

- Sigue siendo responsable de validación de tarjeta, saldo y autorización.
- El PAN del programa usa el dígito verificador MOD-TDF del procesador; la API
  y el gateway validan formato (solo dígitos y longitud), pero no aplican Luhn.
- Valida que la terminal esté dada de alta/vigente.
- La app y la API no acceden a bases internas de usuarios/tarjetas en este MVP.
- Altas de comercios, usuarios y terminales: provisión desde central sobre
  base/configuración (no administración completa en la app).

### 2.5 Arquitectura y conectividad

```
App Flutter (Verifone)
  → API pública (cloud)
    → Gateway ISO
      → Procesador on-premises (authkig / legacy)
```

- La app no habla directo con el procesador.
- Conectividad segura cloud → on-prem (p. ej. salida con IP fija autorizada).

---

## 3. Aclaraciones de producto acordadas

| Tema | Definición |
|------|------------|
| `installation_id` | Es el terminal id configurado en la terminal (hasta 8 caracteres). No lo define el cliente por cada venta. |
| Alta de terminal | La valida el procesador en la autorización. |
| Captura principal | Lectura de banda en Verifone. |
| Captura fallback | Ingreso manual. |
| Comprobante principal | Ticket impreso en térmica. |
| Comprobante secundario | Visualización en pantalla / historial. |
| Moneda/producto | Catálogo de productos de gas del backend (no ARS/USD genéricos del borrador mobile). Cada producto informa su unidad de medida con textos `singular` y `plural`: `unidad`/`unidades` para garrafas y tubos, y `m3`/`m3` para granel. |

---

## 4. Fuera del MVP inmediato (módulos posteriores del PDF)

Siguen siendo opcionales y no necesariamente secuenciales. No bloquean el MVP
Verifone salvo que se prioricen aparte.

### 4.1 App de usuario + flujo QR (~100–140 h en estimación)

- App de usuario final, escaneo de QR cerrado generado por comercio.
- Adaptación de backend/servicio QR existente.
- Historial y comprobantes del canal usuario.

### 4.2 App web de observabilidad (~100 h)

- Consulta operativa interna: filtros por fecha, comercio, usuario, especie,
  estado, código de respuesta; detalle y métricas básicas.
- No reemplaza reportes/conciliación del procesador ni administración completa
  de altas.

### 4.3 Extras de captura / plataformas

- OCR / foto de tarjeta (~20 h estimadas).
- NFC (estimación a determinar tras validación técnica; no es contactless POS).
- Soporte iOS (~60 h estimadas; Fase 0 prioriza Android/terminal).

---

## 5. Estimación de referencia (PDF, Fase 0 original)

La estimación preliminar de Fase 0 (terminal *virtual* + ingreso manual) fue:

| Componente | Horas |
|------------|------:|
| App Flutter comercio | 80 |
| Sistema de pagos / ISO | 40 |
| Backend API mobile | 40 |
| Integración, QA, deploy, puesta en marcha y reuniones | 40 |
| **Total Fase 0** | **200** |

Esa cifra **no incluye** el delta de producto Verifone (SDK/banda, impresión
térmica, entry mode ISO, build/empaquetado para el modelo de terminal). Ese
delta debe estimarse aparte cuando se fije modelo Verifone y SDK disponibles.

---

## 6. Criterios de aceptación del MVP actual

1. Un operador puede autenticarse en la terminal y operar ventas de gas.
2. La captura principal es por banda; el manual funciona como respaldo.
3. La operación llega al procesador vía API + gateway ISO con terminal válida.
4. El resultado se muestra en UI con mensaje claro.
5. Se imprime ticket en la térmica cuando la operación lo requiere.
6. Existe historial/detalle consultable desde la app (backed por API).
7. No se persisten PAN/CVV/track completos en API ni gateway.
