# Demo — Transacción aprobada (código 00)

Guía para reproducir una venta **aprobada (00)** en el stack local:

```
App Flutter → API → Payment Gateway → Autorizador (authkig) → MySQL
```

## 1. Datos de demo

| Campo | Valor |
|-------|-------|
| Tarjeta | `6063007014007403` |
| CVV | `878` |
| Vencimiento (DE14) | `1228` |
| Producto | `993` |
| `installation_id` / terminal | `05000001` |
| Comercio del terminal | `012502` (GOBIERNO) |

Usar siempre `6063007014007403`. No usar `4111111111111111`: cuelga el
autorizador en `calcula_saldo_vivo()` (bug del C).


## 2. Levantar el stack

```bash
make -C payment_processor reset   # schema + seed + 03_fix_demo (volumen limpio)
# o: make -C payment_processor up  # si el volumen ya está inicializado
```

`utils/demo/03_fix_demo.sql` corre **solo** en init de MySQL (compose →
`/docker-entrypoint-initdb.d/`), junto con `01_schema.sql` y `02_seed.sql.gz`.
No hace falta ejecutarlo a mano.

Gateway y API:

```bash
cd payment-gateway && make run   # ISO_TRANSPORT=tcp, ISO_HOST=127.0.0.1, ISO_PORT=4452
cd api && make run
```

Si el saldo de demo se agota (sin resetear la DB):

```bash
make -C payment_processor recarga
```

## 3. Probar

### Gateway (`POST /v1/authorize`)

```bash
curl -X POST http://127.0.0.1:8001/v1/authorize \
  -H "Content-Type: application/json" \
  -d '{
    "card_number": "6063007014007403",
    "expiration_date": "1228",
    "amount_minor": 10000,
    "product_code": "993",
    "terminal_id": "05000001",
    "stan": "000001",
    "ticket_number": "0001"
  }'

```

Esperado: `"status":"APPROVED"`, `"response_code":"00"`.

### API (`POST /v1/transactions`)

```bash
curl -X POST http://127.0.0.1:8000/v1/transactions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -H "Idempotency-Key: demo-$(date +%s)" \
  -d '{
    "product": "993",
    "amount": "100.00",
    "card_number": "6063007014007403",
    "cvv": "878",
    "expiration_date": "1228"
  }'

```

### App Flutter

```bash
flutter run --dart-define=API_BASE_URL=http://<IP-PC>:8000/v1
```

Sin `--dart-define=INSTALLATION_ID=...`, el default de la app es `05000001`.

## 4. Troubleshooting

| Código | Causa | Fix |
|--------|-------|-----|
| **89** | Terminal desconocida | Usar `05000001` |
| **17** | Venta demasiado reciente | Cubierto por `03_fix_demo` (`venta_min_horas_ultima_venta=0`); si no, `make reset` |
| **51** | Fondos insuficientes | `make -C payment_processor recarga` |
| **96** | DE62 / comprobante | Ya cubierto en gateway con `ticket_number` |

## Referencias

- `payment_processor/utils/demo/03_fix_demo.sql` — init de demo montado por compose
- `payment_processor/utils/demo/recarga.sql` — recarga vía `make recarga`
- `docs/gaps.md` — G-P0-08, G-P0-18
