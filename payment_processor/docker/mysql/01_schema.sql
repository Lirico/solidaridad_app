/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `terminales` (
  `codigo_terminales` varchar(8) NOT NULL,
  `marca` varchar(50) DEFAULT NULL,
  `modelo` varchar(50) DEFAULT NULL,
  `tipo` varchar(30) DEFAULT NULL,
  `fecha_alta` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_baja` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `cod_comercio` char(6) DEFAULT NULL,
  `situacion` varchar(1) DEFAULT NULL,
  `cod_moneda` varchar(3) NOT NULL DEFAULT '-1',
  `location` varchar(3) NOT NULL DEFAULT 'O',
  UNIQUE KEY `idx_codigo_terminales` (`codigo_terminales`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_usuario` (
  `nro_tarjeta` char(16) NOT NULL DEFAULT '0',
  `id_usuario` varchar(16) DEFAULT NULL,
  `num_cta` varchar(6) DEFAULT NULL,
  `sucursal` varchar(6) DEFAULT NULL,
  `dig_verificador` smallint(5) DEFAULT NULL,
  `idusr_externo` varchar(16) DEFAULT NULL,
  `situacion` varchar(1) DEFAULT NULL,
  `fecha_situacion` date DEFAULT NULL,
  `apellido` varchar(30) DEFAULT NULL,
  `nombre` varchar(30) DEFAULT NULL,
  `apellido_nombre` varchar(128) DEFAULT NULL,
  `sexo` char(1) DEFAULT NULL,
  `estado_civil` char(1) DEFAULT NULL,
  `domicilio` varchar(128) DEFAULT NULL,
  `provincia` varchar(128) DEFAULT NULL,
  `localidad` varchar(128) DEFAULT NULL,
  `barrio` varchar(128) DEFAULT NULL,
  `cod_postal` char(4) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `correo_electronico` varchar(128) DEFAULT NULL,
  `tipo_doc` varchar(3) DEFAULT NULL,
  `nro_doc` varchar(12) NOT NULL,
  `fecha_nac` date DEFAULT NULL,
  `fecha_emision` date DEFAULT NULL,
  `vigencia_desde` date DEFAULT NULL,
  `vigencia_hasta` date DEFAULT NULL,
  `fecha_alta` date DEFAULT NULL,
  `ranking_unidades` smallint(5) DEFAULT NULL,
  `ranking_importe` smallint(5) DEFAULT NULL,
  `entrego_tarjeta` varchar(1) DEFAULT NULL,
  `fecha_entrego_tarjeta` date DEFAULT NULL,
  `marca_baja` int(11) DEFAULT '0',
  `cvv_actual` varchar(4) DEFAULT NULL,
  `cvv_renovacion` varchar(4) DEFAULT NULL,
  `tecc` varchar(32) DEFAULT NULL,
  `email` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`nro_tarjeta`,`nro_doc`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_usuario_cta` (
  `id_usuario` varchar(16) DEFAULT NULL,
  `nro_tarjeta` varchar(16) DEFAULT NULL,
  `fecha_operacion` date DEFAULT NULL,
  `cod_operacion` smallint(5) DEFAULT NULL,
  `importe` float(10,2) NOT NULL DEFAULT '0.00',
  `saldo` float(10,2) NOT NULL DEFAULT '0.00',
  `prod_id` varchar(5) NOT NULL DEFAULT '-1',
  `id_cierre` int(11) NOT NULL DEFAULT '-1',
  `ts_operacion` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `id_tr` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id_tr`)
) ENGINE=InnoDB AUTO_INCREMENT=5389243 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_productos` (
  `id_especial` varchar(5) NOT NULL DEFAULT '',
  `nombre` varchar(128) DEFAULT NULL,
  `kgas_carga` float(10,2) DEFAULT '0.00',
  `id_normal` varchar(5) DEFAULT NULL,
  `multi` int(11) DEFAULT NULL,
  `cod_moneda` varchar(3) NOT NULL DEFAULT '-1',
  `valida_int` int(11) DEFAULT '1',
  `max_tk_unit` int(11) DEFAULT '-1',
  `tname` varchar(10) DEFAULT NULL,
  `kgid` varchar(7) DEFAULT NULL,
  PRIMARY KEY (`id_especial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_comercio` (
  `nro_sucursal` tinyint(4) NOT NULL,
  `cod_comercio` char(6) NOT NULL,
  `marca_suspendido` char(1) DEFAULT NULL,
  `dig_verificador` tinyint(4) DEFAULT NULL,
  `nbre_fantasia` varchar(40) DEFAULT NULL,
  `razon_social` varchar(40) DEFAULT NULL,
  `benef_pago` varchar(40) DEFAULT NULL,
  `domicilio` varchar(40) DEFAULT NULL,
  `provincia` varchar(40) DEFAULT NULL,
  `localidad` varchar(10) DEFAULT NULL,
  `barrio` varchar(10) DEFAULT NULL,
  `cod_postal` varchar(4) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `fecha_alta` date DEFAULT NULL,
  `nro_cuit` varchar(15) DEFAULT NULL,
  `limite_venta` float(10,2) NOT NULL DEFAULT '0.00',
  `correo_electronico` varchar(60) DEFAULT NULL,
  `situacion` varchar(1) DEFAULT NULL,
  `fecha_situacion` date DEFAULT NULL,
  PRIMARY KEY (`nro_sucursal`,`cod_comercio`),
  UNIQUE KEY `uidx_com` (`cod_comercio`),
  KEY `idx_com` (`cod_comercio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_comercio_cta` (
  `nro_sucursal` tinyint(4) DEFAULT NULL,
  `cod_comercio` char(6) DEFAULT NULL,
  `fecha_operacion` date DEFAULT NULL,
  `ts_operacion` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cod_operacion` int(11) DEFAULT NULL,
  `importe` float(10,2) NOT NULL DEFAULT '0.00',
  `saldo` float(10,2) NOT NULL DEFAULT '0.00',
  `id_cierre` int(11) NOT NULL DEFAULT '-1',
  `prod_id` varchar(5) NOT NULL DEFAULT '-1',
  `id_tr` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id_tr`)
) ENGINE=InnoDB AUTO_INCREMENT=5402554 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_cup` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cod_comercio` varchar(10) NOT NULL,
  `cod_moneda` char(3) NOT NULL,
  `terminal_time` time NOT NULL,
  `terminal_date` date DEFAULT NULL,
  `vencimiento` varchar(4) DEFAULT NULL,
  `cant_cuotas` int(10) unsigned DEFAULT '0',
  `importe` float(10,2) DEFAULT '0.00',
  `codigo_autorizacion` varchar(15) NOT NULL,
  `refref` varchar(15) DEFAULT '',
  `id_operacion` int(10) unsigned NOT NULL DEFAULT '0',
  `procode` varchar(6) DEFAULT NULL,
  `codigo_respuesta` char(2) DEFAULT NULL,
  `terminalid` varchar(8) NOT NULL,
  `tipo_plan` char(1) DEFAULT NULL,
  `importe_resp` decimal(12,2) DEFAULT NULL,
  `lote` int(11) NOT NULL,
  `numero_comprobante` int(11) NOT NULL,
  `anula_comprobante` int(11) DEFAULT '-1',
  `comentario_autorizacion` varchar(40) DEFAULT NULL,
  `tipo_mensaje` char(4) DEFAULT NULL,
  `nro_tarjeta` varchar(55) DEFAULT NULL,
  `ts_operacion` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`,`cod_comercio`,`cod_moneda`,`codigo_autorizacion`,`id_operacion`,`terminalid`,`lote`,`numero_comprobante`,`terminal_time`)
) ENGINE=InnoDB AUTO_INCREMENT=4709112 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_trx` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cod_comercio` varchar(10) DEFAULT NULL,
  `cod_moneda` char(3) DEFAULT NULL,
  `terminal_time` time DEFAULT NULL,
  `terminal_date` date DEFAULT NULL,
  `vencimiento` varchar(4) DEFAULT NULL,
  `cant_cuotas` int(10) unsigned DEFAULT '0',
  `importe` float(10,2) DEFAULT '0.00',
  `codigo_autorizacion` varchar(15) DEFAULT NULL,
  `refref` varchar(15) DEFAULT '',
  `id_operacion` int(10) unsigned DEFAULT '0',
  `procode` varchar(6) DEFAULT NULL,
  `codigo_respuesta` char(2) DEFAULT NULL,
  `terminalid` varchar(8) DEFAULT NULL,
  `tipo_plan` char(1) DEFAULT NULL,
  `importe_resp` decimal(12,2) DEFAULT NULL,
  `lote` int(11) DEFAULT NULL,
  `numero_comprobante` int(11) DEFAULT NULL,
  `anula_comprobante` int(11) DEFAULT NULL,
  `comentario_autorizacion` varchar(40) DEFAULT NULL,
  `tipo_mensaje` char(4) DEFAULT NULL,
  `nro_tarjeta` varchar(55) DEFAULT NULL,
  `marca_cierre` char(1) DEFAULT 'N',
  `cant_ventas` int(10) unsigned DEFAULT '0',
  `total_ventas` float(10,2) DEFAULT '0.00',
  `cant_anul` int(10) unsigned DEFAULT '0',
  `total_anul` float(10,2) DEFAULT '0.00',
  `cant_devol` int(10) unsigned DEFAULT '0',
  `total_devol` float(10,2) DEFAULT '0.00',
  `ts_operacion` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ncom_id` int(11) DEFAULT '0',
  `id_envio` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6352434 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_cup_trx` (
  `id` int(11) NOT NULL DEFAULT '0',
  `cod_comercio` varchar(10) CHARACTER SET utf8 DEFAULT NULL,
  `cod_moneda` char(3) CHARACTER SET utf8 DEFAULT NULL,
  `terminal_time` time DEFAULT NULL,
  `terminal_date` date DEFAULT NULL,
  `vencimiento` varchar(4) CHARACTER SET utf8 DEFAULT NULL,
  `cant_cuotas` int(10) unsigned DEFAULT '0',
  `importe` float(10,2) DEFAULT '0.00',
  `codigo_autorizacion` varchar(15) CHARACTER SET utf8 DEFAULT NULL,
  `refref` varchar(15) CHARACTER SET utf8 DEFAULT '',
  `id_operacion` int(10) unsigned DEFAULT '0',
  `procode` varchar(6) CHARACTER SET utf8 DEFAULT NULL,
  `codigo_respuesta` char(2) CHARACTER SET utf8 DEFAULT NULL,
  `terminalid` varchar(8) CHARACTER SET utf8 DEFAULT NULL,
  `tipo_plan` char(1) CHARACTER SET utf8 DEFAULT NULL,
  `importe_resp` decimal(12,2) DEFAULT NULL,
  `lote` int(11) DEFAULT NULL,
  `numero_comprobante` int(11) DEFAULT NULL,
  `anula_comprobante` int(11) DEFAULT NULL,
  `comentario_autorizacion` varchar(40) CHARACTER SET utf8 DEFAULT NULL,
  `tipo_mensaje` char(4) CHARACTER SET utf8 DEFAULT NULL,
  `nro_tarjeta` varchar(55) CHARACTER SET utf8 DEFAULT NULL,
  `ts_operacion` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `id_envio` int(11) DEFAULT '0',
  `ncom_id` int(11) DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `iso_pool` (
  `tpdu` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `mtype` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `bitmap_1` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `pan_2` varchar(40) COLLATE utf8_bin DEFAULT 'NULL',
  `procode_3` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `amount_4` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `datetime_7` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `systracenum_11` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `timetrx_12` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `datetrx_13` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `dateexpire_14` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `datesettle_15` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `datecapute_17` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `posentrymode_22` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `nii_24` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `poscondcode_25` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `track2_35` varchar(40) COLLATE utf8_bin DEFAULT 'NULL',
  `retrefnum_37` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `authid_38` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `respcode_39` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `termid_41` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `merchid_42` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `track1_45` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `adddataiso_46` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `adddataprvt_48` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `currcode_49` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `settcurrcode_50` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `addamount_54` varchar(40) COLLATE utf8_bin DEFAULT NULL,
  `field_59` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `field_60` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `field_61` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `field_62` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `field_63` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `length_63` int(11) DEFAULT NULL,
  `cvv_55` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `datetime_trx` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `soli_categories` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `categoria` bigint(20) DEFAULT NULL,
  `precio_kg_gas` double DEFAULT NULL,
  `coef_benef` double DEFAULT NULL,
  `monto_benef` double DEFAULT NULL,
  `coef_prov` double DEFAULT NULL,
  `monto_prov` double DEFAULT NULL,
  `coef_nac` double DEFAULT NULL,
  `monto_nac` double DEFAULT NULL,
  `vigencia_desde` datetime(3) DEFAULT NULL,
  `vigencia_hasta` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_category` (`categoria`,`vigencia_desde`),
  KEY `idx_soli_categories_deleted_at` (`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_usuario_expansion` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nro_tarjeta` char(16) NOT NULL,
  `nro_doc` varchar(12) NOT NULL,
  `categoria_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_nro_tarjeta_nro_doc` (`nro_tarjeta`,`nro_doc`),
  KEY `fk_categorias` (`categoria_id`),
  CONSTRAINT `fk_categorias` FOREIGN KEY (`categoria_id`) REFERENCES `soli_categories` (`id`),
  CONSTRAINT `fk_tabla_principal` FOREIGN KEY (`nro_tarjeta`, `nro_doc`) REFERENCES `sgas_usuario` (`nro_tarjeta`, `nro_doc`)
) ENGINE=InnoDB AUTO_INCREMENT=12990 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `soli_config` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8_bin NOT NULL,
  `val_char` varchar(255) COLLATE utf8_bin DEFAULT NULL,
  `val_int` int(11) DEFAULT NULL,
  `category` varchar(30) COLLATE utf8_bin DEFAULT 'general',
  `comment` text COLLATE utf8_bin,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_name` (`name`),
  KEY `idx_cat` (`category`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgas_usuario_load` (
  `uid_gob` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `nombre_apellido` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `tipo_doc` varchar(4) COLLATE utf8_bin DEFAULT NULL,
  `nro_doc` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `fec_nac` date DEFAULT NULL,
  `domicilio` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `provincia` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `localidad` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `barrio` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `cod_postal` varchar(8) COLLATE utf8_bin DEFAULT NULL,
  `cod_operacion` char(1) COLLATE utf8_bin DEFAULT NULL,
  `categoria` int(11) DEFAULT NULL,
  `primera` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `num_cuenta` varchar(6) COLLATE utf8_bin DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `soli_db_scripts` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `filename` varchar(255) COLLATE utf8_bin NOT NULL,
  `applied_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_filename` (`filename`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;
