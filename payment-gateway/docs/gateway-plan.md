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

`ticket_number` se envía en DE62 (`numero_comprobante`). Es el sufijo numérico
de `transaction_number` de la API (no el STAN).

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

`ISO_TRANSPORT` debe elegirse explícitamente. Si falta, está vacío o contiene
un valor desconocido, el gateway no arranca. `mock` queda restringido al
ambiente `local`; los demás ambientes deben usar `tcp`.

| `ISO_TRANSPORT` | Comportamiento |
|-----------------|----------------|
| `mock` | Sin red. Decline si PAN = `4000000000000002`; solo con `APP_ENV=local` |
| `tcp` | Pack ISO + TCP a `ISO_HOST:ISO_PORT` |

## Capas

`presentation` → `application` (`AuthorizePayment` / `VoidPayment` + `IsoProcessor`) → `domain` ← `infrastructure/iso`

Los mensajes incluyen **DE41** (terminal) y **DE42** (comercio, ASCII de 15
caracteres con espacios a la derecha). La API proporciona el comercio; para
Verifone, el procesador valida la relación entre terminal y comercio.

## Fuera de alcance (por ahora)

- Persistencia / idempotencia (vive en la API)
- Refund / settlement. El reverso MTI `0400` ya existe como primitiva ISO
  interna; su endpoint HTTP y la orquestación automática siguen pendientes.
- Tokenización PCI
