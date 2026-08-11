# 🧾 Rama 3 — Gateway con `entry_mode` dinámico + API con `entry_mode`/`track2`

> **Estado:** ✅ Completada · **Commit:** `f9d5e4c` · **Rama:** `feature/entry-mode-api`
> **Fecha:** 2026-11-08

---

## 🎯 Resumen ejecutivo (en 30 segundos)

Cuando se cobra con tarjeta, el sistema necesita saber **cómo se leyó la tarjeta**:
si se **pasó por la banda magnética** (swipe) o si se **escribió a mano** (manual).

Antes de esta Rama 3, el gateway **siempre asumía que era manual** (código `012`),
sin importar cómo se leyó la tarjeta. Eso está mal: si la tarjeta se pasó por la
banda, el mensaje que se manda al procesador debe ser distinto.

Esta Rama 3 le enseñó al **gateway** y a la **API** a distinguir entre los dos
modos y a armar el mensaje ISO correcto en cada caso.

---

## 🧩 El problema (contexto)

El flujo de un cobro con tarjeta es así:

```
App mobile  →  API  →  Gateway  →  Procesador (ISO 8583)
```

El **Gateway** es el que arma el mensaje ISO (el "idioma" que entiende el
procesador). Dentro de ese mensaje hay un campo llamado **DE22** que dice
**cómo se leyó la tarjeta**:

| Código DE22 | Qué significa |
|:-----------:|---------------|
| `012` | Manual (se escribió el número a mano) |
| `022` | Banda magnética (se pasó la tarjeta por el lector) |

**El problema:** el gateway tenía el DE22 **fijo en `012`** (manual), sin importar
cómo se leyó la tarjeta. Y además, cuando la tarjeta se lee por banda, los datos
que se mandan son distintos (se manda el **track2** de la banda, no el número de
tarjeta + vencimiento).

**Objetivo de la Rama 3:** que el gateway y la API sepan distinguir entre manual
y banda, y armen el mensaje ISO correcto en cada caso.

---

## 📞 La analogía del "formulario de compra"

Imaginá que comprás por internet y tenés que llenar un formulario. Hay dos formas
de pagar:

| Forma de pago | Qué llenás en el formulario |
|---------------|-----------------------------|
| **Manual** | Escribís el número de tarjeta, el vencimiento y el CVV a mano |
| **Banda** | Pasás la tarjeta por un lector y el formulario se llena solo con los datos de la banda |

El formulario (el mensaje ISO) es el mismo, pero **los campos que se llenan son
distintos** según cómo pagaste. La Rama 3 le enseñó al sistema a llenar el
formulario correcto según el método.

---

## 🗺️ El flujo completo (qué cambió de punta a punta)

```
App mobile
   │  manda: entry_mode ("012" o "022") + track2 (si es banda)
   ▼
API  ──►  recibe entry_mode/track2 en el request
   │  manda: entry_mode/track2 al gateway
   ▼
Gateway  ──►  arma el mensaje ISO según entry_mode/track2
   │
   ▼
Procesador (ISO 8583)
```

---

## 📁 Cambios en el Gateway (`payment-gateway/`)

### 1. `domain/authorization.py` — el "contrato" del comando

- **Qué es:** define la estructura del comando de autorización (los datos que
  necesita el gateway para cobrar).
- **Qué cambió:** se le agregaron **dos campos nuevos**:
  - `entry_mode: str` — cómo se leyó la tarjeta (`"012"` manual o `"022"` banda).
  - `track2: str | None` — los datos de la banda magnética (opcional; solo si
    se leyó por banda).

> 💡 **Por qué:** el gateway necesita saber estos datos para armar el mensaje ISO
> correcto. Antes no los tenía.

### 2. `presentation/schemas/authorize.py` — el "formulario de entrada"

- **Qué es:** define qué campos acepta el gateway cuando le llega un request HTTP.
- **Qué cambió:** ahora acepta `entry_mode` y `track2` (opcionales).

> 💡 **Por qué:** si la API le manda estos datos, el gateway tiene que poder
> recibirlos.

### 3. `infrastructure/iso/message_builder.py` — el "corazón" del cambio ⭐

- **Qué es:** el archivo que **arma el mensaje ISO** que se manda al procesador.
- **Qué cambió:** ahora decide **qué campos usar según cómo se leyó la tarjeta**:

| Caso | DE22 | Campos de tarjeta que usa |
|------|:----:|---------------------------|
| **Banda** (viene `track2`) | `022` | **DE35** (track2 de la banda) — NO usa DE2 ni DE14 |
| **Manual** (no viene `track2`) | `012` | **DE2** (número de tarjeta) + **DE14** (vencimiento) |

> 💡 **Por qué:** cuando la tarjeta se lee por banda, el procesador espera el
> **track2** (DE35), no el número de tarjeta + vencimiento (DE2 + DE14). Antes
> el DE22 era fijo `012` desde la config; ahora sale del `entry_mode` que llega.

### 4. `application/payments/authorize_payment.py` — el "traductor"

- **Qué es:** el caso de uso que normaliza los datos del request.
- **Qué cambió:** propaga `entry_mode`/`track2` desde el request al comando.

### 5. `presentation/controllers/authorize_controller.py` — el "portero"

- **Qué es:** el controller HTTP del gateway.
- **Qué cambió:** pasa `entry_mode`/`track2` del request al caso de uso.

