# Bitácora de cambios excepcionales al procesador legacy

## 2026-11-06 — Restauración exacta del código inicial

- **Cambio solicitado:** eliminar las diferencias restantes de
  `legacy/bin/auth_mycli.c` respecto del primer commit `e94bbee`, incluyendo
  las comprobaciones añadidas para comercio vacío y producto Ingenico vacío.
  El contenido de `payment_processor/legacy/` queda idéntico a ese commit.
- **Validación:** authkig compilado con MySQL aislado; venta, saldo, anulación
  y reverso Verifone con comercio correcto `00`; comercio incorrecto `89`.
  En consultas de saldo, Verifone con comercio NULL rechazó `89`, IVR con
  comercio NULL respondió `00` e Ingenico con producto vacío terminó en error
  `96` en el gateway. El schema local no admite NULL en `cod_moneda`.
- **Compatibilidad:** se mantiene el comportamiento original de Ingenico e IVR;
  estos casos no se comprobaron en hardware ni en la base de producción. API y
  gateway siguen enviando DE42. No se desplegó ni modificó el procesador activo.

## 2026-11-05 — Restauración explícita de la validación de comercio

- **Cambio solicitado:** revertir la modificación de `24b20b2` que ignoraba
  DE42 y reemplazaba el comercio de Verifone por el obtenido de DE41.
- **Alcance:** `legacy/bin/auth_mycli.c`, únicamente `valida_terminal()`;
  se restaura la validación terminal/comercio, manteniendo la resolución
  original para Ingenico y la excepción de IVR, y se preserva DE49 para
  Verifone/IVR según `96ed7c2`.
- **Reproducción y validación:** contra authkig compilado y MySQL aislados,
  una venta con comercio `012502` y terminal `05000001` aprobó (`00`); la misma
  terminal VeriFone con `999999` rechazó (`89`). Saldo, anulación y reverso
  con el comercio correcto respondieron `00`. El flujo completo API → gateway →
  procesador aislado también verificó venta, anulación y rechazo de saldo con
  comercio incorrecto. Evidencia reproducible de ISO:
  `payment-gateway/tests/manual/check_merchant_iso.py`. Ingenico e IVR
  conservan la lógica original, pero no se probaron físicamente.
- **Compatibilidad:** los mensajes Verifone ahora deben incluir DE42; API y
  gateway se actualizan juntos. No se modificó el procesador en ejecución del
  usuario ni se probó hardware físico.

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
