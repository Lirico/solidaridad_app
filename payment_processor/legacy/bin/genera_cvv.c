/*
Genera CVV

*/
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

char* genera_cvv(int ndoc)
{
	char* ret;
        char* lelong;
	int rnd;
        int stLen;
        int seed=ndoc;

	ret = (char*)malloc(sizeof(char)*4);
	memset(ret, '\0', 4);

        lelong = (char*)malloc(sizeof(char)*16);
        memset(lelong, '\0', 16);
	
	//srand(time(NULL));
	//rnd = rand() % 20;
        rnd = rand_r(&seed);
	
	printf("RAND = %d\n", rnd);
        printf("RAND 3 = %03d\n", rnd);

        sprintf(lelong, "%d", rnd);

	//sprintf(ret, "%03d", rnd);
        stLen = strlen(lelong);

        ret[0] = lelong[stLen-1];
        ret[1] = lelong[stLen-2];
        ret[2] = lelong[stLen-3];

	return ret;
}

int write_cvv(MYSQL *con, char* cvv, char* ndoc)
{
	int ret = 0;
	char* sql;
	int num_rows;

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

	sprintf(sql, "UPDATE sgas_usuario SET cvv_actual='%s', cvv_renovacion='%s' WHERE nro_doc='%s' ", cvv, cvv, ndoc);

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

int main()
{
	int ret=0;
	int i;
	char* elrand;
	MYSQL *con;
	char* sql;
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;

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

	sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    sprintf(sql, "SELECT nro_tarjeta, nro_doc FROM sgas_usuario ");

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
		for(i=0; i<num_rows; i++)
		{
			row = mysql_fetch_row(result);

			elrand = genera_cvv(atoi(row[1]));

			printf("TARJETA: %s, DOC: %s, RANDOM: %s\n", row[0], row[1], elrand );

			write_cvv(con, elrand, row[1]);
		}
	}


	free(sql);
	mysql_free_result(result);

	return ret;
}

