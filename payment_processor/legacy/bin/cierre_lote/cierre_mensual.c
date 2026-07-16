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

int valida_prodcuto(MYSQL *con, char* ncard, char* cod_moneda)
{
	int ret = 0;
	MYSQL_RES *result;
    int num_rows = 0;
    char* sql;
    struct tm z;
    time_t now;
    
    sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	if (con == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -1;
	}

	time (&now);
    z=*localtime(&now);

	printf("valida_prodcuto() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT * FROM sgas_usuario_cta WHERE nro_tarjeta='%s' AND prod_id='%s' AND fecha_operacion like '%d-%02d-%%' ",
    ncard, cod_moneda, (z.tm_year+1900), (z.tm_mon+1) );

	if (mysql_query(con, sql)) 
	{
		printf("valida_prodcuto() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("valida_prodcuto() ERROR: store results. \n");
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows <= 0)
	{
		ret = -1;
	}

	printf("valida_prodcuto() - END \n");

	free(sql);
	mysql_free_result(result);
	return ret;
}

int cierra_mes_usuario(MYSQL *con, char* cod_moneda)
{
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    int i = 0;
    int k = 0;

    double saldo_anterior = 0.0;
    double saldo_final = 0.0;
    double importe = 0.0;

    char* sql;
    char* sql_ins;

    if (con == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -1;
	}

	printf("cierra_mes_usuario() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT nro_tarjeta, nro_doc FROM sgas_usuario WHERE situacion='V'");

	if (mysql_query(con, sql)) 
	{
		printf("cierra_mes_usuario() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("cierra_mes_usuario() ERROR: store results. \n");
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
			
			if (valida_prodcuto(con, row[0], cod_moneda) == 0)
			{
				saldo_anterior = calcula_saldo_anterior(con, row[0], cod_moneda);

				if (saldo_anterior >= 0)
				{
            		importe = saldo_anterior;

            		saldo_final = saldo_anterior - importe;

            		printf("cierra_mes_usuario() - saldo_final cta.cte.: %f\n", saldo_final);

					memset(sql_ins, '\0', 1024);

					sprintf(sql_ins, "INSERT INTO sgas_usuario_cta (fecha_operacion, cod_operacion, importe, saldo, nro_tarjeta, id_usuario, id_cierre, prod_id, ts_operacion) VALUES("
                		"CURRENT_DATE(), 1, %f, %f, '%s', '%s', cast(DATE_FORMAT(CURRENT_DATE(), '%%Y%%m%%d') as unsigned), '%s', CURRENT_TIMESTAMP )",
                		importe, saldo_final, row[0], row[1], cod_moneda
            		);

					printf("cierra_mes_usuario() - INSERT cta.cte. SQL: %s\n", sql_ins);

					if (mysql_query(con, sql_ins))
					{
						fprintf(stderr, "%s\n", mysql_error(con));
						return -3;
					}
				} else {
					importe = saldo_anterior;

            		saldo_final = 0.0;

            		printf("cierra_mes_usuario() - saldo_final cta.cte.: %f\n", saldo_final);

					memset(sql_ins, '\0', 1024);

					sprintf(sql_ins, "INSERT INTO sgas_usuario_cta (fecha_operacion, cod_operacion, importe, saldo, nro_tarjeta, id_usuario, id_cierre, prod_id, ts_operacion) VALUES("
                		"CURRENT_DATE(), 1, %f, %f, '%s', '%s', cast(DATE_FORMAT(CURRENT_DATE(), '%%Y%%m%%d') as unsigned), '%s', CURRENT_TIMESTAMP )",
                		importe, saldo_final, row[0], row[1], cod_moneda
            		);

					printf("cierra_mes_usuario() - INSERT cta.cte. SQL: %s\n", sql_ins);

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

    printf("cierra_mes_usuario() - END \n");

    free(sql_ins);
    mysql_free_result(result);
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

			cierra_mes_usuario(con, row[0]);
		}
	}

	free(sql);
	mysql_free_result(result);
	printf(" %s main() - END %s \n", argv[0]);
	return ret;
}
