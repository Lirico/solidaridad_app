CREATE TABLE IF NOT EXISTS `soli_config` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `val_char` VARCHAR(255) DEFAULT NULL,         -- Valor siempre como string para fácil casting en C
  `val_int` INT(11) DEFAULT NULL,               -- Columna espejo para valores numéricos directos
  `category` VARCHAR(30) DEFAULT 'general',
  `comment` TEXT,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_name` (`name`),
  INDEX `idx_cat` (`category`)
);

INSERT IGNORE INTO `soli_config` (`name`, `val_int`, `comment`)
VALUES ('venta_max_porcentaje_ultima_recarga', 5000, 'Maximo monto de venta en relacion a la ultima recarga en %, con dos decimales');

INSERT IGNORE INTO `soli_config` (`name`, `val_int`, `comment`)
VALUES ('venta_min_horas_ultima_venta', 72, 'Horas minimas desde la ultima venta para permitir una nueva');

INSERT IGNORE INTO `soli_db_scripts` (`filename`)
VALUES ('2025-12-18.sql');
