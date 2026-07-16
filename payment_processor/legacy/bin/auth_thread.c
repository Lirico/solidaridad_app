// auth thread
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

void* auth_thread(void* data)
{
	int* sdp = (int*)data;
	int sd = *sdp;

	int desc_srv,port_srv,n_rx,n_tx,ll_rx,ll_tx,offset,i,fdmax,cli,opt=1;
	char req[BUF_SIZE],req_buf[BUF_SIZE],res[BUF_SIZE],joker[100],bitmap_req[8];

	int val_op = 0;
	int cLote = 0;
	int ret_vop = 0;
    int anul_cup = 0;
    int vta = 0;
    int cons_sal = 0;

    int val_term = 0;

	struct iso8583* iso;
    struct iso8583* iso_tmp;

    fd_set rfds;
    struct timeval tv;
    int retval, len;

    struct tm ts;
    time_t now;

    /*
    FD_ZERO(&rfds);
    FD_SET(0, &rfds);

    tv.tv_sec = 20;
    tv.tv_usec = 0;

    retval = select(sd +1, &rfds, NULL, NULL, &tv);
    if (retval == -1){
        perror("select()");
        return NULL;
    } else {
        n_rx=read(sd, req_buf, BUF_SIZE); //lee del socket del cliente
    }

    //si read devuelve un cero es que se ha cerrado el socket
    if(n_rx==0)
    {
        tlog("Info: El cliente cerro la conexion","","");
        close(sd);
        return NULL;
    }

    if(n_rx < 6)
    {
        tlog("Info: El cliente cerro la conexion","","");
        close(sd);
        return NULL;
    }

    if(n_rx<0)
    {
        switch(errno)
        {
            case EINTR:
            case EAGAIN:
                    usleep (100);
                    break;
            default:
                    tlog("Error: De lectura en el socket del cliente","","");
                    close(sd);
                    return NULL;
        }
    }
    */

    /*
    memset(joker, '\0', 100);

    printf("Info: Mensaje recibido del cliente longitud %d\n", n_rx);

    sprintf(joker,"%d",n_rx);
    sprintf(joker,"Info: Mensaje recibido del cliente longitud %d", n_rx);
    tlog(joker,"","");
    offset=0;
    */

    do {
        //----------------------------------------------------------------------------------
        FD_ZERO(&rfds);
        FD_SET(sd, &rfds);

        tv.tv_sec = 1;
        tv.tv_usec = 0;

        retval = select(sd +1, &rfds, NULL, NULL, &tv);
        if (retval == -1)
        {
            perror("select()");
            return NULL;
        } else {
            n_rx=read(sd, req_buf, BUF_SIZE); //lee del socket del cliente
        }

        if(n_rx==0)
        {
            tlog("Info: El cliente cerro la conexion -> n_rx = 0","","");
            close(sd);
            return NULL;
        }

        if(n_rx < 6)
        {
            tlog("Info: El cliente cerro la conexion -> n_rx < 6","","");
            close(sd);
            return NULL;
        }

        if(n_rx<0)
        {
            switch(errno)
            {
                case EINTR:
                case EAGAIN:
                        usleep (100);
                        break;
                default:
                        tlog("Error: De lectura en el socket del cliente","","");
                        close(sd);
                        return NULL;
            }
        }

        memset(joker, '\0', 100);

        printf("Info: Mensaje recibido del cliente longitud %d\n", n_rx);

        sprintf(joker,"%d",n_rx);
        sprintf(joker,"Info: Mensaje recibido del cliente longitud %d", n_rx);
        tlog(joker,"","");
        offset=0;

        //----------------------------------------------------------------------------------

        printf("Info: antes de longitude_to_int() \n");

        ll_rx=longitude_to_int('h',req_buf[offset],req_buf[offset+1]);
        if(ll_rx>BUF_SIZE)
        {
            sprintf(joker,"Error: El mensaje del cliente %d de longitud %d excede la longitud maxmima admitida",cli,n_rx);
            tlog(joker,"","");
            close(sd);
            return NULL;
        }

        printf("Info: despues de longitude_to_int() \n");

        for(i=offset;i<ll_rx+offset+2;i++) req[i-offset]=req_buf[i];
        offset=offset+ll_rx+2;

        printf("Info: antes de malloc( iso ) \n");

        iso = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
        iso_tmp = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
        memset(iso, '\0', sizeof(struct iso8583));
        memset(iso_tmp, '\0', sizeof(struct iso8583));

        printf("Info: despues de malloc( iso ) \n");

        printf("Info: antes de packunpack_iso() \n");

        if(packunpack_iso(req, iso, 1, DEBUG_ISO) < 0)//desempaqueta el requerimiento
        {
            tlog("Error: desempaquetando respuesta","","");
            free(iso);
            free(iso_tmp);
            close(sd);
            return NULL;
        }

        printf("Info: despues de packunpack_iso() \n");

        for(i=0;i<8;i++) bitmap_req[i]=iso->bitmap_1[i];   //guarda bitmap original

        /***************** proceso de validacion ******************/
        if(!rw_bitmap(3,iso->bitmap_1,0)||!rw_bitmap(24,iso->bitmap_1,0)||!rw_bitmap(41,iso->bitmap_1,0))
        {
            memset(iso->bitmap_1, '\0', 8);
            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);
            strcpy(iso->respcode_39,"99");
            rw_bitmap(39,iso->bitmap_1,1);
        }

        memcpy(iso_tmp, iso, sizeof(struct iso8583));
        printf("Mtype: %s\n", iso->mtype);

        val_term = valida_terminal(NULL, iso);

        // ingenico patch
        if (iso->flag_ingenico == 1)
        {
            get_time(iso->datetrx_13, iso->timetrx_12);
            rw_bitmap(12,iso->bitmap_1,1);
            rw_bitmap(13,iso->bitmap_1,1);
        }

        if(strcmp(iso->mtype,"0300") == 0)   // DENUNCIA DE ROBO
        {
						guardar_iso(NULL, iso, 1);

            memset(iso->bitmap_1, '\0', 8);

            if(rw_bitmap(11, bitmap_req, 0))
            {
                rw_bitmap(11, iso->bitmap_1, 1);
            }

            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);

            sprintf(iso->authid_38,"%06d",rand()%1000000);
            rw_bitmap(38,iso->bitmap_1,1);

            rw_bitmap(39,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if (atoi(iso->procode_3) == 30000)
            {
                if (denuncia_perdida(iso) != 0)
                {
                    strcpy(iso->respcode_39,"14");
                } else {
                    strcpy(iso->respcode_39,"00");
                }
            }

						guardar_iso(NULL, iso, 1);
        }

        if(strcmp(iso->mtype,"0500") == 0)   // CIERRE DE LOTE
        {
					 	guardar_iso(NULL, iso, 1);

            memset(iso->bitmap_1, '\0', 8);

            get_time(iso->datetrx_13, iso->timetrx_12);
            rw_bitmap(12,iso->bitmap_1,1);
            rw_bitmap(13,iso->bitmap_1,1);

            if(rw_bitmap(11,bitmap_req,0))
            {
                rw_bitmap(11,iso->bitmap_1,1);
            }

            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if(rw_bitmap(42,bitmap_req,0))
            {
                rw_bitmap(42,iso->bitmap_1,1);
            }

            rw_bitmap(50, iso->bitmap_1, 1);
            rw_bitmap(39,iso->bitmap_1,1);

            rw_bitmap(3, iso->bitmap_1, 1);
            rw_bitmap(24, iso->bitmap_1, 1);

            if (atoi(iso->procode_3) == 920000)
            {
                cLote = cierre_lote(iso);
                if (cLote < 0)
                {
                    if (iso->flag_ingenico == 1)
                    {
                        strcpy(iso->respcode_39,"00");
                    } else {
                        strcpy(iso->respcode_39,"19");
                    }
                } else if(cLote > 0) {
                    if (iso->flag_ingenico == 1)
                    {
                        //strcpy(iso->respcode_39,"00"); // error en DB, DIFF
                    } else{
                        //strcpy(iso->respcode_39,"95"); // error en DB, DIFF
                    }

                    strcpy(iso->respcode_39,"00");
                } else {
                    sprintf(iso->authid_38, "%06d", rand()%1000000);
                    rw_bitmap(38, iso->bitmap_1, 1);
                    strcpy(iso->respcode_39,"00");
                }
            }

						guardar_iso(NULL, iso, 1);
        }

        if (strcmp(iso->mtype,"0400") == 0)  // REVERSO
        {
						guardar_iso(NULL, iso, 1);

            printf("auth_thread() Reverso INIT.\n");

            memset(iso->bitmap_1, '\0', 8);

            rw_bitmap(39,iso->bitmap_1,1);

            rw_bitmap(3, iso->bitmap_1, 1);

            if(rw_bitmap(11,bitmap_req,0))
            {
                rw_bitmap(11,iso->bitmap_1,1);
            }

            rw_bitmap(24,iso->bitmap_1,1);

            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);

            sprintf(iso->authid_38,"%06d",rand()%1000000);
            rw_bitmap(38,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if(rw_bitmap(42,bitmap_req,0))
            {
                rw_bitmap(42,iso->bitmap_1,1);
            }

            if(!rw_bitmap(22, bitmap_req,0))
            {
                printf("auth_thread() Comprobando campo 22.\n");
                strcpy(iso->respcode_39,"19");
            } else {

                ret_vop = valida_operacion(iso, bitmap_req);
                if ( (ret_vop == CUP_DUP) || (ret_vop == TRANS_OK) )
                {
                    if(ret_vop == CUP_DUP)
                    {
                        printf("auth_thread() ret_vop = CUP_DUP.\n");
                    }

                    if (ret_vop == TRANS_OK)
                    {
                        printf("auth_thread() ret_vop = TRANS_OK.\n");
                    }

                    if (reverso(iso) != 0)
                    {
                        sprintf(iso->respcode_39, "%02u", ret_vop);
                        // cambio cuando responde diferente de 0
                        //close(sd);
                        //break;
                    } else {
                        strcpy(iso->respcode_39,"00");
                    }
                } else {
                    sprintf(iso->respcode_39, "%02u", ret_vop);
                    // cambio cuando responde diferente de 0
                    //close(sd);
                    //break;
                }
            }

						guardar_iso(NULL, iso, 1);
        }

        if(strcmp(iso->mtype,"0200") == 0)   // VENTA, ANULACION, DEVOLUCION
        {
						guardar_iso(NULL, iso, 1);

            memset(iso->bitmap_1, '\0', 8);

            rw_bitmap(39,iso->bitmap_1,1);

            rw_bitmap(3, iso->bitmap_1, 1);

            if(rw_bitmap(11,bitmap_req,0))
            {
                rw_bitmap(11,iso->bitmap_1,1);
            }

            rw_bitmap(24,iso->bitmap_1,1);

            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);

            sprintf(iso->authid_38,"%06d",rand()%1000000);
            rw_bitmap(38,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if(rw_bitmap(42,bitmap_req,0))
            {
                rw_bitmap(42,iso->bitmap_1,1);
            }

            time_t ltime;
            struct tm *stm;
            time( &ltime );
            stm = localtime( &ltime );

            if (stm->tm_hour == 23)
            {
                if (stm->tm_min < 30)
                {
                   printf("HORARIO DE ATENCION <23 && >00 : %d\n", stm->tm_hour);
                   sleep(5);
                   strcpy(iso->respcode_39,"05");
								}
            } else {
                if ((atoi(iso->procode_3) == 20000) || (atoi(iso->procode_3) == 50000)) // ANULACION
                {
                    anul_cup = anula_cupon(iso, iso_tmp);
                    if ( anul_cup < 0)
                    {
                        strcpy(iso->respcode_39,"76");
                    } else if ( anul_cup <= -1000) {
                        memset(iso->respcode_39, '\0', 3);
                        strcpy(iso->respcode_39,"19");
                    } else {
                        strcpy(iso->respcode_39,"00");
                    }
                } else{
                    val_op = valida_operacion(iso, bitmap_req);

                    if (val_op == TRANS_OK)   // DEVOLUCION
                    {
                        if (atoi(iso->procode_3) == 200000)
                        {
                            int devol_op = devolucion(iso);

                            if (devol_op < 0)
                            {
                                strcpy(iso->respcode_39,"19");
                            } else if(devol_op > 0){
                                sprintf(iso->respcode_39, "%02u", devol_op);
                            } else {
                                strcpy(iso->respcode_39,"00");
                            }
                        } else {
                            vta = venta_cupon(iso);
                            if (vta < 0)
                            {
                                sprintf(iso->respcode_39, "%02u", vta);
                            } else if (vta == 0){
                                strcpy(iso->respcode_39,"00");
                            } else {
                                sprintf(iso->respcode_39, "%02u", vta);
                            }
                        }
                    } else {
                        if (val_op == CUP_DUP)
                        {
                            strcpy(iso->respcode_39,"17");
                        } else{
                            sprintf(iso->respcode_39, "%02u", val_op);
                        }
                    }
                } // main IF
            } // checkea horario

						guardar_iso(NULL, iso, 1);
        }

        if(strcmp(iso->mtype, "0100") == 0)  // CONSULTA DE SALDO
        {
						guardar_iso(NULL, iso, 1);

            memset(iso->bitmap_1, '\0', 8);
            rw_bitmap(3, iso->bitmap_1, 1);

            rw_bitmap(39,iso->bitmap_1,1);

            if (val_term == 0)
            {
                cons_sal = consulta_saldo(iso);
            } else {
                memset(iso->amount_4, '\0', 13);
                sprintf(iso->amount_4, "%012u", 0);

                cons_sal = val_term;
            }

            if(cons_sal > 0)
            {
                if (cons_sal == HAVENO_LIMIT_EXCD)
                {
                    strcpy(iso->respcode_39,"61");
                } else {
                    sprintf(iso->respcode_39, "%02d", cons_sal);
                }
            } else if(cons_sal < 0) {
                strcpy(iso->respcode_39,"19");
            } else {
                strcpy(iso->respcode_39,"00");
            }

            rw_bitmap(4,iso->bitmap_1,1);

            if(rw_bitmap(11,bitmap_req,0))
            {
                rw_bitmap(11,iso->bitmap_1,1);
            }

            rw_bitmap(24,iso->bitmap_1,1);

            sprintf(iso->retrefnum_37,"%012u",rand()%1000000);
            rw_bitmap(37,iso->bitmap_1,1);

            sprintf(iso->authid_38,"%06d",rand()%1000000);
            rw_bitmap(38,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if(rw_bitmap(42,bitmap_req,0))
            {
                rw_bitmap(42,iso->bitmap_1,1);
            }

            if(rw_bitmap(49,bitmap_req,0))
            {
                rw_bitmap(49,iso->bitmap_1,1);
            }

						guardar_iso(NULL, iso, 1);
        }

        if(strcmp(iso->mtype, "0800") == 0)
        {
						guardar_iso(NULL, iso, 1);

            memset(iso->bitmap_1, '\0', 8);

            rw_bitmap(3, iso->bitmap_1, 1);

            if(rw_bitmap(11,bitmap_req,0))
            {
                rw_bitmap(11,iso->bitmap_1,1);
            }

            rw_bitmap(24,iso->bitmap_1,1);

            sprintf(iso->amount_4,"%012u",12340);
            rw_bitmap(4,iso->bitmap_1,1);

            rw_bitmap(41,iso->bitmap_1,1);

            if(rw_bitmap(42,bitmap_req,0))
            {
                rw_bitmap(42,iso->bitmap_1,1);
            }

            if(rw_bitmap(49,bitmap_req,0))
            {
                rw_bitmap(49,iso->bitmap_1,1);
            }

						guardar_iso(NULL, iso, 1);
        }

        //swap nii origen y destino del tpdu
        strcpy(joker,iso->tpdu);

        for(i=6;i<10;i++)
        {
            iso->tpdu[i-4]=joker[i];
        }

        for(i=2;i<6;i++)
        {
            iso->tpdu[i+4]=joker[i];
        }

        //suma 10 al message type
        sprintf(joker,"%04d",atoi(iso->mtype)+10);
        strcpy(iso->mtype,joker);
        rw_bitmap(11,iso->bitmap_1,0);

        //fecha y hora en la respuesta
        get_time(iso->datetrx_13,iso->timetrx_12);
        rw_bitmap(12,iso->bitmap_1,1);
        rw_bitmap(13,iso->bitmap_1,1);

        // 59 de fecha
        time (&now);
        ts=*localtime(&now);
        rw_bitmap(59, iso->bitmap_1, 1);
        memset(iso->field_59, '\0', 100);
        sprintf(iso->field_59, "%02d%02d%02d%02d%02d%02d",
        ts.tm_mday, (ts.tm_mon+1), (ts.tm_year-100), ts.tm_hour, ts.tm_min, ts.tm_sec );

        // escribo log de TR.
        if(strcmp(iso->mtype, "0800") != 0)
        {
            if(strcmp(iso->respcode_39, "00") != 0)
            {
                //
            }
        }

        ll_tx=packunpack_iso(res, iso, 0, DEBUG_ISO);
        n_tx=write(sd,res,ll_tx);

        // libero iso
        free(iso_tmp);
        free(iso);

        //si write devuelve un cero es que se ha  cerrado el socket
        if(n_tx==0)
        {
            tlog("El cliente cerro la conexion","","");
            close(sd);
            printf("FREE: FD = %d", sd);
        }

        if(n_tx<0)
        {
            switch(errno)
            {
                case EINTR:
                case EAGAIN:
                        usleep (100);
                        break;
                default:
                        tlog("Error de escritura en el socket del cliente","","");
                        close(sd);
                        printf("FREE: FD = %d", sd);
            }
        }

        offset=0;

    } while(offset < n_rx);

    printf("Saliendo del Hilo...\n");

    close(sd);
    return NULL;
}
