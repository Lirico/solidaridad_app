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

#define TIMEOUT_SOCKET 30 //tiempo máximo de espera para la conexion o respuesta del validador [s]

/*
Nombre: sckt
Descripción: Crea y abre el socket contra el validador para procesar la transacción.
Parametros: Se le pasan los punteros a las cadenas que contiene la dirección IP, el puerto, la longitud y el mensaje a enviar, y el mensaje a devolver.
Devolución: Devuelve un entero con la longitud del mensaje recibido, la cadena de respuesta, ó -1 en caso de error.
*/
int sckt(char *host, char *port, int l, char *req, char *resp)
{
    struct timeval timeout;
    int desc_sckt,so_error,n;
    socklen_t len = sizeof so_error;
    struct sockaddr_in dir_sckt;//estructura que ontendrá la dirección del para habrir el socket
    struct hostent *Host;//estructura que contendrá la dirección del host
    char *dir_host = NULL;

    timeout.tv_sec=TIMEOUT_SOCKET;//se guarda la cte de timeout en unidades de seg definida al comienzo
    fd_set sckts_lectura;//usamos otro descriptor porque no funciona FD_CLR para sacar en descriptor del socket cusndo sale de validar
    FD_ZERO(&sckts_lectura);
    Host=gethostbyname(host);//traduce el nombre de dominio y carga la estructura hostend (Host) con la informacion del host (h_addr tiene la ip en network byte order)
    
    dir_sckt.sin_family=AF_INET;
    dir_sckt.sin_port=htons(atoi(port));
    dir_sckt.sin_addr.s_addr=((struct in_addr*)(Host->h_addr))->s_addr;
    
    //dir_host=(char *)inet_ntoa(dir_sckt.sin_addr.s_addr);

    
    desc_sckt=socket(AF_INET, SOCK_STREAM, 0);
    if(desc_sckt==-1)
    {
        tlog("Error: no se pudo abrir el socket con el host",dir_host,port);
        return -1;
    }
    if(fcntl(desc_sckt,F_SETFL,O_NONBLOCK)==-1)//connect no bloqueante
    {
        tlog("Error: no se pudo configuar el socket con el host",dir_host,port);
        return -1;
    }
    if(connect(desc_sckt,(struct sockaddr *)&dir_sckt,sizeof(dir_sckt))==-1) if (errno != EINPROGRESS)
    {
        tlog("Error: no se pudo intentar conectar con el host",dir_host,port);
        return -1;
    }
    FD_SET(desc_sckt,&sckts_lectura);//cargamos el descriptor del socket en los descriptores de lectura para la funcion select
    if (select(desc_sckt+1,NULL,&sckts_lectura,NULL,&timeout)==-1)
    {
        tlog("Error: no se pudo seleccionar la conexion con el host",dir_host,port);
        return -1;
    }

    if(getsockopt(desc_sckt,SOL_SOCKET,SO_ERROR,&so_error,&len)==-1)
    {
        tlog("Error: no se pudo obtener opciones de la conexion con el host",dir_host,port);
        return -1;
    }
    if (so_error != 0)
    {
        tlog("Error: no se pudo conectar con el host",dir_host,port);
        return -1;
    }
    n=write(desc_sckt,req,l);
    if(n==0)
    {
        tlog("Error: el host remoto cerró el socket",dir_host,port);
        close(desc_sckt);
        return -1;
    }
    if(n==-1)
    {
        switch(errno)
        {
            case EINTR:
            case EAGAIN:
                usleep(100);
                break;
            default:
                tlog("Error: no se pudo enviar los datos al host",dir_host,port);
                return -1;
        }
    }
    do
    {
        //select devuelve la cantidad de sockets que tienen actividad, 0 timeout, o -1 error
        if(select(desc_sckt+1,&sckts_lectura,0,0,&timeout)<=0)//expiro el tiempo de respuesta o error
        {
            tlog("Error: tiempo máximo sin respuesta del host",dir_host,port);
            close(desc_sckt);
            return -1;
        }
    }
    while(FD_ISSET(desc_sckt,&sckts_lectura)==0);//pregunta si paso algo en ese socket, si salio de select por otro retorna
    n=read(desc_sckt,resp,512);//acorde al tamaño máximo del buffer
    if(n==0)
    {
        tlog("Error: el host remoto cerró el socket",dir_host,port);
        close(desc_sckt);
        return -1;
    }

    if(n==-1)
    {
        switch(errno)
        {
            case EINTR:
            case EAGAIN:
                usleep(100);
                break;
            default:
                tlog("Error: al recibir los datos del host",dir_host,port);
                return -1;
        }
    }
    
    close(desc_sckt);
    resp[n+1]='\0';

    sleep(10);
    return n;
}

void* cliISOThr(void* data)
{
    int desc_srv,port_srv,n_rx,n_tx,ll_rx,ll_tx,offset,i,fdmax,cli,opt=1;
    char req[BUF_SIZE],req_buf[BUF_SIZE],res[BUF_SIZE],joker[100],bitmap_req[8];

    struct iso8583* iso;
    struct iso8583* iso_tmp;

    iso = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
    memset(iso, '\0', sizeof(struct iso8583));

    iso_tmp = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
    memset(iso_tmp, '\0', sizeof(struct iso8583));

    sprintf(iso->tpdu, "6000040000");

    sprintf(iso->mtype, "0800");
    
    rw_bitmap(3,iso->bitmap_1,1);
    sprintf(iso->procode_3, "910000");

    get_time(iso->datetrx_13, iso->timetrx_12);
    rw_bitmap(12,iso->bitmap_1,1);
    rw_bitmap(13,iso->bitmap_1,1);

    rw_bitmap(24,iso->bitmap_1,1);
    sprintf(iso->nii_24, "0004");

    rw_bitmap(41,iso->bitmap_1,1);
    sprintf(iso->termid_41, "00000112");

    rw_bitmap(45,iso->bitmap_1,1);
    sprintf(iso->merchid_42, "012500");

    ll_tx=packunpack_iso(res, iso, 0, DEBUG_ISO);//empaqueta el mensaje

    int rst = sckt("127.0.0.1", "4453", ll_tx, res, req);
    if (rst == -1)
    {
        printf("ERROR: %d \n", rst);
        return NULL;
    } else {
        ll_rx=packunpack_iso(res, iso_tmp, 1, DEBUG_ISO); //desempaqueta el mensaje
    }

    return NULL;
}

int main(int argc, char** argv)
{
    pthread_t* cliThr;
    int iret = 0;
    int i=0;

    for (i=0; i<1; i++)
    {
        cliThr = (pthread_t*)malloc(sizeof(pthread_t));

        iret = pthread_create( cliThr, NULL, cliISOThr, (void*) NULL);
        if(iret)
        {
            fprintf(stderr,"ERROR: pthread_create() ret: %d\n", iret);
        } //else {
            //pthread_join( *cliThr, NULL);
        //}
    }

    return 0;
}