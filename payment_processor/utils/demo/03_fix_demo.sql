-- ============================================================
-- 03_fix_demo.sql — datos de demo aplicados en cada DB limpia.
--
-- Parte de la inicialización MySQL (misma nomenclatura que
-- 01_schema.sql / 02_seed.sql.gz). Montado en
-- /docker-entrypoint-initdb.d/ desde docker-compose.yml.
-- No correr a mano: usar `make reset` (o el primer `make up`
-- con volumen vacío).
--
-- Propósito: terminal 05000001 + tarjetas de prueba con saldo
-- para poder autorizar ventas aprobadas en el stack local.
-- ============================================================

-- 1) Comercio del terminal 05000001.
--    En el seed viene cod_comercio='000000' (no existe en
--    sgas_comercio) → valida_comercio() rechaza. GOBIERNO 012502
--    existe y está vigente (situacion='V').
UPDATE terminales
   SET cod_comercio = '012502'
 WHERE codigo_terminales = '05000001';

-- 2) Saldo/recarga para 6063007014007403 (Lillo original) en TODOS los productos.
--    saldo > 0 → calcula_saldo_anterior(); importe < 0 → obtieneUltimaRecarga().
--    El saldo es POR PRODUCTO (sgas_usuario_cta.prod_id): sin fila para un
--    producto, valida_usuario_producto() rechaza con código 06. Por eso se
--    cargan los 5 productos (993–997) para poder probar cualquier garrafa.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '993', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '994', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '995', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '996', -1, NOW()),
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '997', -1, NOW());

-- 3) Permitir ventas seguidas en demo.
--    validaTiempoUltimaVenta() rechaza (código 17) si hubo venta reciente
--    dentro de venta_min_horas_ultima_venta (default 72h).
INSERT INTO soli_config (name, val_int, comment)
VALUES ('venta_min_horas_ultima_venta', 0, 'Horas minimas desde la ultima venta para permitir una nueva')
ON DUPLICATE KEY UPDATE val_int = VALUES(val_int);

-- 4) Saldo alto para la tarjeta de demo recomendada: 6063007014007401.
--    Es la que se usa en docs/demo-transaccion-aprobada.md.
--    Se cargan los 5 productos (993–997) para poder probar cualquier garrafa.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '993', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '994', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '995', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '996', -1, NOW()),
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '997', -1, NOW());
