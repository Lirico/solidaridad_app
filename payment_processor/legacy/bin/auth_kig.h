#ifndef _AUTH_KIG_H_
#define _AUTH_KIG_H_

//constantes
#define ARCHIVO_LOGS "./authkig.log"
#define BUF_SIZE 2048 //tamaño de buffer para los sockets en ambos sentidos
#define DEBUG_ISO 1 //mayor a 0 depura mensajes iso en el log
#define CLI_MAX 100 //maxima cantidad de clientes

#define VALIDA_INT_OK 1

// codigos de retorno
#define TRANS_OK 0
#define COMER_DES_SUP 3
#define TIT_BOLETIN 4
#define TRANS_DENY 5
#define TRASN_TYPE_UNK 6
#define RETEN_CALL 7
#define INVALID_AMOUNT 13
#define TIT_DES_SUP 14
#define DNI_DES 15
#define DATE_FROM_ERROR 16
#define CUP_DUP 17
#define VD_ERROR 18
#define WRITE_ERROR 19
#define CUOTA_EXCD 21
#define CUOTA_NUM_ERROR 23
//#define REG_NOT_FOUND_ANULAR 76
#define REG_NOT_FOUND_ANULAR 25
#define ANULACION_UNK 25

#define FORMAT_ERROR 30
#define PLAN1_DATE_ERROR 31
#define COMER_SUP 38
#define FALTA_BOLETIN 40
#define RETEN_CALL2 41
#define CUOTA_EXCD2 48
#define EXP_DATE_ERROR 49
#define COMER_FIDELIDAD_DES 53
#define EXPIRED_CARD 54
#define HAVENO_LIMIT_EXCD 61

#define CVV_ERROR 5   ///  Esta operacion requiere CVV

#define LIMIT_EXCD 65
#define PLAN_CUOTAS_ERROR 77
#define HAVENO_MOVS 80
#define TERMINAL_UNK 89
#define EMISOR_CONN_ERROR 91
#define CIERRE_DIFF 95


//variables globales
struct iso8583 //todos los campos en la estructura se manejan es ascii, a excepción del 1_bitmap que es hex.
{
    char tpdu[11],
    mtype[5],            // msg type by iso
    bitmap_1[8],         // field mapper
    pan_2[21],           // card number manual
    procode_3[7],        // sub id from mtype -> op. type.
    amount_4[13],        // importe -> 2 decimal
    systracenum_11[7],   // terminal count operation number
    timetrx_12[7],       // terminal rtc time
    datetrx_13[5],       // terminal rtc date  MMDD (year = now)
    dateexpire_14[5],    // card expire manual
    datesettle_15[5],      // fecha de creacion lote (0500)
    posentrymode_22[5],    // manual / banda
    nii_24[5],             // logical NII
    poscondcode_25[3],     // not used
    track2_35[38],         // card number and vigencia by banda
    retrefnum_37[13],      // auth -> random ref
    authid_38[7],          // auth ID -> BCD (puede ser HEX) codigo de autorizacion.
    respcode_39[3],        // cod respuesta
    termid_41[9],          // terminal ID
    merchid_42[16],        // comer ID, left space fill COMER
    track1_45[77],         // main track data
    currcode_49[4],        // moneda code (997 ?)
    settcurrcode_50[4],    // modena para 0500
    addamount_54[100],     // salud (not used)
    cvv_55[100],           // string de CVV
    field_59[100],         // string de fecha completo
    field_60[100],         // user defined (hex)
    field_61[100],         // user defined (hex)
    field_62[100],         // user defined (hex)
    field_63[100];         // user defined (hex)
    int flag_ingenico;
    int length_63; //para indicar la longitud de los campos en ascii de longitud variable cuando contienen elementos en bcd.(solo modificado para tdf)
};

struct authCONF{
    int auth_port;
    char auth_listen[17];
    char auth_log[256];
    char auth_nlive[20][17];

    char dbHost[32];
    char dbUser[32];
    char dbPass[32];
    char dbName[32];
};

extern struct authCONF* aconf;

extern int read_config(char* confFL);
extern void* auth_thread(void* data);

//prototipos
extern int sckt(char *host, char *port, int l, char *req, char *resp);
//extern char* cliISOThr(struct iso8583* iso, char* ans);

extern int tlog(char *,char *,char *);
extern void get_time(char *,char *);
extern int packunpack_iso(char *,struct iso8583 *,int,int);
extern int rw_bitmap(int,char *,int);

extern void bcd_to_asc(int,char *,char *);
extern int asc_to_bcd(char *,char *);

extern int longitude_to_int(char,char,char);
extern void int_to_longitude(char,int,char *,char *);
extern int genVd(char *,int,int);

#endif
