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

struct CGR{
	char    dni[12];
	int     prod_id;
	double  cantidad;
	char    fecha[12];
	char    t_op;
	int idx;
};

typedef struct CGR CARGA;

CARGA load[50000];

int read_carga(char* cgFile)
{
	FILE* fs = NULL;
	char* buff;
	char* ptr;
	char* arrow;
	char* sln;
	int nLive = 0;
	int i=0;

	char* ges;

	fs = fopen(cgFile, "r");
	if (fs == NULL)
	{
		printf("Error al abrir el archivo.\n");
		return -1;
	} else {
		fseek(fs, 0L, SEEK_SET);
	}

	printf("read_carga() - INIT  \n");

	buff = (char*) malloc(sizeof(char)*512);

	while(!feof(fs))
	{
		//printf("LEE LINEA... %d\n", i);

		memset(buff, '\0', 512);
		ges = fgets(buff, 512, fs);

		if (ges == NULL)
		{
			printf("saliendo de read_carga()\n");
			break;
		}

		//printf("LINEA = %s \n", buff);

		sln = strchr(buff, '\n');
		*sln = '\0';

		//printf("LINEA LIMPIA = %s \n", buff);

		arrow=buff;
		ptr = strchr(buff, ';');
		*ptr='\0';

		//printf("BUFF = %s \n", arrow);
		memset(load[i].dni, '\0', 12);
		sprintf(load[i].dni, "%s", arrow);
		//printf("LOAD = %s \n", load[i].dni);

		ptr++;
		arrow=ptr;
		ptr = strchr(arrow, ';');
		*ptr='\0';

		//printf("BUFF = %s \n", arrow);
		load[i].prod_id = atoi(arrow);
		//printf("LOAD = %d \n", load[i].prod_id);

		ptr++;
		arrow=ptr;
		ptr = strchr(arrow, ';');
		*ptr='\0';

		//printf("BUFF = %s \n", arrow);
		load[i].cantidad = atof(arrow);
		//printf("LOAD = %f \n", load[i].cantidad);

		ptr++;
		arrow=ptr;
		ptr = strchr(arrow, ';');
		*ptr='\0';

		//printf("BUFF = %s \n", arrow);
		memset(load[i].fecha, '\0', 12);
		sprintf(load[i].fecha, "%s", arrow);
		//printf("LOAD = %s \n", load[i].fecha);

		ptr++;
		arrow = ptr;

		//printf("BUFF = %c \n", arrow[0]);
		load[i].t_op = arrow[0];
		//printf("LOAD = %c \n", load[i].t_op);

		i++;
	}

	load[0].idx = i;

	free(buff);
	fclose(fs);
	return 0;
}

