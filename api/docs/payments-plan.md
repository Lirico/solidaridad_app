# Plan: transacciones (POST /v1/transactions)

Contrato vivo de compra/autorización y anulación. La API es la capa de negocio
(auth, ledger, idempotencia, mensajes); el gateway es adaptador ISO; el
procesador autoriza.

## Decisiones

| Tema | Decisión |
|------|----------|
| Ruta venta | `POST /v1/transactions` (Bearer JWT) |
| Ruta anulación | `POST /v1/transactions/{transaction_number}/void` |
| Producto | Enum legible en el client; API mapea a `993`–`997` |
| Identidad | PK técnico `BIGINT IDENTITY`; clave pública `transaction_number` (`OP-YYMMDD-NNNNNNNN`) |
| Ticket ISO (DE62) | Sufijo numérico de `transaction_number` (`NNNNNNNN`), persistido como `processor_ticket` |
| Idempotencia | Header requerido `Idempotency-Key` (scope user en venta; scope void en anulación) |
| PCI | No persistir PAN ni CVV; solo `card_last4`; anulación exige reingreso de tarjeta |
| Gateway | `POST /v1/authorize` / `POST /v1/void` |

## Productos

| API | Procesador (DE49) | Seed |
|-----|-------------------|------|
| `GARRAFA_10` | `993` | GARRAFA10 |
| `GARRAFA_15` | `994` | GARRAFA15 |
| `GARRAFA_30` | `995` | GARRAFA30 |
| `TUBO_45` | `996` | TUBO45 |
| `GRANEL` | `997` | GRANEL |

## Request venta

```json
{
  "product": "GARRAFA_10",
  "amount": "1.50",
  "card_number": "6063007014001602",
  "expiration_date": "2912",
  "cvv": "123"
}
```

Headers:

- `Authorization: Bearer <jwt>` (requerido)
- `Idempotency-Key: <string>` (requerido)

Notas:

- `amount` es cantidad decimal (string); se convierte a unidades menores (exponente 2).
- `cvv` se valida pero no se reenvía al gateway en v1.
- El `installation_id` del JWT identifica la terminal configurada; la API lo
  resuelve en `installations` y envía ese valor como `terminal_id` al procesador.

## Request anulación

```json
{
  "card_number": "6063007014001602",
  "expiration_date": "2912",
  "cvv": "123"
}
```

`POST /v1/transactions/OP-260716-00000042/void` con `Idempotency-Key`.

Reglas: solo `APPROVED`; `card_last4` debe coincidir; ya `VOIDED` → 200
idempotente.

## Response

```json
{
  "transaction_number": "OP-260716-00000042",
  "status": "APPROVED",
  "user_message": "Pago aprobado",
  "created_at": "2026-07-16T19:00:00Z"
}
```

### Estados

| Status | Significado |
|--------|-------------|
| `APPROVED` | Autorización confirmada |
| `VOIDED` | Anulación confirmada |
| `DECLINED` | Rechazo confirmado |
| `FAILED` | Fallo antes de llegar al procesador (sin impacto) |
| `UNKNOWN` | Resultado ambiguo (posible impacto); no reintentar con key nueva |
| `PENDING` | En curso; solo en replay de idempotencia → reintentar misma key |

### Idempotencia (venta)

| Estado existente | HTTP | Acción |
|------------------|------|--------|
| No existe | 201 | Crear, autorizar |
| `PENDING` | 202 | Devolver misma tx; cliente reintenta luego |
| Terminal | 201 | Devolver resultado; sin reautorizar |
| Misma key, body distinto | 409 | Conflicto |

## Errores

Shape: `{ "message": "..." }`

| Caso | HTTP |
|------|------|
| Validación / producto / monto / PAN / sin Idempotency-Key | 400 |
| Auth | 401 |
| Transacción no encontrada (void) | 404 |
| Body incompatible con key | 409 |

## E2E local

```bash
make dev   # API :8000 + gateway ISO_TRANSPORT=tcp + processor
```

1. Login demo → Bearer
2. `POST /v1/transactions` con `product=GARRAFA_10`, PAN del seed, `Idempotency-Key`
3. Esperar `APPROVED`/`DECLINED` y fila en Postgres
4. Repetir misma key → misma respuesta sin segunda autorización
5. `POST /v1/transactions/{tn}/void` con la misma tarjeta e `Idempotency-Key` distinta → `VOIDED`
