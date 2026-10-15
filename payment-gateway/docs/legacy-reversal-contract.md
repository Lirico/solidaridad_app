# Contrato observado del reverso legacy (`0400`)

> RA-00 · Evidencia obtenida el 2026-10-12 contra el stack Docker local y el
> binario legacy sin modificaciones.

## Conclusión operativa

El procesador devuelve `0410/DE39=00` tanto cuando encuentra la venta original
como cuando no existe. Esto no produce un saldo negativo: el cálculo de consumo
solo incluye filas `0200`, y reportes y cierre excluyen `0400`.

El contrato operativo acordado establece que:

- el `0400` solo se genera para un `0200` previamente enviado;
- `0410/00` se clasifica como `REVERSED_CONFIRMED`;
- un reverso de una original inexistente es económicamente neutro;
- una respuesta inválida o un fallo ambiguo de transporte permanece
  `INDETERMINATE`.

## Mensaje caracterizado

La trama ejercitada reutiliza el layout histórico de venta, cambia el MTI a
`0400` y conserva los identificadores originales. El procesador responde con
MTI `0410`.

| DE | Contenido | Uso observado en el legacy |
|---:|---|---|
| 2 | PAN sintético | Parte de la coincidencia estricta |
| 3 | Código de proceso `000000` | Parte de la coincidencia estricta |
| 4 | Importe, 12 dígitos | Parte de la coincidencia estricta |
| 11 | STAN original | Se compara con `id_operacion` |
| 12 | Hora local | Se persiste en la fila de reverso |
| 13 | Fecha local `MMDD` | Se persiste en la fila de reverso |
| 14 | Vencimiento `YYMM` | Parte de la coincidencia estricta |
| 22 | Entry mode `0012` | Obligatorio; si falta responde `19` |
| 24 | NII | Se refleja en la respuesta |
| 25 | Condición POS | Presente en el vector histórico; no participa del match |
| 41 | Terminal, 8 caracteres | Parte del match y resuelve el comercio |
| 49 | Producto | Parte de la coincidencia estricta |
| 62 | Ticket original | Parte de la coincidencia estricta |

El comercio no necesita DE42 en el vector Verifone/IVR: se obtiene desde DE41.
El lote se obtiene de DE63; al estar ausente en el contrato vigente toma valor
`0`. Ambos valores participan en la búsqueda de la venta original.

La búsqueda completa de `valida_cupon_reverso()` compara comercio,
vencimiento, importe, STAN, terminal, ticket, producto, PAN, lote y código de
proceso. Sin embargo, que la búsqueda no encuentre filas no es un error:
`reverso()` inserta igualmente una fila `0400` y devuelve éxito.

## Matriz reproducida

| Escenario | DE39 | Estado de DB después | Clasificación operativa |
|---|---:|---|---|
| Venta existente y luego reverso | `00` | 2 filas `0400`: original mutada + registro de reverso | `REVERSED_CONFIRMED` |
| Venta inexistente | `00` | 1 fila `0400` sin original, sin impacto en saldo | `REVERSED_CONFIRMED` |
| Mismo reverso repetido | `00` | pasa de 2 a 3 filas `0400`, sin impacto adicional | `REVERSED_CONFIRMED` |
| Reverso antes de registrar la venta | `00` | 1 fila `0400` | fuera del flujo admitido |
| Venta después del reverso anticipado | `00` | 1 fila `0400` + 1 fila `0200` activa | fuera del flujo admitido |

La repetición es idempotente respecto del código HTTP/ISO aparente, pero no en
persistencia: cada repetición agrega otra fila. Tampoco existe un tombstone que
impida una venta tardía.

## Evidencia ejecutable

- `tests/fixtures/legacy_reversal_contract.json` contiene las tramas binarias
  sintéticas y los conteos observados; no contiene datos de producción.
- `tests/test_legacy_reversal_contract.py` verifica los MTI, bitmaps, códigos y
  la clasificación operativa aceptada.
- `tests/manual/record_legacy_reversal_contract.py` reproduce los cuatro casos
  contra `authkig` + MySQL locales. Solo limpia los STAN/tickets reservados
  `890001`–`890003` de la tarjeta sintética del seed.

Reproducción manual:

```bash
make -C payment_processor up
make -C payment_processor recarga
cd payment-gateway
PYTHONPATH=. uv run python tests/manual/record_legacy_reversal_contract.py
make check
```

## Decisión de integración

No se modifica el C legacy. El gateway interpreta `0410/00` como reverso
confirmado y no reintenta internamente. La orquestación superior conserva
`INDETERMINATE` cuando no obtiene una respuesta ISO válida.
