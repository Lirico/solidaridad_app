CREATE TABLE IF NOT EXISTS `soli_db_scripts` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `filename` VARCHAR(255) NOT NULL,          -- Nombre del .sql aplicado (por ejemplo: 2025-12-18.sql)
  `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_filename` (`filename`)
);

CREATE TABLE IF NOT EXISTS `soli_categories` (
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
);

CREATE TABLE IF NOT EXISTS `sgas_usuario_expansion` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nro_tarjeta` char(16) NOT NULL,
  `nro_doc` varchar(12) NOT NULL,
  `categoria_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_nro_tarjeta_nro_doc` (`nro_tarjeta`,`nro_doc`),
  KEY `fk_categorias` (`categoria_id`),
  CONSTRAINT `fk_categorias` FOREIGN KEY (`categoria_id`) REFERENCES `soli_categories` (`id`),
  CONSTRAINT `fk_tabla_principal` FOREIGN KEY (`nro_tarjeta`, `nro_doc`) REFERENCES `sgas_usuario` (`nro_tarjeta`, `nro_doc`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO `soli_db_scripts` (`filename`)
VALUES ('2023-12-13.sql');
