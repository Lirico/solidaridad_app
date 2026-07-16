#!/bin/bash

## loader mysql

MYSQL_HOST="192.168.1.1"
MYSQL_DB="kigsolidario2"
MYSQL_USR="kigadmin2"
MYSQL_PAS="mar89\$an2-"
F_PATH=$1

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "DELETE FROM sgas_usuario_load;"
if [ $? -ne 0 ]; then
        echo "ERROR: Borrando SGAS_USUARIO_LOAD."
        exit 1
fi

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "LOAD DATA LOCAL INFILE '$F_PATH' INTO TABLE sgas_usuario_load FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';"
if [ $? -ne 0 ]; then
	echo "ERROR: Carga de Beneficiarios."
	exit 1
fi


