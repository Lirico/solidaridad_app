# AGENTS.md

Guía para agentes y contribuidores que modifican este monorepo.

## Documentación de alcance y gaps

- Alcance funcional/producto: [`docs/alcance.md`](docs/alcance.md)
- Inventario de brechas: [`docs/gaps.md`](docs/gaps.md)

**Obligatorio:** cada cambio que implemente, complete o invalide un ítem del
alcance debe **actualizar `docs/gaps.md` en el mismo trabajo** (estado,
evidencia, nuevos gaps descubiertos y fecha de última revisión). No dejar el
documento de gaps desfasado respecto del código.

Si el cambio modifica decisiones de producto (por ejemplo modo de captura,
terminal, contratos), actualizar también `docs/alcance.md`.

## Componentes

| Path | Rol |
|------|-----|
| `mobile/` | App Flutter (comercio / terminal) |
| `poc_verifone/` | POC Flutter semilla para PSDK Verifone (V660P) |
| `api/` | API pública (FastAPI + Postgres) |
| `payment-gateway/` | Adaptador HTTP → ISO8583 |
| `payment_processor/` | Autorizador legacy (C + MySQL) |

Hay `AGENTS.md` adicionales en `api/` y `payment-gateway/` con convenciones
locales de esos componentes; respetarlos al trabajar ahí.

## Procesador legacy

`payment_processor/legacy/` se considera una dependencia existente e
inmutable: **no modificarla salvo para corregir un bug explícito, reproducible
y acotado del procesador**. Las adaptaciones de contrato, captura, HTTP e ISO
corresponden a `mobile/`, `api/` o `payment-gateway/`, no al código C legacy.

Cada corrección excepcional en el procesador debe agregarse a
[`payment_processor/LEGACY_CHANGELOG.md`](payment_processor/LEGACY_CHANGELOG.md)
en el mismo cambio, indicando fecha, bug reproducible, alcance de los archivos,
evidencia de validación y compatibilidad evaluada.
