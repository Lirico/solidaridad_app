-- ============================================================
-- Recarga de saldo para demos / pruebas locales.
--
-- No es parte de la inicialización de MySQL. Este script se
-- aplica sobre una DB levantada cuando el saldo de demo se agota.
--
-- Uso (desde payment_processor/):
--   make recarga
-- ============================================================

-- Extender vigencia de las tarjetas de demo (DE14 = 1228).
UPDATE sgas_usuario
   SET vigencia_hasta = '2028-12-30'
 WHERE nro_tarjeta IN ('6063007014007401', '6063007014007403');

-- Recarga alta para las tarjetas de demo.
-- saldo = 100000 → ~1000 ventas de $100. importe < 0 → recarga.
-- El saldo es POR PRODUCTO (sgas_usuario_cta.prod_id): sin fila para un
-- producto, valida_usuario_producto() rechaza con código 06. Por eso se
-- recargan los 5 productos (993–997) para poder probar cualquier garrafa.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '993', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '994', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '995', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '996', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '997', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -100000.00, 100000.00, '993', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -100000.00, 100000.00, '994', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -100000.00, 100000.00, '995', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -100000.00, 100000.00, '996', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -100000.00, 100000.00, '997', -1, NOW());


