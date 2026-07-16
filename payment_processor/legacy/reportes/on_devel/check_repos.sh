
MYSQL_HOST="192.168.100.6"
MYSQL_DB="kigsolidario2"
MYSQL_USR="kigadmin2"
MYSQL_PAS="mar89\$an2-"

F_AYER=$(date -d "-1 days" +"%Y%m%d")

GA_FILE="GASAUSTRAL-"$F_AYER".csv"
SA_FILE="SARTINI-"$F_AYER".csv"
GOB_FILE="REP-DIA"$F_AYER".csv"

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "delete from gasaustral_control;"
if [ $? -ne 0 ]; then
        echo "ERROR: borrando tablas de control: gasaustral_control."
        exit 1
fi

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "delete from sartini_control;"
if [ $? -ne 0 ]; then
        echo "ERROR: borrando tablas de control:  sartini_control."
        exit 1
fi

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "delete from gobierno_control;"
if [ $? -ne 0 ]; then
        echo "ERROR: borrando tablas de control: gobierno_control."
        exit 1
fi


mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "LOAD DATA LOCAL INFILE '$GA_FILE' INTO TABLE gasaustral_control FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';"
if [ $? -ne 0 ]; then
	echo "ERROR: Carga de gasaustral_control."
	exit 1
fi


mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "LOAD DATA LOCAL INFILE '$SA_FILE' INTO TABLE sartini_control FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';"
if [ $? -ne 0 ]; then
        echo "ERROR: Carga de sartini_control."
        exit 1
fi

mysql -u $MYSQL_USR -h $MYSQL_HOST -D $MYSQL_DB --password=$MYSQL_PAS --local-infile=1 \
-e "LOAD DATA LOCAL INFILE '$GOB_FILE' INTO TABLE gobierno_control FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';"
if [ $? -ne 0 ]; then
        echo "ERROR: Carga de gobierno_control."
        exit 1
fi


