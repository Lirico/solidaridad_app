#!/bin/bash

MYSQL_HOST="192.168.100.6"
MYSQL_DB="kigsolidario2"
MYSQL_USR="kigadmin2"
MYSQL_PAS="mar89\$an2-"

#########################################################################

LASTMON=$(date --date="last month" | gawk -F' ' '{print $2}')
NOWMON=$(date | gawk -F' ' '{print $2}')

NOWT=$(date +%Y%m%d_%H%M%S)

# ANTERIOR
FLMON_USH="/tmp/trx_"$LASTMON"_"$NOWT"_ush.xls"
FLMON_THN="/tmp/trx_"$LASTMON"_"$NOWT"_thn.xls"
FLMON_RGD="/tmp/trx_"$LASTMON"_"$NOWT"_rgd.xls"

# ACTUAL
FNMON_USH="/tmp/trx_"$NOWMON"_"$NOWT"_ush.xls"
FNMON_THN="/tmp/trx_"$NOWMON"_"$NOWT"_thn.xls"
FNMON_RGD="/tmp/trx_"$NOWMON"_"$NOWT"_rgd.xls"

# MES ACTUAL - USHUAIA
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FNMON_USH"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from ( select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and localidad = 'USHUAIA'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and ciudad = 'USHUAIA') as sub1
;" 2>/dev/null

# MES ANTERIOR - TOLHUIN
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FNMON_THN"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from ( select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and localidad = 'TOLHUIN'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and ciudad = 'TOLHUIN') as sub1
;" 2>/dev/null

# MES ACTUAL - RIO GRANDE
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FNMON_RGD"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from ( select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and localidad = 'RIO GRANDE'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01')
 and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-16') )
and ciudad = 'RIO GRANDE') as sub1
;" 2>/dev/null


##############################################################

# MES ANTERIOR - USHUAIA
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FLMON_USH"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from (select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and localidad = 'USHUAIA'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and ciudad = 'USHUAIA'
) as sub1
;" 2>/dev/null


# MES ANTERIOR - TOLHUIN
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FLMON_THN"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from (select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and localidad = 'TOLHUIN'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and ciudad = 'TOLHUIN'
) as sub1
;" 2>/dev/null

# MES ANTERIOR - RIO GRANDE
/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select localidad, tr_date, tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
INTO OUTFILE '"$FLMON_RGD"'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
from (select localidad, tr_date,tr_time, id_carga, nombre, prod_gob, tipo_trans, cantidad_kilo
from repo_all_tr
where
(tr_date between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and localidad = 'RIO GRANDE'
union all
select ciudad, fecha_tr, hora_tr, id_carga, apellido_nombre, prod_id, tipo_trans, cantidad_kilo
from reporte_diaria
where
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-17') and
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month) ) )
and ciudad = 'RIO GRANDE'
) as sub1
;" 2>/dev/null
