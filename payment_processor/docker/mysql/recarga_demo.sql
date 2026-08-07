-- ============================================================
-- RECARGA DEMO: cargar saldo alto en las tarjetas de prueba
-- para que el cliente pueda hacer muchas ventas sin agotarse.
--
-- Tarjetas:
--   6063007014007401  (Lillo, Luhn-válida)
--   4111111111111111  (VISA de prueba, Luhn-válida)
--
-- Aplicar contra la base kigsolidario2 del autorizador (MySQL 5.7).
-- Ejecutar con:  mysql -h127.0.0.1 -P3307 -ukigadmin2 -plocaldev kigsolidario2 < recarga_demo.sql
-- ============================================================

-- 0) Extender la vigencia de la tarjeta de Lillo a 12/2028 (DE14 = 1228).
--    El autorizador valida vigencia contra `vigencia_hasta` en sgas_usuario
--    usando el año/mes del DE14 que envía el cliente.
UPDATE sgas_usuario SET vigencia_hasta='2028-12-30' WHERE nro_tarjeta='6063007014007401';

-- 1) Recarga alta para 6063007014007401 (Lillo).
--    saldo = 100000.00 -> permite 1000 ventas de $100.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007401', CURDATE(), 2, -100000.00, 100000.00, '993', -1, NOW());


-- 2) Recarga alta para 4111111111111111 (VISA de prueba).
--    saldo = 100000.00 -> permite 1000 ventas de $100.
--    importe = -100000.00 (negativo) -> el autorizador la detecta como recarga
--    (obtieneUltimaRecarga() busca importe < 0). Con 0.00 no se comportaría como recarga.
--    ADVERTENCIA: el autorizador se cuelga en calcula_saldo_vivo() cuando se intenta
--    autorizar con este PAN (bug del código C) y Docker reinicia el contenedor.
--    No usar esta tarjeta para el demo; usar siempre 6063007014007401.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('12345678', '4111111111111111', CURDATE(), 2, -100000.00, 100000.00, '993', 0, NOW());


-- Verificación (debe devolver saldo=100000 para ambas):
-- SELECT nro_tarjeta, prod_id, importe, saldo FROM sgas_usuario_cta
--   WHERE nro_tarjeta IN ('6063007014007401','4111111111111111') AND prod_id='993'
--   ORDER BY nro_tarjeta, ts_operacion DESC;