---

## 📁 Cambios en la API (`api/`)

### 6. `presentation/schemas/transactions.py` — el "formulario de entrada"

- **Qué es:** define qué campos acepta la API cuando la app mobile registra una venta.
- **Qué cambió:** el `CreateTransactionRequest` ahora acepta:
  - `entry_mode: str` — opcional, default `"012"` (manual).
  - `track2: str | None` — opcional (solo si es banda).

> 💡 **Por qué:** la app mobile le va a mandar estos datos (en la Rama 4), y la
> API tiene que poder recibirlos y pasarlos al gateway.

### 7. `application/payments/create_transaction.py`, `ports.py`, `infrastructure/payments/http_gateway.py`, `presentation/controllers/transactions_controller.py`

- **Qué son:** la cadena que lleva los datos desde el request de la API hasta la
  llamada al gateway.
- **Qué cambió:** todos propagan `entry_mode`/`track2` de punta a punta.

> 💡 **Por qué:** si la API recibe `entry_mode`/`track2` pero no los pasa al
> gateway, el cambio no sirve de nada. Hay que llevarlos hasta el final.

---

## 🔐 Consideraciones de seguridad (importante)

- **CVV:** la banda magnética **NO contiene el CVV**. Por eso `track2` es
  opcional y el CVV se sigue pidiendo por separado (o se pide manualmente en
  pantalla). No se asume que la banda trae CVV.
- **Persistencia:** la API **solo guarda `card_last4`** (los últimos 4 dígitos).
  Nunca guarda el PAN completo ni el track2 completo.
- **Track2 (DE35):** para banda magnética, el gateway usa **DE35** en vez de
  DE2 (PAN) + DE14 (vencimiento).

---

## ✅ Cómo se verificó que funcionó

Se corrió el quality gate obligatorio en **ambos** paquetes (gateway y API):

```bash
# En payment-gateway/
make check
# Resultado: lint ✓ · typecheck ✓ · 54 tests ✓ · cobertura ≥ 90% ✓

# En api/
make check
# Resultado: lint ✓ · typecheck ✓ · 115 tests ✓ · cobertura ≥ 90% ✓
```

> El hecho de que pasen los tests y la cobertura confirma que el cambio no rompió
> nada y que los casos nuevos (manual y banda) están cubiertos.

---

## 🚧 Qué NO se hizo todavía (y qué viene)

La Rama 3 **solo arregló el backend** (gateway + API). Todavía falta que la app
mobile **mande** el `entry_mode`/`track2` cuando registra una venta. El plan
completo es de **4 ramas**:

| Rama | Qué hace | Estado |
|------|----------|:------:|
| **Rama 1** | Portar el bridge PSDK | ✅ Hecha |
| **Rama 2** | Conectar `WaitingForCardScreen` al PSDK + navegación "Tarjeta" | ⏳ Pendiente |
| **Rama 3** | Gateway con `entry_mode` dinámico + API con `entry_mode`/`track2` | ✅ Hecha |
| **Rama 4** | Mobile `registerSale` con `entry_mode` + actualizar `docs/gaps.md` | ⏳ Pendiente |

---

## 📖 Glosario

| Término | Qué significa (en simple) |
|---------|---------------------------|
| **ISO 8583** | El "idioma" estándar que usan los procesadores de tarjetas para cobrar |
| **DE22** | Campo del mensaje ISO que dice **cómo se leyó la tarjeta** (`012` manual, `022` banda) |
| **DE2** | Campo del mensaje ISO con el **número de tarjeta** (PAN) |
| **DE14** | Campo del mensaje ISO con el **vencimiento** de la tarjeta |
| **DE35** | Campo del mensaje ISO con el **track2** (los datos de la banda magnética) |
| **entry_mode** | Cómo se leyó la tarjeta: `"012"` (manual) o `"022"` (banda) |
| **track2** | Los datos que se leen de la banda magnética de la tarjeta |
| **PAN** | El número completo de la tarjeta |
| **card_last4** | Solo los últimos 4 dígitos de la tarjeta (lo único que se guarda) |
| **Gateway** | El adaptador que convierte HTTP → ISO 8583 |
| **make check** | El quality gate: lint + typecheck + tests + cobertura ≥ 90% |

---

## 🔗 Referencias

- Gateway — comando: `payment-gateway/domain/authorization.py`
- Gateway — request: `payment-gateway/presentation/schemas/authorize.py`
- Gateway — armado del mensaje ISO: `payment-gateway/infrastructure/iso/message_builder.py`
- Gateway — caso de uso: `payment-gateway/application/payments/authorize_payment.py`
- Gateway — controller: `payment-gateway/presentation/controllers/authorize_controller.py`
- API — request: `api/presentation/schemas/transactions.py`
- API — caso de uso: `api/application/payments/create_transaction.py`
- API — puerto: `api/application/payments/ports.py`
- API — cliente del gateway: `api/infrastructure/payments/http_gateway.py`
- API — controller: `api/presentation/controllers/transactions_controller.py`
- Test cases gateway: [`docs/test_cases_gateway.md`](test_cases_gateway.md)
- Test cases API: [`docs/test_cases_api.md`](test_cases_api.md)
- Registro de avance: [`docs/gaps.md`](gaps.md) (gaps G-P0-06 y G-P1-06 → `partial`)
