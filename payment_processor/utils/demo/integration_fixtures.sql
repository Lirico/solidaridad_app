-- Fixtures exclusivos para integración contra el procesador local.
-- Se aplican únicamente con `make integration-reset`.

DELETE FROM sgas_usuario_cta
 WHERE nro_tarjeta IN (
    '6063007014990001', '6063007014990002', '6063007014990003',
    '6063007014990004'
 );

DELETE FROM sgas_usuario
 WHERE nro_tarjeta IN (
    '6063007014990001', '6063007014990002', '6063007014990003',
    '6063007014990004'
 );

-- 0001: saldo suficiente para DE49=993.
-- 0002: cuenta existente sin saldo: rechazo por límite/fondos (65).
-- 0003: sin cuenta para 993: rechazo por producto no asignado (06).
-- 0004: saldo reservado para la consulta de saldo, sin ventas en esta suite.
INSERT INTO sgas_usuario (
    nro_tarjeta, id_usuario, situacion, fecha_situacion, apellido_nombre,
    nro_doc, vigencia_desde, vigencia_hasta, fecha_alta, marca_baja,
    cvv_actual, cvv_renovacion
)
VALUES
    ('6063007014990001', 'INTEG0001', 'V', CURDATE(), 'INTEGRACION APRUEBA', '99000001', CURDATE(), '2029-12-31', CURDATE(), 0, '111', '111'),
    ('6063007014990002', 'INTEG0002', 'V', CURDATE(), 'INTEGRACION SIN SALDO', '99000002', CURDATE(), '2029-12-31', CURDATE(), 0, '222', '222'),
    ('6063007014990003', 'INTEG0003', 'V', CURDATE(), 'INTEGRACION SIN PRODUCTO', '99000003', CURDATE(), '2029-12-31', CURDATE(), 0, '333', '333'),
    ('6063007014990004', 'INTEG0004', 'V', CURDATE(), 'INTEGRACION SALDO', '99000004', CURDATE(), '2029-12-31', CURDATE(), 0, '444', '444');

INSERT INTO sgas_usuario_cta (
    id_usuario, nro_tarjeta, fecha_operacion, cod_operacion, importe, saldo,
    prod_id, id_cierre, ts_operacion
)
VALUES
    ('INTEG0001', '6063007014990001', CURDATE(), 2, -1000.00, 1000.00, '993', -1, NOW()),
    ('INTEG0002', '6063007014990002', CURDATE(), 2, 0.00, 0.00, '993', -1, NOW()),
    ('INTEG0004', '6063007014990004', CURDATE(), 2, -1000.00, 1000.00, '993', -1, NOW());
