#!/bin/bash

# CANTIDAD DE RESUMENES CARGADOS

MYSQL_HOST="192.168.100.6"
MYSQL_DB="kigsolidario2"
MYSQL_USR="kigadmin2"
MYSQL_PAS="mar89\$an2-"


## MES ANTERIOR

/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select 'CARGA MENSUAL', 'DEVOLUCION', 'DESCARGA', 'CIERRE', 'CON.SALDO', 'DENEGADA', 'REVERSO', 'DESDE', 'HASTA'
union all
select * from
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') and 
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month))) 
and tipo_trans='CARGA MENSUAL') ts1,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') and 
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month))) 
and tipo_trans='DEVOL') ts2,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') and 
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month))) 
and tipo_trans='DESCARGA') ts3,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') and 
LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 month))) 
and tipo_trans='CIERRE') ts4,
(select count(*)  from iso_pool where mtype='0100' and respcode_39='00' and (datetime_trx between 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') and  LAST_DAY( DATE_SUB(CURRENT_DATE(), 
INTERVAL 1 month)) )  ) t1,
(select count(*) from iso_pool where mtype in ('0100', '0200') and
(respcode_39!='' and respcode_39!='00') and (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) 
, '%Y-%m'), '-15') and  LAST_DAY( DATE_SUB(CURRENT_DATE(), INTERVAL 1 month)) ) ) t2,
(select count(*) from iso_pool where mtype='0400' and
(respcode_39!='' and respcode_39='00') and (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) 
, '%Y-%m'), '-15') and  LAST_DAY( DATE_SUB(CURRENT_DATE(), INTERVAL 1 month)) ) ) t3,
(select concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) , '%Y-%m'), '-15') ) t4,
(select LAST_DAY( DATE_SUB(CURRENT_DATE(), INTERVAL 1 month))) t5
;" 2>/dev/null

echo ""
echo ""

### MES EN CURSO

/usr/local/mysql57/bin/mysql --skip-column-names -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS \
-e "select 'CARGA MENSUAL', 'DEVOLUCION', 'DESCARGA', 'CIERRE', 'CON.SALDO', 'DENEGADA', 'REVERSO', 'DESDE', 'HASTA'
union all
select * from
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) 
and tipo_trans='CARGA MENSUAL') ts1,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) 
and tipo_trans='DEVOL') ts2,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) 
and tipo_trans='DESCARGA') ts3,
(select count(*) from reporte_diaria where 
(fecha_tr between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) 
and tipo_trans='CIERRE') ts4,
(select count(*)  from iso_pool where mtype='0100' and respcode_39='00' and (datetime_trx between 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') and 
concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') )) t1,
(select count(*) from iso_pool where mtype in ('0100', '0200') and
(respcode_39!='' and respcode_39!='00') and (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) 
, '%Y-%m'), '-01') and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') )) t2,
(select count(*) from iso_pool where mtype='0400' and
(respcode_39!='' and respcode_39='00') and (datetime_trx between concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) 
, '%Y-%m'), '-01') and concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') )) t3,
(select concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-01') ) t4,
(select concat(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 0 MONTH) , '%Y-%m'), '-14') ) t5
;" 2>/dev/null

