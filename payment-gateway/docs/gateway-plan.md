# Plan: payment gateway (HTTP → ISO)

## Rol

Adaptador sin contexto de clientes: recibe authorize/void HTTP, arma ISO8583
(dialecto KIG), habla con `authkig` por TCP, y devuelve `APPROVED` / `DECLINED` /
`FAILED`.

## Contrato

### `POST /v1/authorize` (venta)

```json
{
  "product_code": "993",
  "amount_minor": 150050,
  "card_number": "4111111111111111",
  "terminal_id": "05000001",
  "stan": "123456",
  "ticket_number": "00000042",
  "expiration_date": "2912"
}
```

`ticket_number` se envía en DE62 (`numero_comprobante`). Desde 2026-08-24 la API
lo arma con el **STAN** de la transacción (único por reintento) para evitar que
el autorizador lo considere cupón duplicado (código 17 `CUP_DUP`). Histórico:
era el sufijo numérico de `transaction_number` (no el STAN).

El **CVV** (campo `cvv`, opcional) se envía en **DE55** cuando el modo de entrada
es manual (012 / `entry_mode` "012"). En banda (022) no viaja, porque esa
tarjeta no lo trae y el autorizador no debe validarlo. El autorizador compara
DE55 contra `sgas_usuario.cvv_actual` y rechaza con `CVV_ERROR` si no coincide.
Desde 2026-08-24.

### `POST /v1/void` (anulación)

```json
{
  "product_code": "993",
  "amount_minor": 150050,
  "card_number": "4111111111111111",
  "terminal_id": "05000001",
  "stan": "654321",
  "original_ticket": "00000042",
  "void_ticket": "654321",
  "expiration_date": "2912"
}
```

ISO: MTI `0200`, DE3 `020000`, DE37 = ticket original (ruta Verifone), DE60 =
importe (el autorizador lee anulación desde DE60), DE62 = ticket de la fila de
anulación.

`product_code` es un enum cerrado (`993` | `994` | `995` | `996` | `997`) y se usa
directamente para construir DE49 (no hay mapeo ISO 4217).

`expiration_date` (`YYMM`) es opcional.

Response 200:

```json
{
  "status": "APPROVED",
  "response_code": "00",
  "user_message": "Aprobada",
  "auth_id": "MOCK01",
  "retrieval_reference": "000000123456"
}
```

- Errores de validación → 400 `{ "message": "..." }`
- No se pudo conectar con el procesador (el ISO nunca salió) → 503
- Falla después de enviar el ISO (timeout de lectura, conexión cortada) → 502

La distinción 503 / 502 es parte del contrato: la API traduce 503 a `FAILED`
(sin impacto posible) y 502 a `UNKNOWN` (resultado ambiguo).

## Transportes

| `ISO_TRANSPORT` | Comportamiento |
|-----------------|----------------|
| `mock` (default) | Sin red. Decline si PAN = `4000000000000002` |
| `tcp` | Pack ISO + TCP a `ISO_HOST:ISO_PORT` |

## Capas

`presentation` → `application` (`AuthorizePayment` / `VoidPayment` + `IsoProcessor`) → `domain` ← `infrastructure/iso`

El mensaje 0200 incluye **DE41** (terminal); el procesador resuelve comercio desde `terminales` (no se envía DE42).

## Fuera de alcance (por ahora)

- Persistencia / idempotencia (vive en la API)
- Refund / settlement / reverso MTI `0400`
- Tokenización PCI
