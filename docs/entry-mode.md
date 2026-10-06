# Captura de tarjeta y contrato ISO legacy

**Decisión vigente: 2026-10-05.**

La lectura de banda y la carga manual comparten el mismo contrato funcional:
la app entrega a la API el PAN y, cuando está disponible, el vencimiento en
formato `YYMM`. La lectura por banda solamente evita que el operador tenga que
tipear esos datos.

No forman parte del contrato HTTP ni del mensaje ISO:

- `entry_mode`;
- Track 2 / DE35;
- CVV (se acepta opcionalmente por compatibilidad con clientes anteriores, pero
  no se reenvía al gateway ni al procesador).

El gateway preserva el layout que esperaba el autorizador legacy:

| Dato | Campo ISO |
| --- | --- |
| PAN | DE2 |
| Vencimiento `YYMM` | DE14 |
| Modo de captura histórico | DE22 = `0012` |
| Track 2 | No se envía (sin DE35) |

La pista leída queda limitada al dispositivo para extraer PAN y vencimiento;
no se persiste, no se loguea y no se propaga fuera de Flutter.

Esta es una decisión de compatibilidad para este autorizador legacy, no un
modelo genérico de adquirencia EMV/contactless. Si se requiere una integración
EMV real, debe diseñarse como un contrato y una integración nuevos, sin adaptar
el procesador existente al formato del cliente.

El código de `payment_processor/legacy/` no se modifica por necesidades de
captura o de contrato de las capas superiores. Cualquier corrección excepcional
por un bug explícito y reproducible debe quedar registrada en
[`payment_processor/LEGACY_CHANGELOG.md`](../payment_processor/LEGACY_CHANGELOG.md).
