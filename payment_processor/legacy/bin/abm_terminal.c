#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <sys/select.h>
#include <sys/time.h>
#include <arpa/inet.h>

#include <my_global.h>
#include <mysql.h>

#include <auth_kig.h>
#include <auth_mycli.h>


int alta_terminal(MYSQL *con, char* terminal, char* comercio, char* loc)
{
    char* sql;
    char* moneda;
    int i;

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    moneda = (char*)malloc(sizeof(char)*4);
    memset(moneda, '\0', 4);

    sprintf(moneda, "993");

    for (i=0; i<5; i++)
	{
		terminal[1]=0x35+i;
		moneda[2]=0x33+i;

    	sprintf(sql, "INSERT INTO terminales (codigo_terminales, marca, modelo, tipo, fecha_alta, fecha_baja, cod_comercio, situacion, cod_moneda, location) "
    		         " VALUES ('%s', 'VeriFone', 'DUO', 'vx520', '2015-11-25 11:46:19', '2015-11-25 11:46:19', '%s', 'V', '%s', '%s') ", 
    		         terminal, comercio, moneda, loc);

    	if (mysql_query(con, sql))
		{
			fprintf(stderr, "%s\n", mysql_error(con));
			return -3;
		}

	}

	free(moneda);
	free(sql);

	return 0;
}

int baja_terminal(MYSQL *con, char* terminal)
{
	int ret = 0;
	char* sql;
	int num_rows;

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

	terminal[1]='%';

	sprintf(sql, "delete from terminales where codigo_terminales like '%s' ", terminal);

	if (mysql_query(con, sql))
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -3;
	}

	num_rows = mysql_affected_rows(con);

	if (num_rows == 0)
	{
		ret = -1;
	}


	free(sql);

	return ret;
}

int consulta(MYSQL *con, char tipo, char* numero)
{
	char* sql;
	int num_rows;
	FILE* fs_out;
	int i;
	MYSQL_ROW row;
    MYSQL_RES *result;

	sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

	switch(tipo)
	{
		case 'T':
				numero[1]='%';
				sprintf(sql, "select codigo_terminales, cod_comercio, if(situacion='V', 'ALTA', 'BAJA'), if(location='C', 'CAMION', 'OFICINA') from terminales where cod_moneda='993' and codigo_terminales like '%s' ", numero);
				break;
		case 'C':
				sprintf(sql, "select codigo_terminales, cod_comercio, if(situacion='V', 'ALTA', 'BAJA'), if(location='C', 'CAMION', 'OFICINA') from terminales where cod_moneda='993' and cod_comercio='%s' ", numero);
				break;
		case 'A':
				sprintf(sql, "select codigo_terminales, cod_comercio, if(situacion='V', 'ALTA', 'BAJA'), if(location='C', 'CAMION', 'OFICINA') from terminales where cod_moneda='993' order by codigo_terminales");
				break;
	}

	if (mysql_query(con, sql)) 
	{
		printf("consulta() ERROR: exec SQL = %s.\n",  sql);
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("consulta() ERROR: store results. \n");
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		fs_out=fopen("abm_terminales_informe.csv", "w+");

		if(fs_out == NULL)
		{
			mysql_free_result(result);
			free(sql);
			return -1;
		}

		for(i=0; i<num_rows; i++)
		{
			row = mysql_fetch_row(result);

			row[0][1]=0x30;

			fprintf(fs_out, "%s;%s;%s;%s\n", row[0], row[1], row[2], row[3]);
		}
		
		sleep(3);
		fclose(fs_out);
		mysql_free_result(result);
	}

	free(sql);

	return 0;
}

int main(int argc, char** argv)
{
	MYSQL *con;

	if (argc < 3)
	{
		printf("ERROR: Parametros incorrectos!\nabm_terminal <OP> <terminal_num> <comercio_num> <lugar>\nTodo entrecomillado si lleva cero delante.\n"
			"OP= (A)lta, (B)aja, (M)odifica, (C)onsulta\n"
			"(C)onsulta parametros -> (T)erminal <numero> / (C) comercio <numero> / (A)ll \n");

		return -1;
	}
	
	if (read_config("authkig.conf") != 0)
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

	if ((argv[1][0] == 'A') || (argv[1][0] == 'a'))
	{
		if (alta_terminal(con, argv[2], argv[3], argv[4]) != 0)
		{
			fprintf(stderr, "ERROR: Al procesar ALTA!\n");
			mysql_close(con);
			return -4;
		} else {
			printf("\nSe ha procesador el ALTA correctamente!\n");
		}
	} else if ((argv[1][0] == 'B') || (argv[1][0] == 'c')) 
	{
		 if (baja_terminal(con, argv[2]) != 0)
		 {
		 	fprintf(stderr, "ERROR: Al procesar BAJA!\n");
			mysql_close(con);
			return -5;
		 } else {
		 	printf("\nSe ha procesador el BAJA correctamente!\n");
		 }
	} else if((argv[1][0] == 'C') || (argv[1][0] == 'c'))
	{
		if(argv[2][0] == 'A')
		{
			if (consulta(con, argv[2][0], NULL) != 0)
			{
				fprintf(stderr, "ERROR: Al procesar CONSULTA!\n");
				mysql_close(con);
				return -6;
			}
		} else {
			if (consulta(con, argv[2][0], argv[3]) != 0)
			{
				fprintf(stderr, "ERROR: Al procesar CONSULTA!\n");
				mysql_close(con);
				return -6;
			}
		}

	} else {
		printf("DISCULPE: FUNCION NO IMPLEMETADA!\n");
	}

	mysql_close(con);

	return 0;
}