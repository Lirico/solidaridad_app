# Bitácora de cambios excepcionales al procesador legacy

`payment_processor/legacy/` no se modifica para adaptar contratos de la app,
API o gateway. Solo se aceptan correcciones de bugs explícitos, reproducibles y
acotados del procesador.

Cada entrada debe incluir: fecha, bug/reproducción, archivos afectados,
justificación de por qué la corrección pertenece al procesador, validación y
compatibilidad evaluada.

## 2026-07-16 — Resolver comercio por terminal vigente

- **Bug reproducible:** una terminal vigente era rechazada cuando DE42 no
  coincidía con `terminales.cod_comercio`, aunque DE41 identificara de forma
  unívoca la terminal. La validación duplicaba una relación que ya posee la
  tabla `terminales`.
- **Corrección:** commit `24b20b2` en `legacy/bin/auth_mycli.c`.
  `valida_terminal()` resuelve `merchid_42` desde
  DE41 (`terminales.codigo_terminales`), requiere una terminal vigente con
  `cod_comercio` configurado y elimina la validación redundante DE41+DE42.
- **Ajuste de compatibilidad:** commit `96ed7c2` del mismo día preservó DE49
  enviado por VeriFone/IVR; solo Ingenico lo obtiene desde la configuración de
  la terminal. El comercio continúa resolviéndose exclusivamente por DE41.
- **Validación y alcance:** el comportamiento quedó documentado en
  `payment_processor/README.md` y forma parte del baseline restaurado de
  `auth_mycli.c`. No adapta el procesador al contrato de captura: corrige la
  resolución interna de una terminal válida.
