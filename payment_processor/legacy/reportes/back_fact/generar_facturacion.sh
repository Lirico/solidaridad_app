#!/bin/bash

# CANTIDAD DE RESUMENES CARGADOS

MYSQL_HOST="192.168.100.6"
MYSQL_DB="kigsolidario2"
MYSQL_USR="kigadmin2"
MYSQL_PAS="mar89\$an2-"


####### LIMPIO LA TABLA


## MES ANTERIOR

/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e ";" 2>/dev/null



/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "insert into repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) (
select * from(
select if(merchid_42='014113' or merchid_42='014114', 'USHUAIA',
if(merchid_42='022873' or merchid_42='022874', 'RIO GRANDE',
if(merchid_42='014116', 'TOLHUIN', 'SL'))) localidad, 
DATE_FORMAT(datetime_trx, '%Y-%m-%d') fecha, 
DATE_FORMAT(datetime_trx, '%H:%i:%s') hora,
'0' id_carga, if( track1_45='', if( track2_35='', pan_2 , substring(track2_35, 1, 16) ), track1_45) usuario,
if(currcode_49='993', '1',if(currcode_49='994', '4',if(currcode_49='995', '5',if(currcode_49='996', '2',
if(currcode_49='997', '3', '0'))))) prod_id, 
'DENEGADA' trans,amount_4
from iso_pool where (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') 
and LAST_DAY( DATE_SUB(CURRENT_DATE(), INTERVAL 1 month)))
and mtype in ('0100', '0200') and (respcode_39!='' and respcode_39!='00' )) t2)
;" 2>/dev/null



/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "insert into repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) (
select * from (
select if(merchid_42='014113' or merchid_42='014114', 'USHUAIA',
if(merchid_42='022873' or merchid_42='022874', 'RIO GRANDE',
if(merchid_42='014116', 'TOLHUIN', 'SL'))) localidad, 
DATE_FORMAT(datetime_trx, '%Y-%m-%d') fecha, 
DATE_FORMAT(datetime_trx, '%H:%i:%s') hora,
'0' id_carga, if( track1_45='', if( track2_35='', pan_2 , substring(track2_35, 1, 16) ), track1_45) usuario,
if(currcode_49='993', '1',if(currcode_49='994', '4',if(currcode_49='995', '5',if(currcode_49='996', '2',
if(currcode_49='997', '3', '0'))))) prod_id, 'REVERSO' trans, amount_4
from iso_pool where (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') 
and LAST_DAY( DATE_SUB(CURRENT_DATE(), INTERVAL 1 month)) ) and mtype='0400' and respcode_39='00' ) t2)
;" 2>/dev/null


######################################################################
### MES EN CURSO
######################################################################


/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "insert into repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) (
select * from (
select if(merchid_42='014113' or merchid_42='014114', 'USHUAIA',
if(merchid_42='022873' or merchid_42='022874', 'RIO GRANDE',
if(merchid_42='014116', 'TOLHUIN', 'SL'))) localidad, 
DATE_FORMAT(datetime_trx, '%Y-%m-%d') fecha, 
DATE_FORMAT(datetime_trx, '%H:%i:%s') hora,
'0' id_carga, if( track1_45='', if( track2_35='', pan_2 , substring(track2_35, 1, 16) ), track1_45) usuario,
if(currcode_49='993', '1',if(currcode_49='994', '4',if(currcode_49='995', '5',if(currcode_49='996', '2',
if(currcode_49='997', '3', '0'))))) prod_id, 'CON.SALDO' trans, amount_4
from iso_pool where (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') 
and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) 
and mtype='0100' and respcode_39='00') t1)
;" 2>/dev/null



/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "insert into repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) (
select * from (
select if(merchid_42='014113' or merchid_42='014114', 'USHUAIA',
if(merchid_42='022873' or merchid_42='022874', 'RIO GRANDE',
if(merchid_42='014116', 'TOLHUIN', 'SL'))) localidad, 
DATE_FORMAT(datetime_trx, '%Y-%m-%d') fecha, 
DATE_FORMAT(datetime_trx, '%H:%i:%s') hora,
'0' id_carga, if( track1_45='', if( track2_35='', pan_2 , substring(track2_35, 1, 16) ), track1_45) usuario,
if(currcode_49='993', '1',if(currcode_49='994', '4',if(currcode_49='995', '5',if(currcode_49='996', '2',
if(currcode_49='997', '3', '0'))))) prod_id, 'DENEGADA' trans, amount_4
from iso_pool where (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') )
and mtype in ('0100', '0200') and (respcode_39!='' and respcode_39!='00' )) t2)
;" 2>/dev/null



/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "insert into repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) (
select * from (
select if(merchid_42='014113' or merchid_42='014114', 'USHUAIA',
if(merchid_42='022873' or merchid_42='022874', 'RIO GRANDE',
if(merchid_42='014116', 'TOLHUIN', 'SL'))) localidad, 
DATE_FORMAT(datetime_trx, '%Y-%m-%d') fecha, 
DATE_FORMAT(datetime_trx, '%H:%i:%s') hora,
'0' id_carga, if( track1_45='', if( track2_35='', pan_2 , substring(track2_35, 1, 16) ), track1_45) usuario,
if(currcode_49='993', '1',if(currcode_49='994', '4',if(currcode_49='995', '5',if(currcode_49='996', '2',
if(currcode_49='997', '3', '0'))))) prod_id, 'REVERSO' trans, amount_4
from iso_pool where (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') )
and mtype='0400' and respcode_39='00' ) t2)
;" 2>/dev/null


