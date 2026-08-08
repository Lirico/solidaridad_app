-- ============================================================
-- Recarga de saldo para demos / pruebas locales.
--
-- No es parte de la inicialización de MySQL. Este script se
-- aplica sobre una DB levantada cuando el saldo de demo se agota.
--
-- Uso (desde payment_processor/):
--   make recarga
-- ============================================================

-- Extender vigencia de la tarjeta de demo (DE14 = 1228).
UPDATE sgas_usuario
   SET vigencia_hasta = '2028-12-30'
 WHERE nro_tarjeta = '6063007014007401';

-- Recarga alta para 6063007014007401 (tarjeta de demo canónica).
-- saldo = 100000 → ~1000 ventas de $100. importe < 0 → recarga.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '993', -1, NOW());
