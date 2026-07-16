#include <stdio.h> //standar io
#include <string.h> //funciones str...
#include <stdlib.h> //función atoi()
#include <sys/types.h> //funciones de socket
#include <sys/socket.h> //funciones de socket
#include <netdb.h> //funciones de socket
#include <unistd.h> //función select
#include <errno.h> //errores referidos a los sockets
#include <time.h> //función time
#include <sys/select.h> //función select
#include <sys/time.h> //timeout de select
#include <arpa/inet.h>

#include <my_global.h>
#include <mysql.h>

#include <auth_kig.h>
#include <auth_mycli.h>

#define COMER_TYPE 1
#define USER_TYPE 0


struct authCONF* aconf;

/*
    ./acumulator_kig <config_file> <hora>
*/

struct SM{
	int id;
	char fecha_op[11];
	double importe;
	int cod_moneda;
	int num;
	char ts_operacion[21];
};

typedef struct SM Cupon;

Cupon* get_consumo_vivo(MYSQL* con, char* card_number, char* cod_moneda, int flag)
{
    Cupon* ret = NULL;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_fields;
    double prod_charge = 0.0;
    int num_rows;
    int i, j;
    
    Cupon* cup;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("get_consumo_vivo(): INIT \n");

    if (con == NULL) 
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return (Cupon*)NULL;
    }

    if (flag == USER_TYPE)
    {
    	sprintf(sql, "SELECT  id, terminal_date, importe, cod_moneda, tipo_mensaje, procode, ts_operacion FROM sgas_cup_trx "
                "WHERE "
                " cod_moneda='%s' AND nro_tarjeta='%s' AND "
                "ORDER BY ts_operacion",
                cod_moneda, card_number
    	);
	} else if (flag == COMER_TYPE) {
		sprintf(sql, "SELECT  id, terminal_date, importe, cod_moneda, tipo_mensaje, procode, ts_operacion FROM sgas_cup_trx "
                "WHERE  "
                " cod_moneda='%s' AND cod_comercio='%s'"
                "ORDER BY ts_operacion",
                cod_moneda, card_number
    	);
	}

    printf("get_consumo_vivo() - SQL: %s\n", sql);

    if (mysql_query(con, sql)) 
    {
        printf("get_consumo_vivo() ERROR: exec query.\n");
        free(sql);
        return (Cupon*)NULL;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("get_consumo_vivo() ERROR: store results. \n");
        free(sql);
        return (Cupon*)NULL;
    }

    num_rows = mysql_num_rows(result);

    printf("get_consumo_vivo() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0) 
    {
        cup = (Cupon*) malloc(sizeof(Cupon)*num_rows);

        for (i=0; i<num_rows; i++)
        {
            row = mysql_fetch_row(result);

            cup[i].id = atoi(row[0]);

            memset(cup[i].fecha_op, '\0', 11);
            sprintf(cup[i].fecha_op, "%s", row[1]);
            
            prod_charge = getProdAmount(con, row[3]);

            if (atoi(row[5]) == 20000)
            {
                cup[i].importe = (atof(row[2])*prod_charge)*(-1);
            } else {
                cup[i].importe = atof(row[2])*prod_charge;
            }
            
            cup[i].cod_moneda = atoi(row[3]);

            memset(cup[i].ts_operacion, '\0', 21);
            sprintf(cup[i].ts_operacion, "%s", row[6]);

            printf("get_consumo_vivo() LOG id = %d; fecha_op = %s, importe = %f; moneda = %d; ts_operacion = %s \n",
                cup[i].id, cup[i].fecha_op, cup[i].importe, cup[i].cod_moneda, cup[i].ts_operacion);
        }

        cup[0].num = num_rows;

        mysql_free_result(result);

        ret = cup;
    } else {
        ret = NULL;
    }
  
    free(sql);
    return (Cupon*)ret;
}

int cierra_cuenta_usuario(MYSQL *con, char* cod_moneda)
{
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    int i = 0;
    int k = 0;

    double saldo_anterior = 0.0;
    double saldo_final = 0.0;

    char* sql;
    char* sql_ins;

    if (con == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -1;
	}

	printf("cierra_cuenta_usuario() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT nro_tarjeta, nro_doc FROM sgas_usuario "
                 "WHERE nro_tarjeta in (SELECT DISTINCT nro_tarjeta FROM sgas_cup_trx WHERE cod_moneda='%s')", cod_moneda);

	if (mysql_query(con, sql)) 
	{
		printf("cierra_cuenta_usuario() ERROR: exec SQL.");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("cierra_cuenta_usuario() ERROR: store results.");
		free(sql);
		return -3;
	}

	sql_ins = (char*)malloc(sizeof(char)*1024);

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		for (i=0; i<num_rows; i++ )
		{
			row = mysql_fetch_row(result);

			saldo_anterior = calcula_saldo_anterior(con, row[0], cod_moneda);
            if(saldo_anterior == -1)
            {
                saldo_anterior = 0.0;
            }
            
        	Cupon* cup = get_consumo_vivo(con, row[0], cod_moneda, USER_TYPE);

        	if (cup != NULL)
        	{
            	saldo_final = saldo_anterior;

            	for (k=0; k<cup[0].num; k++)
            	{
                	saldo_final = saldo_final - cup[k].importe;

                	printf("cierra_lote_efectivo() - saldo_final cta.cte.: %f\n", saldo_final);

                	memset(sql_ins, '\0', 1024);

                	sprintf(sql_ins, "INSERT INTO sgas_usuario_cta (fecha_operacion, cod_operacion, importe, saldo, nro_tarjeta, id_usuario, id_cierre, prod_id, ts_operacion) VALUES("
                    	"'%s', 2, %f, %f, '%s', '%s', %d, '%s', '%s')",
                    	cup[k].fecha_op, cup[k].importe, saldo_final, row[0], row[1], cup[k].id, cod_moneda, cup[k].ts_operacion
                	);

                	printf("cierra_lote_efectivo() - INSERT cta.cte. SQL: %s\n", sql_ins);

                	if (mysql_query(con, sql_ins))
                	{
                    	fprintf(stderr, "%s\n", mysql_error(con));
                    	return -3;
                	}
            	}
        	}
		}
	}

	free(sql);

    printf("cierra_cuenta_usuario() - END \n");

    free(sql_ins);
    mysql_free_result(result);
	return 0;
}

