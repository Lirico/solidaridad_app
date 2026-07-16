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

int carga_load(MYSQL *con, char* nro_doc)
{
    int num_rows = 0;
    char* sql;

    if (con == NULL) 
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -1;
	}

	printf("carga_load() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "DELETE FROM sgas_usuario_load");
	if (mysql_query(con, sql)) 
	{
		printf("carga_load() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	sprintf("INSERT INTO sgas_usuario_load (idusr_externo, nombre_apellido, tipo_doc, nro_doc, fec_nac, "
			"domicilio, provincia, localidad, barrio, cod_postal, cod_operacion) "
			"SELECT idusr_externo, apellido_nombre, tipo_doc, nro_doc, fecha_nac, domicilio, "
			"provincia, localidad, barrio, cod_postal, 'A' FROM sgas_usuario WHERE nro_doc = '%s'", nro_doc);

	free(sql);

    printf("cierra_mes_usuario() - END \n");

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

	sprintf(sql, "SELECT nro_doc FROM sgas_usuario WHERE marca_baja=1");

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
