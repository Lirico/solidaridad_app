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

/*
    ./cierre_lote_kig <config_file> <hora>
    <hora> en formato 24 Hs
*/ 

struct authCONF* aconf;

int main (int argc,char *argv[])
{
    char bitmap_req[8];

    char prev_comer[16];
    char prev_term[9];
    char loteid[7];

    struct iso8583* iso;
    struct iso8583* iso_tmp;
    int horaRun = 0;
    int cLote = 0;
    int i = 0;

    MYSQL *con;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows = 0;

    char* sql;

    printf("Proceso de CIERRE V3.... INIT\n");

    if(argc<2)
    {
        printf("Error: Ingreso de parametros incorrectos, uso: %s <PORT>\n");
        return -1;
    }

    if (read_config(argv[1]) != 0)
    {
        return -1;
    }

    horaRun = atoi(argv[2]);

    while(1)
    {
        struct tm ts;
        time_t now;
        time (&now);

        ts=*localtime(&now);

        if (horaRun == ts.tm_hour)
        {
            printf("cierre_lote_forzado(): INIT \n");

            printf("cierre_lote_forzado() Fecha Inicio: %02d/%02d/%02d \n", ts.tm_mday, ts.tm_mon+1, ts.tm_year+1900);
            printf("cierre_lote_forzado() Hora Inicio:  %02d%02d%02d \n", ts.tm_hour, ts.tm_min, ts.tm_sec);

            iso = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
            iso_tmp = (struct iso8583*)malloc(sizeof(struct iso8583)*1);
            memset(iso, '\0', sizeof(struct iso8583));
            memset(iso_tmp, '\0', sizeof(struct iso8583));

            con = mysql_init(NULL);

            if (con == NULL)
            {
                fprintf(stderr, "%s\n", mysql_error(con));
                return -1;
            }

            if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL) 
            {
                fprintf(stderr, "%s\n", mysql_error(con));
                mysql_close(con);
                return -2;
            }

            sql = (char*)malloc(sizeof(char)*1024);
            memset(sql, '\0', 1024);

            //sprintf(sql, "SELECT DISTINCT cod_moneda, LTRIM(RTRIM(cod_comercio)), terminalid, lote FROM kigsolidario2.sgas_cup "
            //             "WHERE tipo_mensaje='0200' and procode='000000' "
            //             "GROUP BY cod_moneda, terminalid, lote");

            sprintf(sql, "SELECT DISTINCT cod_moneda, cod_comercio, terminalid, lote FROM sgas_cup "
                         "GROUP BY cod_moneda, cod_comercio, terminalid, lote");

            if (mysql_query(con, sql))
            {
                printf("cierre_lote_forzado() ERROR: exec SQL = %s\n", sql);
                free(sql);
                mysql_close(con);
                return -3;
            }

            result = mysql_store_result(con);
            if (result == NULL)
            {
                printf("cierre_lote_forzado() ERROR: store results.\n");
                free(sql);
                mysql_close(con);

                return -3;
            }

            num_rows = mysql_num_rows(result);

            memset(prev_comer, '\0', 16);
            memset(prev_term, '\0', 9);
            memset(loteid, '\0', 7);

            if (num_rows > 0)
            {
                // inicializa copia por compatibilidad.
                memcpy(iso_tmp, iso, sizeof(struct iso8583));
                memset(iso->bitmap_1, '\0', 8);

                memcpy(iso_tmp, iso, sizeof(struct iso8583));

                get_time(iso->datetrx_13, iso->timetrx_12);
                rw_bitmap(12,iso->bitmap_1,1);
                rw_bitmap(13,iso->bitmap_1,1);

                strcpy(iso->mtype, "0500");
                strcpy(iso->procode_3, "920000");

                printf("Mtype: %s\n", iso->mtype);

                strcpy(iso->systracenum_11, "015702");

                sprintf(iso->retrefnum_37,"%012u",rand()%1000000);  //RRN aleatorio entre 0 y 999999
                rw_bitmap(37,iso->bitmap_1,1);

                sprintf(iso->authid_38,"%06d",rand()%1000000); //codigo de autorizacion aleatorio entre 0 y 999999
                rw_bitmap(38,iso->bitmap_1,1);

                strcpy(iso->respcode_39,"00");
                rw_bitmap(39,iso->bitmap_1,1);

                rw_bitmap(50, iso->bitmap_1, 1);

                memset(iso->field_63, '\0', 100);  // totales simulados

                // Lleno los campos de negocio a mano
                // cod_comercio, terminalid, lote
                for (i=0; i<num_rows; i++ )
                {
                    row = mysql_fetch_row(result);

                        memset(prev_comer, '\0', 16);
                        sprintf(prev_comer, "%s", row[1]);

                        memset(iso->merchid_42, '\0', 16);

                        rw_bitmap(42,iso->bitmap_1,1);  //devuelve el mismo merchant id
                        sprintf(iso->merchid_42, "%s", row[1]);

                        printf("Comercio: %s, ", iso->merchid_42);

                        memset(prev_term, '\0', 9);
                        sprintf(prev_term, "%s", row[2]);
                        memset(iso->termid_41, '\0', 9);
                        rw_bitmap(41, iso->bitmap_1, 1);     //devuelve el mismo terminal id
                        sprintf(iso->termid_41, "%s", prev_term);

                        printf("Comercio2: %s, ", iso->merchid_42);

                        memset(iso->settcurrcode_50, '\0', 4);  // codigo de moneda
                        sprintf(iso->settcurrcode_50, "%s", row[0]);

                        printf("TermID: %s, ", iso->termid_41);
                        printf("Moneda: %s, ", iso->settcurrcode_50);

                        memset(loteid, '\0', 7);
                        sprintf(loteid, "%s", row[3]);
                        memset(iso->field_60, '\0', 100);
                        sprintf(iso->field_60, "%s", loteid);

                        printf("LoteID: %s \n\n\n", iso->field_60);

                        printf("Comercio3: %s \n ", iso->merchid_42);

                    cLote = cierre_lote(iso);

                    //printf("Comercio: %s, ", iso->merchid_42);


                    //cLote = 0;
                    if (cLote < 0)
                    {
                        strcpy(iso->respcode_39,"19"); // error en DB, WRITE_ERROR
                    } else if(cLote > 0) {
                        strcpy(iso->respcode_39,"95"); // error en DB, WRITE_ERROR
                    } else {
                        strcpy(iso->respcode_39,"00");  //transaccion aprobada
                    }

                }
            } else {
                printf("No hay lotes que cerrar. \n");
            }

            // libero iso
            free(iso_tmp);
            free(iso);
            free(sql);
            mysql_close(con);

            system("./avisos.php");
            break;
        } else {
            sleep(60);
        }
    } // while end

    system("./acumulator_kig ../authkig.conf >acumulator_kig.log");

    return 0;
}