int getMonedaByProdCod(MYSQL *con, int prid)
{
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
	int cod_moneda = 0;
	char* sql;

	printf(" getMonedaByProdCod() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT cod_moneda FROM sgas_productos WHERE id_normal='%d'", prid);

	printf("getMonedaByProdCod() - SQL %s\n", sql);

	if (mysql_query(con, sql)) 
	{
		printf("getMonedaByProdCod() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("getMonedaByProdCod() ERROR: store results. \n");
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		row = mysql_fetch_row(result);
		cod_moneda = atoi(row[0]);

		mysql_free_result(result);
		printf("getMonedaByProdCod() RET: cod_moneda = %d\n", cod_moneda);
	}

	free(sql);
	return cod_moneda;
}

int getCardByNroDoc(MYSQL *con, char* nro_doc, char* nro_tarjeta)
{
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
	char* sql;

	printf("getCardByNroDoc() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	//sprintf(sql, "SELECT nro_tarjeta FROM sgas_usuario WHERE nro_doc='%d' and situacion='V' and marca_baja=0", atoi(nro_doc));
        sprintf(sql, "SELECT nro_tarjeta FROM sgas_usuario WHERE nro_doc='%d' and (situacion='V' or situacion='S') ", atoi(nro_doc));

	printf("getCardByNroDoc() - SQL %s\n", sql);

	if (mysql_query(con, sql)) 
	{
		printf("getCardByNroDoc() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("getCardByNroDoc() ERROR: store results. \n");
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		row = mysql_fetch_row(result);
		sprintf(nro_tarjeta, "%s", row[0]);

		mysql_free_result(result);

		printf("getCardByNroDoc() RET: nro_tarjeta = %s\n", nro_tarjeta);
	} else {
		printf("getCardByNroDoc() RET: nro_tarjeta = NULL\n");
	}

	free(sql);
	return 0;
}

int calcTermId(int cod_moneda, char* terminalid)
{
	switch(cod_moneda)
	{
		case 993:
					sprintf(terminalid, "05000002");
					break;
		case 994:
					sprintf(terminalid, "06000002");
					break;
		case 995:
					sprintf(terminalid, "07000002");
					break;
		case 996:
					sprintf(terminalid, "08000002");
					break;
		case 997:
					sprintf(terminalid, "09000002");
					break;
	}

	return 0;
}

int reservaLotes(MYSQL *con, int cod_moneda)
{
	int ret=0;
	MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    int lote = -1;
    char* sql;

    char num_card[60];
    char terminalid[16];

    printf("reservaLotes() - INIT \n");

	sql = (char*)malloc(sizeof(char)*1024);
	memset(sql, '\0', 1024);

	sprintf(sql, "SELECT if(MAX(lote), MAX(lote), 0) FROM sgas_cup WHERE cod_moneda='%d'", cod_moneda);

	printf("reservaLotes() - SQL %s\n", sql);

	if (mysql_query(con, sql)) 
	{
		printf("reservaLotes() ERROR: exec SQL.\n");
		free(sql);
		return -3;
	}

	result = mysql_store_result(con);
	if (result == NULL)
	{
		printf("reservaLotes() ERROR: store results. \n");
		free(sql);
		return -3;
	}

	num_rows = mysql_num_rows(result);
	if (num_rows > 0)
	{
		printf("reservaLotes() NUM_ROWS = %d \n", num_rows);

		row = mysql_fetch_row(result);
		lote = atoi(row[0]);
		lote++;
		mysql_free_result(result);
	} else {
		printf("reservaLotes() NUM_ROWS = %d \n", num_rows);
		lote = 0;
	}

	memset(sql, '\0', 1024);
	memset(terminalid, '\0', 16);
	memset(num_card, '\0', 60);

	calcTermId(cod_moneda, terminalid);
	getCardByNroDoc(con, "30777666", num_card);

	sprintf(sql, "INSERT INTO sgas_cup (cod_comercio,cod_moneda, terminal_time, terminal_date, cant_cuotas, importe, codigo_autorizacion, "
			    "id_operacion, procode, terminalid, lote,numero_comprobante, anula_comprobante, tipo_mensaje, nro_tarjeta) "
                "VALUES ('012502', '%d', CURRENT_TIME(), CURRENT_DATE(), 1, 0.00, '338460', 0, '000000', '%s', "
                "%d, 0, -1, '0400', '%s')",
                cod_moneda, terminalid, lote, num_card);

	printf("reservaLotes() SQL ins = %s \n", sql);

	if (mysql_query(con, sql))
	{
		fprintf(stderr, "%s\n", mysql_error(con));
		return -3;
	}

	printf("reservaLotes() RET = %d \n", lote);

	return lote;
}

int main(int argc, char** argv)
{
    int ret = 0;
    MYSQL *con;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;
    int cod_moneda;
    char authid[60];
    char* sql;
    int i = 0;
    char terminalid[16];
    int id_op ;
    int loteid[1000];
    char num_card[60];
    char procode[16];
    double prod_amount, importe;
    int ret_gc;

    char cod_str_moneda[4];

    if(argc<2)
    {
        printf("Error: Ingreso de parametros incorrectos, uso: %s <conf_file> <carga_file>\n");
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

    read_carga(argv[2]);

    sql = (char*)malloc(sizeof(char)*1024);

	loteid[993] = reservaLotes(con, 993);
	loteid[994] = reservaLotes(con, 994);
	loteid[995] = reservaLotes(con, 995);
	loteid[996] = reservaLotes(con, 996);
	loteid[997] = reservaLotes(con, 997);

	for (i=0; i<load[0].idx; i++)
	{
		memset(sql, '\0', 1024);
		memset(authid, '\0', 60);
		memset(terminalid, '\0', 16);
		memset(procode, '\0', 16);
		memset(num_card, '\0', 60);
		memset(cod_str_moneda, '\0',4);

		printf("On while() 1 \n");

		sprintf(authid,"%06d",rand()%1000000);

		printf("On while() 2 \n");

		cod_moneda = getMonedaByProdCod(con, load[i].prod_id);

		printf("On while() 3 \n");

		calcTermId(cod_moneda, terminalid);

		printf("On while() 4 \n");

		id_op = i+1;

		ret_gc = getCardByNroDoc(con, load[i].dni, num_card);

		if (ret_gc < 0)
		{
			printf("main() - ERROR: DNI %s inexistente o en estado de baja.\n", load[i].dni);
		} else {

			printf("On while() 5 \n");

			sprintf(cod_str_moneda, "%d", cod_moneda);

			printf("On while() 6 \n");

			prod_amount = getProdAmount(con, cod_str_moneda);
			importe = (load[i].cantidad / prod_amount)*-1;

			printf("On while() 7 \n");

			if (importe > 0)
			{
				sprintf(procode, "000000");
			} else {
				sprintf(procode, "200000");
			}

			sprintf(sql, "INSERT INTO sgas_cup (cod_comercio,cod_moneda, terminal_time, terminal_date, cant_cuotas, importe, codigo_autorizacion, "
			    "id_operacion, procode, terminalid, lote,numero_comprobante, anula_comprobante, tipo_mensaje, nro_tarjeta) "
                "VALUES ('012502', '%d', CURRENT_TIME(), CURRENT_DATE(), 1, %f, '%s', %d, '%s', '%s', "
                "%d, %d, -1, '0200', '%s')",
                cod_moneda, importe, authid, id_op, procode, terminalid, loteid[cod_moneda], id_op, num_card);

			printf("main() - SQL: %s\n", sql);
		}


		if (mysql_query(con, sql))
		{
			fprintf(stderr, "%s\n", mysql_error(con));
			return -3;
		}
	}

	mysql_close(con);
	return ret;
}
