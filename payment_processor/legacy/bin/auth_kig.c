/*
08/07/2015
Notas acerca de la version:
autor_test.c: Version inicial en desarrollo. 08/07/2015
Descripcion: Autorizador de transacciones ISO8583 TCP-IP.
cuestiones conocidas: Los campos alfanumericos iso con caracteres nulos o no imprimibles no se veran correctamente el el log.
*/

//librerias
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

/*parametros del main ./autor_test <PORT>*/ 

int main (int argc,char *argv[])
{
    pthread_t* cliThr;
    struct timeval timeout; //estructura que tiene los valores de tiempo para select
    char joker[100];
    int opt=1;
    int  iret = 0;
    int desc_srv, port_srv;
    int* desc_cli;
    int sock_cli;

    struct sockaddr_in add_srv,client;
    unsigned int size_cli;

    if(argc<2)
    {
        printf("Error: Ingreso de parametros incorrectos, uso: %s <PORT>\n");
        return -1;
    }
    printf("MARCOS TEST\n");
    if (read_config(argv[1]) != 0)
    {
        return -1;
    }

    //port_srv=atoi(argv[1]);
    port_srv = aconf->auth_port;
    desc_srv=socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    
    if( setsockopt(desc_srv, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt)) < 0 )
    {
        printf("Error configurar socket para multiples conexiones en el puerto %d\n",port_srv);
        return -1;
    }

    if(desc_srv<0)
    {
        printf("Error al abrir el socket puerto %d\n",port_srv);
        return -1;
    }

    add_srv.sin_family=AF_INET;
    add_srv.sin_port=htons(port_srv);
    add_srv.sin_addr.s_addr=INADDR_ANY;
    
    if(bind(desc_srv, (struct sockaddr *)&add_srv, sizeof(add_srv))<0)
    {
        close (desc_srv);
        printf ("Error de bind en el socket puerto %d\n",port_srv);
        return -1;
    }

    if(listen(desc_srv, CLI_MAX)<0)
    {
        close(desc_srv);
        printf("Error al escuchar en el socket puerto %d\n",port_srv);
        return -1;
    }
    
    size_cli=sizeof(client);
    printf("Aguardando conexiones en el puerto %d\n", port_srv);

    while(1)
    {
        //sock_cli = accept4(desc_srv,(struct sockaddr *)&client, &size_cli, SOCK_NONBLOCK);
        sock_cli = accept(desc_srv,(struct sockaddr *)&client, &size_cli);

        if (sock_cli < 0)
        {
            tlog("Error: Al aceptar la conexion del cliente","","");
            printf("Error: Al aceptar la conexion del cliente.\n");
            return -1;
        }

        desc_cli = (int*)malloc(sizeof(int));
        *desc_cli = sock_cli;

        printf("Assign FD = %d \n", *desc_cli);

        sprintf(joker,"Info: Cliente %d conectado ip: %s puerto: %d", *desc_cli, inet_ntoa(client.sin_addr),ntohs(client.sin_port));
        tlog(joker,"","");

        cliThr = (pthread_t*)malloc(sizeof(pthread_t));
        iret = pthread_create( cliThr, NULL, auth_thread, (void*) desc_cli);
        if(iret)
        {
            printf("ERROR: pthread_create() ret: %d\n", iret);
        } //else {
            //pthread_join( *cliThr, NULL);
        //}

        printf("On WHILE.\n");
    } // while end
}