int cierra_cuenta_comercio(MYSQL *con, char* cod_moneda)
{
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    int i = 0;
    int k = 0;

    double saldo_anterior = 0.0;
    double saldo_final = 0.0;

    char* sql;
    char* sql_ins;

    if (con == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -1;
	}

	printf("cierra_cuenta_comercio() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT cod_comercio, nro_sucursal FROM sgas_comercio "
                 "WHERE cod_comercio in (SELECT DISTINCT cod_comercio FROM sgas_cup_trx WHERE cod_moneda='%s')", cod_moneda);

	if (mysql_query(con, sql)) 
	{
		printf("cierra_cuenta_comercio() ERROR: exec SQL.");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("cierra_cuenta_comercio() ERROR: store results.");
		free(sql);
		return -3;
	}

	sql_ins = (char*)malloc(sizeof(char)*1024);

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		for (i=0; i<num_rows; i++ )
		{
			row = mysql_fetch_row(result);

			saldo_anterior = saldo_anterior_comercio(con, row[0], cod_moneda);
        	Cupon* cup = get_consumo_vivo(con, row[0], cod_moneda, COMER_TYPE);

        	if (cup != NULL)
        	{
            	saldo_final = saldo_anterior;

            	for (k=0; k<cup[0].num; k++)
            	{
                	saldo_final = saldo_final + cup[k].importe;

                	printf("cierra_cuenta_comercio() - saldo_final cta.cte.: %f\n", saldo_final);

                	memset(sql_ins, '\0', 1024);

                	sprintf(sql_ins, "INSERT INTO sgas_comercio_cta (fecha_operacion, cod_operacion, importe, saldo, cod_comercio, "
                		             "nro_sucursal, id_cierre, prod_id, ts_operacion) VALUES("
                    	"'%s', 1, %f, %f, '%s', %s, %d, '%s', '%s')",
                    	cup[k].fecha_op, cup[k].importe, saldo_final, row[0], row[1], cup[k].id, cod_moneda, cup[k].ts_operacion
                	);

                	printf("cierra_cuenta_comercio() - INSERT cta.cte. SQL: %s\n", sql_ins);

                	if (mysql_query(con, sql_ins))
                	{
                    	fprintf(stderr, "%s\n", mysql_error(con));
                    	return -3;
                	}
            	}
        	}
		}

		mysql_free_result(result);
	}

	free(sql);

	// Borrado de ACUM
	memset(sql_ins, '\0', 1024);
    sprintf(sql_ins, "DELETE FROM sgas_cup_trx WHERE cod_moneda='%s'", cod_moneda);

    printf("cierra_cuenta_comercio() - delete CUP SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
    	free(sql_ins);
        return -3;
    }

    if(mysql_affected_rows(con) == 0)
    {
    	free(sql_ins);
        return -3;
    }

    printf("cierra_cuenta_comercio() - END \n");

    free(sql_ins);
    
	return 0;
}

int main(int argc, char** argv)
{
	int ret = 0;
	MYSQL *con;
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    char* sql;
    int i = 0;

	if(argc<2)
    {
        printf("Error: Ingreso de parametros incorrectos, uso: %s <conf_file>\n");
        return -1;
    }

    if (read_config(argv[1]) != 0)
    {
        return -1;
    }

    con = mysql_init(NULL);

    if (con == NULL) 
    {
    	fprintf(stderr, "%s\n", mysql_error(con));
		return -2;
	}

	if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		mysql_close(con);
		return -3;
	}

	printf(" %s main() - INIT . \n", argv[0]);

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT cod_moneda, nombre FROM sgas_productos");

	if (mysql_query(con, sql)) 
	{
		printf("%s main() ERROR: exec SQL. \n", argv[0]);
		free(sql);
		return -3;
	}

	printf(" %s main() - SQL . \n", argv[0]);

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("%s main() ERROR: store results. \n", argv[0]);
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		for (i=0; i<num_rows; i++ )
        {
        	row = mysql_fetch_row(result);

        	printf(" %s main() - PROCESA MONEDA: %s \n", argv[0], row[1]);

			cierra_cuenta_usuario(con, row[0]);
			cierra_cuenta_comercio(con, row[0]);
		}
	}

	free(sql);
	mysql_free_result(result);
	mysql_close(con);

	printf(" %s main() - END %s \n", argv[0]);
	return ret;
}
