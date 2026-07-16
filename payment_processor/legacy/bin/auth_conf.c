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
#include <pthread.h>

#include <my_global.h>
#include <mysql.h>

#include "auth_kig.h"
#include "auth_mycli.h"

struct authCONF* aconf;

//int main(int argc, char** argv)
int read_config(char* confFL)
{
	FILE* fs = NULL;
	char* buff;
	char* ptr;
	char* arrow;
	char* sln;
	int nLive = 0;

	fs = fopen(confFL, "r");
	if (fs == NULL)
	{
		printf("Error al abrir el archivo.\n");
		return -1;
	} else {
		fseek(fs, 0L, SEEK_SET);
	}

	aconf = (struct authCONF*) malloc(sizeof(struct authCONF));
	memset(aconf, '\0', sizeof(struct authCONF));

	//printf("INIT... \n");

	buff = (char*) malloc(sizeof(char)*512);
	
	///////////////////////////////////////  PORT
	//printf("LEE PORT... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA PORT = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		////printf("LINEA PORT = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	aconf->auth_port = atoi(ptr);

	//printf("AUTHCONF->PORT = %d \n", aconf->auth_port);

	///////////////////////////////////////  LISTEN ADDRESS
	//printf("LEE LISTEN... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA LISTEN = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA LISTEN = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->auth_listen, "%s", ptr);
	//printf("AUTHCONF->LISTEN = %s \n", aconf->auth_listen);

	///////////////////////////////////////  LOG FILE
	//printf("LEE LOG... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA LOG = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA LOG = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->auth_log, "%s", ptr);
	//printf("AUTHCONF->LOG = %s \n", aconf->auth_log);

	///////////////////////////////////////  ADDRESS LIVE
	//printf("LEE ADDRESS LIVE... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA ADDRESS LIVE = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA ADDRESS LIVE = %s \n", buff);
	}

	ptr = strchr(buff, '=');
	ptr++;
	arrow = ptr;

	ptr = strchr(arrow, ';');
	if (ptr == NULL)
	{
		sln = strchr(buff, '\n');
		*sln = '\0';

		sprintf(aconf->auth_nlive[nLive], "%s", arrow);
		//printf("AUTHCONF->LIST[%d] = %s \n", nLive, aconf->auth_nlive[nLive]);

		nLive++;
	} else{
		while(ptr != NULL)
		{
			*ptr='\0';
			ptr++;
			sprintf(aconf->auth_nlive[nLive], "%s", arrow);
			//printf("AUTHCONF->LIST[%d] = %s \n", nLive, aconf->auth_nlive[nLive]);

			nLive++;
			arrow = ptr;
			ptr = strchr(arrow, ';');

			if (ptr == NULL)
			{
				if (*arrow != '\n')
				{
					sln = strchr(arrow, '\n');
					*sln = '\0';
					sprintf(aconf->auth_nlive[nLive], "%s", arrow);
					//printf("AUTHCONF->LIST[%d] = %s \n", nLive, aconf->auth_nlive[nLive]);
				}
			}
		}
	}

	///////////////////////////////////////  DB HOST
	//printf("LEE DB_HOST... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA DB_HOST = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA DB_HOST = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->dbHost, "%s", ptr);
	printf("AUTHCONF->DB_HOST = %s \n", aconf->dbHost);

	///////////////////////////////////////  DB USER
	//printf("LEE DB_USER... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA DB_USER = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA DB_USER = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->dbUser, "%s", ptr);
	//printf("AUTHCONF->DB_USER = %s \n", aconf->dbUser);

	///////////////////////////////////////  DB PASS
	//printf("LEE DB_PASS... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA DB_PASS = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA DB_PASS = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->dbPass, "%s", ptr);
	//printf("AUTHCONF->DB_PASS = %s \n", aconf->dbPass);

	///////////////////////////////////////  DB NAME
	//printf("LEE DB_NAME... \n");

	memset(buff, '\0', 512);
	fgets(buff, 512, fs);

	//printf("LINEA DB_NAME = %s \n", buff);

	while(!feof(fs))
	{
		if ((buff[0] == '\n') || (buff[0] == 0x20) || (buff[0] == '#'))
		{
			memset(buff, '\0', 512);
			fgets(buff, 512, fs);
		} else {
			break;
		}
	}

	if (feof(fs) != 0)
	{
		fclose(fs);
		return -1;
	} else {
		//printf("LINEA DB_NAME = %s \n", buff);
	}

	sln = strchr(buff, '\n');
	*sln = '\0';

	ptr = strchr(buff, '=');
	ptr++;

	sprintf(aconf->dbName, "%s", ptr);
	//printf("AUTHCONF->DB_NAME = %s \n", aconf->dbName);
	
	///////////////////////////////////////

	free(buff);

	fclose(fs);
	return 0;
}

