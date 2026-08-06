-- ============================================================
-- FIX DEMO: habilitar transacción exitosa para el terminal 05000001
-- y la tarjeta de prueba 6063007014007403 (Lillo Espinoza Silvia Del)
--
-- Aplicar contra la base kigsolidario2 del autorizador (MySQL 5.7).
-- Ejecutar con:  mysql -h127.0.0.1 -P3307 -ukigadmin2 -plocaldev kigsolidario2 < fix_demo.sql
-- ============================================================

-- 1) Arreglar el comercio del terminal 05000001.
--    Antes: cod_comercio='000000' (no existe en sgas_comercio) -> rechaza.
--    Ahora: cod_comercio='012502' (GOBIERNO, existe y situacion='V').
UPDATE terminales
   SET cod_comercio = '012502'
 WHERE codigo_terminales = '05000001';

-- 2) Dar saldo positivo y recarga a la tarjeta de Lillo en el producto 993 (GARRAFA10).
--    - saldo = 2000.00  -> calcula_saldo_anterior() devuelve 2000 (saldo_actual > 0).
--    - importe = -4000.00 (negativo) -> obtieneUltimaRecarga() la detecta como recarga de 4000.
--    Con esto, venta_cupon() aprueba ventas de hasta 2000 pesos de gas
--    (tk_amount*10 <= 2000, es decir montos de hasta $200.00).
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007403', CURDATE(), 2, -4000.00, 2000.00, '993', -1, NOW());

-- 3) Permitir ventas consecutivas de la misma tarjeta/producto en el demo.
--    validaTiempoUltimaVenta() rechaza (código 17) si hubo una venta de la misma
--    tarjeta/producto dentro de 'venta_min_horas_ultima_venta' horas (default 72).
--    Para el demo se setea a 0 para no bloquear ventas seguidas.
UPDATE soli_config SET val_int = 0 WHERE name = 'venta_min_horas_ultima_venta';

-- 4) Recarga alta para la tarjeta de demo (6063007014007401, Luhn-válida).
--    El autorizador calcula saldo disponible = saldo_anterior - consumo_vivo (ventas en sgas_cup).
--    Con saldo 20000 permite varias ventas de $100 sin agotarse.
--    NOTA: la tarjeta que aprueba en vivo es 6063007014007401 (no 6063007014007403,
--    que no pasa Luhn). Aplicar esta recarga a 6063007014007401.
INSERT INTO sgas_usuario_cta
    (id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo, prod_id, id_cierre, ts_operacion)
VALUES
    ('18846764', '6063007014007401', CURDATE(), 2, -20000.00, 20000.00, '993', -1, NOW());



-- Verificación (debe devolver 1 fila con cod_comercio='012502'):
-- SELECT codigo_terminales, cod_comercio, situacion FROM terminales WHERE codigo_terminales='05000001';
-- Verificación (debe devolver saldo=2000, importe=-4000):
-- SELECT nro_tarjeta, prod_id, importe, saldo FROM sgas_usuario_cta
--   WHERE nro_tarjeta='6063007014007403' AND prod_id='993' ORDER BY ts_operacion DESC LIMIT 1;
