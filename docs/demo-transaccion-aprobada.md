# Demo — Transacción aprobada (código 00)

Guía práctica para reproducir una **venta aprobada (código 00)** de punta a
punta en el stack local de Solidaridad:

```
App Flutter (mobile) → API (FastAPI) → Payment Gateway (HTTP→ISO8583) → Autorizador legacy (authkig, C) → MySQL
```

Última verificación: **2026-06-08** (transacción aprobada con expiración `1228`).

---

## 1. Datos de la tarjeta de demo

La tarjeta que aprueba en vivo es la de **Lillo** (Luhn-válida):

| Campo | Valor |
|-------|-------|
| Número | `6063 0070 1400 7401` |
| CVV | `878` |
| Vencimiento (DE14) | `1228` (diciembre 2028) |
| Saldo | **100000** en producto `993` |
| Titular | LILLO ESPINOZA SILVIA DEL |

> **Importante:** la tarjeta original de Lillo (`6063007014007403`) no está
> dada de alta con saldo en el autorizador y se rechaza. Usar siempre
> `6063007014007401`.
>
> Nota: la API y el gateway **no** aplican validación Luhn (las tarjetas del
> programa usan dígito verificador MOD-TDF); solo validan que el PAN sea
> numérico y tenga entre 13 y 19 dígitos. El rechazo de `6063007014007403`
> no se debe a Luhn.


### Cómo recargar saldo / extender vigencia

El script `payment_processor/docker/mysql/recarga_demo.sql` deja la tarjeta con
saldo **100000** y vigencia **2028-12-30**. Aplicarlo contra la base del
autorizador con el target de make (requiere el stack levantado):

```bash
make -C payment_processor recarga
```

Equivalente manual:

```bash
docker exec -i solidaridad-processor-mysql mysql -ukigadmin2 -plocaldev kigsolidario2 < payment_processor/docker/mysql/recarga_demo.sql
```


---

## 2. Datos del terminal / comercio

| Campo | Valor |
|-------|-------|
| `installation_id` / terminal | `05000001` |
| `cod_comercio` | `012502` (GOBIERNO, vigente) |
| `venta_min_horas_ultima_venta` | `0` (permite repetir ventas seguidas) |

> El terminal `05000001` debe existir en la tabla `terminales` del autorizador
> con `cod_comercio='012502'`. Si se usa otro terminal, el autorizador devuelve
> código **89** (terminal desconocida).

---

## 3. Levantar el stack

### 3.1 MySQL + autorizador (Docker)

```bash
make -C payment_processor up
```

Esto levanta `solidaridad-processor-mysql` y `solidaridad-processor-auth`.

### 3.2 Payment Gateway (local)

```bash
cd payment-gateway
# asegurar .env con:
#   ISO_TRANSPORT=tcp
#   ISO_HOST=127.0.0.1
#   ISO_PORT=4452
make run
```

### 3.3 API (local)

```bash
cd api
make run
```

---

## 4. Probar la transacción

### 4.1 Directo por el gateway (`POST /v1/authorize`)

```bash
curl -X POST http://127.0.0.1:8001/v1/authorize \
  -H "Content-Type: application/json" \
  -d '{
    "card_number": "6063007014007401",
    "expiration_date": "1228",
    "amount_minor": 10000,
    "product_code": "993",
    "terminal_id": "05000001",
    "stan": "000001"
  }'
```

**Respuesta esperada:**

```json
{"status":"APPROVED","response_code":"00","user_message":"Aprobada","auth_id":"930886","retrieval_reference":"000000289383"}
```

### 4.2 Vía API (`POST /v1/transactions`) — el flujo que usa la app

```bash
curl -X POST http://127.0.0.1:8000/v1/transactions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{
    "product": "993",
    "amount": "100.00",
    "card_number": "6063007014007401",
    "cvv": "878",
    "expiration_date": "1228"
  }'
```

**Respuesta esperada:** `APPROVED` / `Pago aprobado`.

### 4.3 Desde la app Flutter (celular)

Compilar la app apuntando a la IP de la PC:

```bash
flutter run --dart-define=API_BASE_URL=http://<IP-PC>:8000/v1
```

En el formulario de venta ingresar:
- Producto: **993** (o el que corresponda del catálogo)
- Importe: **100.00**
- Tarjeta: `6063 0070 1400 7401`
- CVV: `878`
- Vencimiento: `12/28`

---

## 5. Verificar en MySQL

Confirmar que el cupón quedó registrado como aprobado:

```bash
docker exec solidaridad-processor-mysql mysql -ukigadmin2 -plocaldev kigsolidario2 \
  -e "SELECT nro_tarjeta, vencimiento, importe, codigo_autorizacion, numero_comprobante, ts_operacion \
      FROM sgas_cup WHERE nro_tarjeta='6063007014007401' ORDER BY ts_operacion DESC LIMIT 3;"
```

**Resultado esperado:** fila con `vencimiento=1228`, `importe=100.00`,
`codigo_autorizacion` no vacío.

---

## 6. Troubleshooting rápido

| Código | Causa | Fix |
|--------|-------|-----|
| **96** | Gateway no envía DE62 (`numero_comprobante`) → error SQL en `valida_cupon_dup()` | Ver G-P0-19 en `docs/gaps.md`. El gateway debe empaquetar `field_62`. |
| **17** | `validaTiempoUltimaVenta()` rechaza ventas repetidas de la misma tarjeta/producto | Setear `venta_min_horas_ultima_venta = 0` en `soli_config`. |
| **89** | Terminal desconocida (`valida_terminal() NUM_ROWS: 0`) | Usar `installation_id=05000001` (existe en `terminales`). |
| **51** | Fondos insuficientes (`saldo_anterior - consumo_vivo < importe`) | Recargar saldo con `make -C payment_processor recarga`. |
| **Rechazo antes de autorizador** | Tarjeta no dada de alta / sin saldo en el autorizador | Usar `6063007014007401` (dada de alta con saldo). |


---

## 7. Nota sobre la tarjeta `4111111111111111`

La tarjeta `4111111111111111` (VISA de prueba) tiene saldo **100000** en
producto `993`, pero el autorizador **se cuelga** en `calcula_saldo_vivo()`
cuando se usa (bug del código C) y Docker reinicia el contenedor. **No usarla
para el demo.** Usar siempre `6063007014007401`.

---

## Referencias

- `docs/gaps.md` — inventario de brechas y fixes (G-P0-18, G-P0-19).
- `payment_processor/docker/mysql/recarga_demo.sql` — recarga + vigencia.
- `payment_processor/docker/mysql/03_fix_demo.sql` — fixes de terminal/comercio
  (se ejecuta automáticamente en cada corrida en limpio vía docker-compose).


