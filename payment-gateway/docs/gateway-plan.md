# Plan: payment gateway (HTTP → ISO)

## Rol

Adaptador sin contexto de clientes: recibe `POST /v1/authorize`, arma ISO8583 (dialecto KIG), habla con `authkig` por TCP, y devuelve `APPROVED` / `DECLINED` / `FAILED`.

## Contrato

`POST /v1/authorize`

```json
{
  "currency": "ARS",
  "amount_minor": 150050,
  "card_number": "4111111111111111",
  "terminal_id": "05000001",
  "stan": "123456",
  "expiration_date": "2912"
}
```

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
- Procesador caído → 502

## Transportes

| `ISO_TRANSPORT` | Comportamiento |
|-----------------|----------------|
| `mock` (default) | Sin red. Decline si PAN = `4000000000000002` |
| `tcp` | Pack ISO + TCP a `ISO_HOST:ISO_PORT` |

## Capas

`presentation` → `application` (`AuthorizePayment` + `IsoProcessor`) → `domain` ← `infrastructure/iso`

El mensaje 0200 incluye **DE41** (terminal); el procesador resuelve comercio desde `terminales` (no se envía DE42).

## Fuera de alcance (por ahora)

- Persistencia / idempotencia (vive en la API)
- Void / refund / settlement
- Tokenización PCI
