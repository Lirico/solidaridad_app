#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <my_global.h>
#include <mysql.h>

#include "auth_kig.h"
#include "auth_mycli.h"

int guardar_iso(MYSQL* con, struct iso8583* iso, int inout)
{
    int ret = 0;
    int num_fields;
    int num_rows;
    int flag_close = 0;
    int i = 0;
    char sql[4096];

    memset(sql, '\0', 4096);

    sprintf(sql,
    "insert into iso_pool (tpdu,mtype,bitmap_1,pan_2,procode_3,amount_4,systracenum_11,"
    "timetrx_12,datetrx_13,dateexpire_14,datesettle_15,posentrymode_22,nii_24,poscondcode_25,"
    "track2_35,retrefnum_37,authid_38,respcode_39,termid_41,merchid_42,track1_45,"
    "currcode_49,settcurrcode_50,addamount_54,cvv_55,field_59,field_60,field_61,field_62,field_63,length_63) values ("
    " '%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s', "
    " '%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s', %d)",

    iso->tpdu,iso->mtype,iso->bitmap_1,iso->pan_2,iso->procode_3,iso->amount_4,iso->systracenum_11,
    iso->timetrx_12,iso->datetrx_13,iso->dateexpire_14,iso->datesettle_15,iso->posentrymode_22,iso->nii_24,iso->poscondcode_25,
    iso->track2_35,iso->retrefnum_37,iso->authid_38,iso->respcode_39,iso->termid_41,iso->merchid_42,iso->track1_45,
    iso->currcode_49,iso->settcurrcode_50,iso->addamount_54,iso->cvv_55,iso->field_59,iso->field_60,iso->field_61,
    iso->field_62,iso->field_63,iso->length_63
    );

    printf("guardar_iso(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
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

        flag_close = 1;
    }

    if (mysql_query(con, sql))
    {
        printf("guardar_iso() ERROR: validando CVV query.");
        if (flag_close == 1)
        {
            mysql_close(con);
        }
        return -3;
    }

    if (flag_close == 1)
    {
        mysql_close(con);
    }

    return ret;
}

static int validaMontoVentaUltimaRecarga(MYSQL *con, char *card_number, char *codMoneda, double montoVenta) {
    double montoUltimaRecarga;
    int val; 
    double montoMaximo, ratio_max;

    if (obtieneConfiguracion(con, "venta_max_porcentaje_ultima_recarga", NULL, &val)) {
        return -1;
    }

    // venta_max_porcentaje_ultima_recarga se almacena como int con dos decimales, en porcentaje
    ratio_max = (double)val / 10000.0;

    if (obtieneUltimaRecarga(con, card_number, codMoneda, &montoUltimaRecarga)) {
        return -1;
    }

    montoMaximo = montoUltimaRecarga * ratio_max;
    printf("validaMontoVentaUltimaRecarga() LOG MontoVenta=%f UltimaRecarga=%f Ratio=%f Max=%f\n",
           montoVenta, montoUltimaRecarga, ratio_max, montoMaximo);

    if (montoVenta > montoMaximo) {
        return INVALID_AMOUNT;
    }

    return 0;
}

int valida_terminal_comercio(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_terminal_comercio(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sprintf(sql, "SELECT situacion FROM terminales WHERE codigo_terminales='%s' and cod_comercio='%s'", iso->termid_41, iso->merchid_42 );
    if (mysql_query(con, sql))
    {
        printf("valida_terminal_comercio() ERROR: validando terminales query.");
        free(sql);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_terminal_comercio() ERROR: validando terminales store.");
        free(sql);
        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_terminal_comercio() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        ret = TRANS_OK;
    } else{
        ret = TERMINAL_UNK;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

int valida_cvv(MYSQL* con, struct iso8583* iso)
{
  int ret = 0;
  MYSQL_ROW row;
  MYSQL_RES *result;
  int num_fields;
  int num_rows;
  int flag_close = 0;

  char* sql = (char*)malloc(sizeof(char)*1024);
  memset(sql, '\0', 1024);

  printf("valida_cvv(): INIT \n");

  if(rw_bitmap(55,iso->bitmap_1,0))
  {
     return TRANS_OK;
  }

  if (con == NULL)
  {
      fprintf(stderr, "%s\n", mysql_error(con));
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

      flag_close = 1;
  }

  char* cNum = getCardNumber(iso);

  sprintf(sql, "SELECT cvv_actual FROM sgas_usuario WHERE nro_tarjeta = '%s'", cNum );
  if (mysql_query(con, sql))
  {
      printf("valida_cvv() ERROR: validando CVV query.");
      free(sql);
      if (flag_close == 1)
      {
          mysql_close(con);
      }

      return -3;
  }

  result = mysql_store_result(con);
  if (result == NULL)
  {
      printf("valida_cvv() ERROR: validando CVV store.");
      free(sql);
      if (flag_close == 1)
      {
          mysql_close(con);
      }

      return -3;
  }

  num_rows = mysql_num_rows(result);
  printf("valida_cvv() NUM_ROWS: %d\n", num_rows);
  if (num_rows != 0)
  {
      row = mysql_fetch_row(result);

      if (strcmp(row[0], iso->cvv_55) == 0)
      {
          ret = TRANS_OK;
          printf("valida_cvv() validando CVV OK.");
      } else {
          printf("valida_cvv() validando CVV -> No es el mismo!");
          ret = CVV_ERROR;
      }

  } else{
      printf("valida_cvv() validando CVV NOK.");
      ret = CVV_ERROR;
  }

  mysql_free_result(result);
  free(sql);

  if (flag_close == 1)
  {
      mysql_close(con);
  }

  return ret;
}

int valida_terminal(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_fields;
    int num_rows;
    int flag_close = 0;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_terminal(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
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

        flag_close = 1;
    }

    sprintf(sql, "SELECT situacion, marca, cod_moneda, cod_comercio FROM terminales WHERE codigo_terminales='%s'", iso->termid_41 );
    if (mysql_query(con, sql))
    {
        printf("valida_terminal() ERROR: validando terminales query.");
        free(sql);
        if (flag_close == 1)
        {
            mysql_close(con);
        }

        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_terminal() ERROR: validando terminales store.");
        free(sql);
        if (flag_close == 1)
        {
            mysql_close(con);
        }

        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_terminal() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        if (strcmp(row[0], "V") == 0 && row[3] != NULL && row[3][0] != '\0')
        {
            if(strcmp(row[1], "Ingenico") == 0)
            {
                printf("valida_terminal() Terminal Type: %s\n", row[1]);
                iso->flag_ingenico = 1;
            }
            else if(strcmp(row[1], "VeriFone") == 0)
            {
                printf("valida_terminal() Terminal Type: %s\n", row[1]);
                iso->flag_ingenico = 0;
            }
            else if(strcmp(row[1], "IVR") == 0)
            {
                printf("valida_terminal() Terminal Type: %s\n", row[1]);
                iso->flag_ingenico = 2;
            }

            /* Comercio siempre desde terminales (solo DE41). */
            memset(iso->merchid_42, '\0', 16);
            sprintf(iso->merchid_42, "%s", row[3]);

            /* Producto/DE49: solo Ingenico lo toma de terminales.cod_moneda.
             * VeriFone/IVR conservan el DE49 enviado en el mensaje. */
            if (iso->flag_ingenico == 1
                && row[2] != NULL
                && row[2][0] != '\0')
            {
                memset(iso->currcode_49, '\0', 4);
                sprintf(iso->currcode_49, "%s", row[2]);
            }

            ret = TRANS_OK;
        } else {
            ret = TERMINAL_UNK;
        }
    } else{
        ret = TERMINAL_UNK;
    }

    mysql_free_result(result);
    free(sql);

    if (flag_close == 1)
    {
        mysql_close(con);
    }

    return ret;
}

char* getUserProds(MYSQL* con, char* nroTarjeta)
{
    char* ret = NULL;
    MYSQL_ROW row;
    MYSQL_RES *result;
    double prod_amount;
    int num_rows;

    int i=0;
    int slen=0;

    struct tm ts;
    time_t now;
    time (&now);
    ts=*localtime(&now);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("getUserProds(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return NULL;
    }

    sprintf(sql, "SELECT cta.id_usuario, cta.nro_tarjeta, cta.prod_id, prd.tname "
                 "FROM sgas_usuario_cta cta, sgas_productos prd "
                 "WHERE cta.fecha_operacion LIKE '%d-%02d-%%' AND cta.cod_operacion=1 AND cta.nro_tarjeta='%s' "
                 "AND prd.cod_moneda=cta.prod_id ORDER BY id_usuario"
    , (ts.tm_year+1900), (ts.tm_mon+1), nroTarjeta );

    if (mysql_query(con, sql))
    {
        printf("getUserProds() ERROR: exec.");
        free(sql);
        return NULL;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getUserProds() ERROR: store.");
        free(sql);
        return NULL;
    }

    num_rows = mysql_num_rows(result);
    printf("getUserProds() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        ret = (char*) malloc(sizeof(char)*50);
        memset(ret, '\0', 50);

        sprintf(ret, "Tipo de asignacion: ");

        for (i=0; i<num_rows; i++)
        {
            row = mysql_fetch_row(result);
            slen = strlen(ret);
            sprintf(&ret[slen], "%s ", row[3]);
        }
    } else{
        ret = NULL;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

int validaCantidadTK(MYSQL* con, char* codMoneda)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    double prod_amount;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("validaCantidadTK(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sprintf(sql, "SELECT max_tk_unit FROM sgas_productos WHERE cod_moneda='%s'", codMoneda );
    if (mysql_query(con, sql))
    {
        printf("validaCantidadTK() ERROR: exec.");
        free(sql);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("validaCantidadTK() ERROR: store.");
        free(sql);
        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("validaCantidadTK() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0]);
    } else{
        ret = -1;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

int validaIntMoneda(MYSQL* con, char* codMoneda)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    double prod_amount;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("validaIntMoneda(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sprintf(sql, "SELECT valida_int FROM sgas_productos WHERE cod_moneda='%s'", codMoneda );
    if (mysql_query(con, sql))
    {
        printf("validaIntMoneda() ERROR: exec.");
        free(sql);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("validaIntMoneda() ERROR: store.");
        free(sql);
        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("validaIntMoneda() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0]);
    } else{
        ret = -1;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

double getProdAmount(MYSQL* con, char* codMoneda)
{
    double ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    double prod_amount;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("getProdAmount(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    // valida comercio
    sprintf(sql, "select kgas_carga from sgas_productos where cod_moneda='%s'", codMoneda );
    if (mysql_query(con, sql))
    {
        printf("getProdAmount() ERROR: exec.");
        free(sql);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getProdAmount() ERROR: store.");
        free(sql);
        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("getProdAmount() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        prod_amount = atof(row[0]);

        ret = prod_amount;
    } else{
        ret = -1;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

int valida_comercio(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_fields;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_comercio(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    // valida comercio
    sprintf(sql, "SELECT situacion FROM sgas_comercio WHERE cod_comercio='%s'", iso->merchid_42 );
    if (mysql_query(con, sql))
    {
        printf("valida_comercio() ERROR: validando comercio.");
        free(sql);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_comercio() ERROR: validando comercio.");
        free(sql);
        return -3;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_comercio() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        if (strcmp(row[0], "V") == 0)
        {
            ret = TRANS_OK;
        } else {
            ret = COMER_SUP;
        }
    } else{
        ret = COMER_DES_SUP;
    }

    mysql_free_result(result);
    free(sql);

    return ret;
}

int valida_usuario_existe(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* cNum;
    int num_rows;

    struct tm ts;
    time_t now;
    time (&now);
    ts=*localtime(&now);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_usuario_existe(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    cNum = getCardNumber(iso);

    sprintf(sql, "SELECT situacion,nro_doc FROM sgas_usuario WHERE nro_tarjeta='%s' AND situacion='V' and marca_baja=0 "
                 " ORDER BY fecha_situacion desc", cNum );

    printf("valida_usuario_existe() SQL: %s\n", sql);

    free(cNum);
    //memset(cNum, '\0', 21);

    if (mysql_query(con, sql))
    {
        printf("valida_usuario_existe() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_usuario_existe() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return TIT_DES_SUP;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_usuario_existe() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        ret = TRANS_OK;
        mysql_free_result(result);
    }  else {
        ret = TIT_DES_SUP;
        mysql_free_result(result);
        free(sql);
        return ret;
    }

    //mysql_free_result(result);
    free(sql);
    return ret;
}

int valida_usuario_vigencia(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    char vig[6];

    int num_rows;
    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);

    //return TRANS_OK;

    char* vigencia_c = getVencimiento(iso);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_usuario_vigencia(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    int v_year = z.tm_year-100;
    int v_mont = z.tm_mon+1;

    int c_year = 0;
    int c_mont = 0;

    vig[0] = vigencia_c[0];
    vig[1] = vigencia_c[1];
    vig[2] = '\0';
    vig[3] = vigencia_c[2];
    vig[4] = vigencia_c[3];
    vig[5] = '\0';

    c_year = atoi(vig);
    c_mont = atoi(&vig[3]);

    if (c_year < v_year)
    {
        return EXPIRED_CARD;
    } else {
        //if (c_mont < v_mont)
        //{
        //    return EXPIRED_CARD;
        //}
    }

    char* cNum = getCardNumber(iso);

    //if ((c_year != 17) && (c_mont != 9))
    //{
       printf("valida_usuario_vigencia() VIGENCIA NORMAL \n");

       sprintf(sql, "SELECT situacion, nro_doc FROM sgas_usuario WHERE nro_tarjeta='%s' AND"
                    " situacion='V' AND vigencia_hasta like '%d-%02d-%%'",
               cNum, (c_year+100+1900), c_mont);
    //} else {
        //printf("valida_usuario_vigencia() VIGENCIA ESPECIAL 0917 DEJA PASAR \n");
        //sprintf(sql, "SELECT situacion, nro_doc FROM sgas_usuario WHERE nro_tarjeta='%s' AND situacion='V' ", cNum );
    //}

    printf("valida_usuario_vigencia() SQL: %s\n", sql);

    free(cNum);

    if (mysql_query(con, sql))
    {
        printf("valida_usuario_vigencia() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_usuario_vigencia() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return EXP_DATE_ERROR;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_usuario_vigencia() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        ret = TRANS_OK;
    }  else {
        ret = EXP_DATE_ERROR;
        //mysql_free_result(result);
        //free(sql);
        //return ret;
        //ret = TRANS_OK;
    }

    mysql_free_result(result);
    free(sql);
    return ret;
    //return TRANS_OK;
}

int valida_usuario_producto(MYSQL* con, struct iso8583* iso)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;

    int num_rows;

    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("valida_usuario_producto(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    char* cNum = getCardNumber(iso);
    //sprintf(sql, "SELECT * FROM sgas_usuario_cta WHERE nro_tarjeta='%s' AND prod_id='%s' AND fecha_operacion like '%d-%02d-%%' ",
    //cNum, getProduct(iso), (z.tm_year+1900), (z.tm_mon+1) );

    // PARA CAMBIO DE CIERRE
    sprintf(sql, "SELECT * FROM sgas_usuario_cta WHERE nro_tarjeta='%s' AND prod_id='%s' ",
    cNum, getProduct(iso) );

    printf("valida_usuario_producto() SQL: %s\n", sql);

    free(cNum);

    if (mysql_query(con, sql))
    {
        printf("valida_usuario_producto() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_usuario_producto() ERROR: validando vigencia.");
        free(sql);
        //mysql_close(con);
        return TRASN_TYPE_UNK;
    }

    num_rows = mysql_num_rows(result);
    printf("valida_usuario_producto() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        ret = TRANS_OK;
    }  else {
        ret = TRASN_TYPE_UNK;
        mysql_free_result(result);
        free(sql);
        return ret;
    }

    mysql_free_result(result);
    free(sql);
    return ret;
}

int valida_usuario(MYSQL* con, struct iso8583* iso)
{
    int ret = TRANS_OK;

    ret = valida_usuario_existe(con, iso);
    if (ret != TRANS_OK)
    {
        return ret;
    }

//    ret = valida_usuario_vigencia(con, iso);
//    if (ret != TRANS_OK)
//    {
//        return ret;
//    }

    ret = valida_usuario_producto(con, iso);
    if (ret != TRANS_OK)
    {
        return ret;
    }

    return ret;
}

int getMonedaFromCUP(MYSQL *con, struct iso8583* iso, struct iso8583* iso_tmp, int flag)
{
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql;
    int num_rows = 0;
    int ret = 0;
    char* cNum;

    printf("getMonedaFromCUP(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    if (flag == 1) // VeriFone
    {
        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT cod_moneda FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND terminalid = '%s' AND "
            "numero_comprobante = %s AND tipo_mensaje = '%s' AND nro_tarjeta = '%s'  ",
            iso->merchid_42,
            iso->termid_41,
            iso_tmp->retrefnum_37,
            iso->mtype,
            cNum
        );

        free(cNum);
    } else if (flag == 2) {  // INGENICO
        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT cod_moneda, numero_comprobante FROM sgas_cup WHERE "
            "terminalid = '%s' AND codigo_autorizacion = '%s' AND "
            "numero_comprobante = %s AND tipo_mensaje = '%s' AND nro_tarjeta = '%s'  ",
            iso->termid_41,
            iso_tmp->authid_38,
            iso_tmp->field_62,
            iso->mtype,
            cNum
        );

        free(cNum);
    } else if (flag == 3) {  // IVR
        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT cod_moneda FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND terminalid = '%s' AND "
            "tipo_mensaje = '%s' AND nro_tarjeta = '%s' AND codigo_autorizacion = '%s' AND importe=%f",
            iso->merchid_42,
            iso->termid_41,
            iso->mtype,
            cNum,
            iso_tmp->authid_38,
            getAmount(iso)
        );

        free(cNum);
    }

    printf("getMonedaFromCUP() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("%s\n", mysql_error(con));
        free(sql);
        return -3000;
    }

    printf("getMonedaFromCUP() - store results \n");

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getMonedaFromCUP() ERROR: buscando lote.");
        free(sql);
        return -3000;
    }

    num_rows = mysql_num_rows(result);

    printf("getMonedaFromCUP() - num_rows = %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0]);

        // INGENICO
        if (flag == 2)
        {
            memset(iso->retrefnum_37, '\0', 13);
            sprintf(iso->retrefnum_37, "%012u", atoi(row[1]));
        }
    } else {
        ret = -1;
    }

    mysql_free_result(result);
    free(sql);
    return ret;
}

int getLoteIdFromCUP(MYSQL *con, struct iso8583* iso, struct iso8583* iso_tmp, int flag)
{
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql;
    int num_rows = 0;
    int ret = 0;
    char* cNum;

    printf("getLoteIdFromCUP(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    if (flag == 1) // VeriFone
    {
        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT lote FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND terminalid = '%s' AND "
            "numero_comprobante = %s AND tipo_mensaje = '%s' AND nro_tarjeta = '%s'  ",
            iso->merchid_42,
            iso->termid_41,
            iso_tmp->retrefnum_37,
            iso->mtype,
            cNum
        );

        free(cNum);

    } else if (flag == 2) {  // INGENICO

        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT lote, numero_comprobante FROM sgas_cup WHERE "
            "terminalid = '%s' AND codigo_autorizacion = '%s' AND "
            "numero_comprobante = %s AND tipo_mensaje = '%s' AND nro_tarjeta = '%s'  ",
            iso->termid_41,
            iso_tmp->authid_38,
            iso_tmp->field_62,
            iso->mtype,
            cNum
        );

        free(cNum);
    } else if (flag == 3) {  // IVR

        cNum = getCardNumber(iso);

        sprintf(sql, "SELECT lote FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND terminalid = '%s' AND "
            "tipo_mensaje = '%s' AND nro_tarjeta = '%s' AND codigo_autorizacion = '%s' AND importe=%f",
            iso->merchid_42,
            iso->termid_41,
            iso->mtype,
            cNum,
            iso_tmp->authid_38,
            getAmount(iso)
        );

        free(cNum);
    }

    printf("getLoteIdFromCUP() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("%s\n", mysql_error(con));
        free(sql);
        return -3000;
    }

    printf("getLoteIdFromCUP() - store results \n");

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getLoteIdFromCUP() ERROR: buscando lote.");
        free(sql);
        return -3000;
    }

    num_rows = mysql_num_rows(result);

    printf("getLoteIdFromCUP() - num_rows = %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0]);

        // INGENICO
        if (flag == 2)
        {
            memset(iso->retrefnum_37, '\0', 13);
            sprintf(iso->retrefnum_37, "%012u", atoi(row[1]));
        }
    } else {
        ret = -1;
    }

    mysql_free_result(result);
    free(sql);
    return ret;
}

int reversa_cupon(MYSQL *con, struct iso8583* iso)
{
    char* sql_ins;
    int num_rows = 0;
    int ret = 0;
    char* cNum;

    printf("reversa_cupon(): INIT. %d\n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    cNum = getCardNumber(iso);

    sprintf(sql_ins, "UPDATE sgas_cup SET tipo_mensaje = '0400' WHERE "
        "cod_comercio = '%s' AND vencimiento = '%s' AND importe = %f AND id_operacion = %s AND terminalid = '%s' AND "
        "numero_comprobante = %s AND cod_moneda = '%s' AND nro_tarjeta = '%s' AND lote = %d AND procode = '%s'",
        iso->merchid_42,
        getVencimiento(iso),
        getAmount(iso),
        iso->systracenum_11,
        iso->termid_41,
        iso->field_62,
        iso->currcode_49,
        cNum,
        getLoteID(iso),
        iso->procode_3
    );

    free(cNum);

    printf("reversa_cupon() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3;
    }

    printf("reversa_cupon() - OK\n");
    free(sql_ins);
    return ret;
}

int valida_cupon_dup(MYSQL *con, struct iso8583* iso)
{
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql_ins;
    int num_rows = 0;
    int ret = 0;
    char* cNum;

    printf("valida_cupon_dup()): INIT\n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    cNum = getCardNumber(iso);

    sprintf(sql_ins, "SELECT lote FROM sgas_cup WHERE "
        "cod_comercio = '%s' AND terminalid = '%s' AND "
        "numero_comprobante = %s AND tipo_mensaje = '%s' AND cod_moneda = '%s' AND lote = %d AND procode = '%s'",
        iso->merchid_42,
        iso->termid_41,
        iso->field_62,
        iso->mtype,
        iso->currcode_49,
        getLoteID(iso),
        iso->procode_3
    );

    free(cNum);

    printf("valida_cupon_dup() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_cupon_dup() ERROR: validando cupon.");
        free(sql_ins);
        return -3000;
    }

    num_rows = mysql_num_rows(result);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0])+1;
    } else {
        ret = 0;
    }

    mysql_free_result(result);
    free(sql_ins);
    return ret;
}

int valida_cupon_reverso(MYSQL *con, struct iso8583* iso)
{
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql_ins;
    int num_rows = 0;
    int ret = 0;
    char* cNum;
    int sub_ret = 0;

    printf("valida_cupon_reverso(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    cNum = getCardNumber(iso);

        sprintf(sql_ins, "SELECT lote FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND vencimiento = '%s' AND importe = %f AND id_operacion = %s AND terminalid = '%s' AND "
            "numero_comprobante = %s AND cod_moneda = '%s' AND nro_tarjeta = '%s' AND lote = %d AND procode = '%s'",
            iso->merchid_42,
            getVencimiento(iso),
            getAmount(iso),
            iso->systracenum_11,
            iso->termid_41,
            iso->field_62,
            iso->currcode_49,
            cNum,
            getLoteID(iso),
            iso->procode_3
        );

    free(cNum);

    printf("valida_cupon_reverso() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_cupon_reverso() ERROR: validando cupon.");
        free(sql_ins);
        return -3000;
    }

    num_rows = mysql_num_rows(result);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0])+1;
    } else {
        ret = 0;
    }

    mysql_free_result(result);
    free(sql_ins);

    if (sub_ret != 0)
    {
        ret = sub_ret;
    }

    return ret;
}


int valida_cupon(MYSQL *con, struct iso8583* iso, int rever)
{
    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql_ins;
    int num_rows = 0;
    int ret = 0;
    char* cNum;
    int sub_ret = 0;

    printf("valida_cupon(): INIT, rever = %d\n", rever);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    cNum = getCardNumber(iso);

    if (rever == 0)
    {
        sprintf(sql_ins, "SELECT lote FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND vencimiento = '%s' AND importe = %f AND id_operacion = %s AND terminalid = '%s' AND "
            "numero_comprobante = %s AND tipo_mensaje = '%s' AND cod_moneda = '%s' AND nro_tarjeta = '%s' AND lote = %d AND procode = '%s'",
            iso->merchid_42,
            getVencimiento(iso),
            getAmount(iso),
            iso->systracenum_11,
            iso->termid_41,
            iso->field_62,
            iso->mtype,
            iso->currcode_49,
            cNum,
            getLoteID(iso),
            iso->procode_3
        );

        sub_ret = valida_cupon_dup(con, iso);

    } else {

        sprintf(sql_ins, "SELECT lote FROM sgas_cup WHERE "
            "cod_comercio = '%s' AND vencimiento = '%s' AND importe = %f AND id_operacion = %s AND terminalid = '%s' AND "
            "numero_comprobante = %s AND cod_moneda = '%s' AND nro_tarjeta = '%s' AND lote = %d AND procode = '%s'",
            iso->merchid_42,
            getVencimiento(iso),
            getAmount(iso),
            iso->systracenum_11,
            iso->termid_41,
            iso->field_62,
            iso->currcode_49,
            cNum,
            getLoteID(iso),
            iso->procode_3
        );
    }

    free(cNum);

    printf("valida_cupon() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("valida_cupon() ERROR: validando cupon.");
        free(sql_ins);
        return -3000;
    }

    num_rows = mysql_num_rows(result);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        ret = atoi(row[0])+1;
    } else {
        ret = 0;
    }

    mysql_free_result(result);
    free(sql_ins);

    if (sub_ret != 0)
    {
        ret = sub_ret;
    }

    return ret;
}

int valida_operacion(struct iso8583* iso, char* bm_req)
{
    int ret;
    MYSQL *con;

    printf("valida_operacion(): INIT \n");

    con = mysql_init(NULL);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL)
        //mysql_real_connect(con, MYDB_HOST, MYDB_USER, MYDB_PASS, MYDB_DB, 0, NULL, 0) == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    if(rw_bitmap(55,bm_req,0))
    {
      ret = valida_cvv(con, iso);
      printf("valida_operacion(): valida_cvv ret = %d \n", ret);
      if (ret != 0)
      {
         mysql_close(con);
         ret = CVV_ERROR;

         rw_bitmap(63,iso->bitmap_1,1);
         memset(iso->field_63, '\0', 100);
         sprintf(iso->field_63, "CVV Invalido.");
         iso->length_63=strlen(iso->field_63);
         return ret;
      }
    } else {
      printf("valida_operacion(): valida_cvv flag apagado \n");
    }


    ret = valida_terminal(con, iso);
    printf("valida_operacion(): valida terminal = %d \n", ret);
    if (ret != 0)
    {
        mysql_close(con);
        ret = TERMINAL_UNK;
        return ret;
    }

    ret = valida_comercio(con, iso);
    printf("valida_operacion(): valida comercio = %d \n", ret);

    if (ret != 0)
    {
        mysql_close(con);
        return ret;
    }

    ret = valida_usuario(con, iso);
    printf("valida_operacion(): valida usuario = %d \n", ret);

    if (ret != 0)
    {
        mysql_close(con);
        return ret;
    }

    ret = valida_cupon(con, iso, 0);
    printf("valida_operacion(): valida cupon = %d \n", ret);

    if (ret > 0)
    {
        mysql_close(con);
        ret = CUP_DUP;
        printf("valida_operacion(): devuelve = %d \n", ret);
        return ret;
    } else if (ret < 0) {
        return ret;
    }

    ret = TRANS_OK;
    printf("valida_operacion(): devuelve = %d \n", ret);

    mysql_close(con);
    return ret;
}

int venta_cupon(struct iso8583* iso)
{
    double consumo_vivo = 0.0;
    double consumo_acum = 0.0;
    double consumo = 0.0;

    double saldo_anterior = 0.0;
    double saldo_final = 0.0;
    double saldo_actual = 0.0;
    double saldo_descubierto = 0.0;
    int tk_max;

    char* cNum;

    double tk_amount = 0.0;
    int tk_int_amount = 0;
    double prod_charge = 0.0;

	MYSQL *con;
	char* sql_ins;
    int ret;

    printf("venta_cupon(): INIT \n");

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

    cNum = getCardNumber(iso);

    consumo = calcula_consumo_vivo(con, cNum, 0, iso);
    if (consumo < -1000)
    {
        free(cNum);
        mysql_close(con);
        ret = -1;
        return ret;
    }

    consumo_acum = calcula_consumo_vivo_acum(con, cNum, 0, iso);
    printf("consulta_saldo() LOG consumo_vivo_acum = %f\n", consumo);
    if (consumo < -1000)
    {
        free(cNum);
        mysql_close(con);
        return -1;
    }

    consumo_vivo  = consumo + consumo_acum;

    saldo_anterior = calcula_saldo_anterior(con, cNum, iso->currcode_49);
    if (saldo_anterior < -1000)
    {
        free(cNum);
        mysql_close(con);
        ret = -1;
        return ret;
    }

    saldo_descubierto = calcula_descubierto(con, getProduct(iso));
    if (saldo_descubierto < -1000)
    {
        free(cNum);
        mysql_close(con);
        ret = -1;
        return ret;
    }

    printf("venta_cupon() LOG saldo_descubierto = %f\n", saldo_descubierto);
    printf("venta_cupon() LOG consumo_vivo = %f\n", consumo_vivo);
    printf("venta_cupon() LOG saldo_anterior = %f\n", saldo_anterior);

    saldo_actual = saldo_anterior - consumo_vivo;

    printf("venta_cupon() LOG saldo_actual = %f\n", saldo_actual);

    tk_amount = getAmount(iso);

    if (validaIntMoneda(con, iso->currcode_49) == VALIDA_INT_OK)
    {
        tk_int_amount = (int)tk_amount;

        printf("venta_cupon() validaIntMoneda -> tk_int_amount = %d, tk_amount = %f \n", tk_int_amount, tk_amount);

        if (tk_int_amount != tk_amount)
        {
            mysql_close(con);
            return INVALID_AMOUNT;
        }
    }

    tk_max = validaCantidadTK(con, iso->currcode_49);
    if (tk_max > 0)
    {
        printf("venta_cupon() validaCantidadTK = %d, tk_int_amount = %d \n", tk_max, tk_int_amount);
        tk_int_amount = (int)tk_amount;

        if (tk_int_amount > tk_max)
        {
            mysql_close(con);
            return INVALID_AMOUNT;
        }
    }

    prod_charge = getProdAmount(con, iso->currcode_49);

    if (saldo_actual <= 0)
    {
        if (saldo_actual <= (saldo_descubierto * (-1)) )
        {
            mysql_close(con);
            ret = LIMIT_EXCD;
            return ret;
        } else {
            saldo_final = saldo_actual - (tk_amount*prod_charge);

            if (saldo_final < ((-1)*saldo_descubierto))
            {
                mysql_close(con);
                ret = LIMIT_EXCD;
                return ret;
            }
        }
    } else{
        if (saldo_actual < (tk_amount*prod_charge) )
        {
            saldo_final = saldo_actual - (tk_amount*prod_charge);

            if (saldo_final < ((-1)*saldo_descubierto))
            {
                mysql_close(con);
                ret = LIMIT_EXCD;
                return ret;
            }
        }
    }

    // Se valida el maximo monto posible para una venta respecto a la ultima carga
    // (ratio configurable en soli_config: venta_max_ratio_ultima_recarga)
    ret = validaMontoVentaUltimaRecarga(con, cNum, iso->currcode_49, tk_amount * prod_charge);
    if (ret != 0) {
        mysql_close(con);
        return ret;
    }

    printf("venta_cupon() LOG Valida fecha ultima venta. Tarjeta= %s Moneda= %s\n", cNum, iso->currcode_49);
    // Se valida que la ultima venta se haya hecho al menos 72 horas antes
    ret = validaTiempoUltimaVenta(con, cNum, iso->currcode_49);
    if (ret < 0) {
        mysql_close(con);
        return -1;
    }
    if (ret > 0) {
        mysql_close(con);
        return TRANS_DENY;
    }

    printf("venta_cupon() LOG saldo_actual = %f\n", saldo_final);

    if (informa_subsidio(con, iso)) {
        mysql_close(con);
        return -1;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

  	sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, cod_comercio, vencimiento, importe, "
      "codigo_autorizacion, refref, id_operacion, codigo_respuesta, terminalid, "
      "numero_comprobante, tipo_mensaje, cod_moneda, nro_tarjeta, lote, procode, anula_comprobante) values("
      "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c',"
      " 1, '%s', '%s', %f, '%s', '%s', %s, '%s', '%s', '%s', '%s', '%s', '%s', %d, '%s', -1)",
       iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
       iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
       iso->merchid_42,
       getVencimiento(iso),
       getAmount(iso),
       iso->authid_38,
       iso->retrefnum_37,
       iso->systracenum_11,
       iso->respcode_39,
       iso->termid_41,
       iso->field_62,
       iso->mtype,
       iso->currcode_49,
       cNum,
       getLoteID(iso),
       iso->procode_3
    );

    free(cNum);

    printf("venta_cupon() - SQL: %s\n", sql_ins);

  	if (mysql_query(con, sql_ins))
  	{
        free(cNum);
  		fprintf(stderr, "%s\n", mysql_error(con));
      	mysql_close(con);
      	return -3;
  	}

    free(sql_ins);
  	mysql_close(con);
  	return 0;
}

int anula_cupon(struct iso8583* iso, struct iso8583* iso_tmp)
{
	MYSQL *con = mysql_init(NULL);
    int loteid = 0;
    int codMoneda = 0;
    char* cNum;

    char* sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL)
        //mysql_real_connect(con, MYDB_HOST, MYDB_USER, MYDB_PASS, MYDB_DB, 0, NULL, 0)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    memset(iso->posentrymode_22, '\0', 5);
    sprintf(iso->posentrymode_22, "0012");

    if (atoi(iso->procode_3) == 50000)  // IVR
    {
        printf("anula_cupon() - COD MONEDA IVR\n");
        codMoneda = getMonedaFromCUP(con, iso, iso_tmp, 3);
        printf("anula_cupon() - codMoneda = %d \n", codMoneda);

        printf("anula_cupon() - BUSCA IVR\n");
        loteid = getLoteIdFromCUP(con, iso, iso_tmp, 3);
        printf("anula_cupon() - loteID = %d\n", loteid);

        if (loteid <= -1000)
        {
            mysql_close(con);
            return -1000;
        }

        if(loteid == -1)
        {
            mysql_close(con);
            return -1;
        }

        cNum = getCardNumber(iso);

        sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, cod_comercio, importe, "
        " codigo_autorizacion, codigo_respuesta, "
        " terminalid, numero_comprobante, tipo_mensaje, nro_tarjeta, procode, anula_comprobante, lote, cod_moneda) values("
        "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, '%s', %f,"
        " '%s', '%s', "
         "'%s', %s, '%s', '%s', '%s', %s, %d, '%d')",
            iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
            iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
            iso->merchid_42,
            getAmount(iso),
            iso->authid_38,
            iso->respcode_39,
            iso->termid_41,
            iso->systracenum_11,
            iso->mtype,
            cNum,
            iso->procode_3,
            iso->field_62,
            loteid,
            codMoneda
        );

        free(cNum);

    } else if (!rw_bitmap(37, iso_tmp->bitmap_1, 0)) {   // INGENICO

        printf("anula_cupon() - COD MONEDA INGENICO\n");
        codMoneda = getMonedaFromCUP(con, iso, iso_tmp, 2);
        printf("anula_cupon() - codMoneda = %d \n", codMoneda);

        printf("anula_cupon() - BUSCA INGENICO\n");
        loteid = getLoteIdFromCUP(con, iso, iso_tmp, 2);
        printf("anula_cupon() - loteID = %d\n", loteid);
        if (loteid < 0)
        {
            mysql_close(con);
            return -1;
        }

        cNum = getCardNumber(iso);

        sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, cod_comercio, importe, "
        " codigo_autorizacion, codigo_respuesta, "
        " terminalid, numero_comprobante, tipo_mensaje, nro_tarjeta, procode, anula_comprobante, lote, cod_moneda) values("
        "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, '%s', %f,"
        " '%s', '%s', "
         "'%s', %s, '%s', '%s', '%s', %s, %d, '%d')",
            iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
            iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
            iso->merchid_42,
            getAmount(iso),
            iso->authid_38,
            iso->respcode_39,
            iso->termid_41,
            iso->systracenum_11,
            iso->mtype,
            getCardNumber(iso),
            iso->procode_3,
            iso->field_62,
            loteid,
            codMoneda
        );

        free(cNum);
    } else {

        printf("anula_cupon() - COD MONEDA VERIFONE\n");
        codMoneda = getMonedaFromCUP(con, iso, iso_tmp, 1);
        printf("anula_cupon() - codMoneda = %d \n", codMoneda);

        printf("anula_cupon() - BUSCA VERIFONE\n");
        loteid = getLoteIdFromCUP(con, iso, iso_tmp, 1);
        printf("anula_cupon() - loteID = %d\n", loteid);

        if (loteid < 0)
        {
            free(sql_ins);
            mysql_close(con);
            return -1;
        }

        printf("anula_cupon() - LoteID: %d\n", loteid);

        cNum = getCardNumber(iso);

        sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, importe, "
            "codigo_autorizacion, id_operacion, codigo_respuesta, terminalid, "
            "numero_comprobante, tipo_mensaje, nro_tarjeta, procode, anula_comprobante, lote, cod_moneda, cod_comercio) values("
            "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, %f, "
            "'%s', %s, '%s', '%s',"
            "%s, '%s', '%s', '%s', %s, %d, '%d', '%s')",
            iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
            iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
            getAmount(iso),
            iso->authid_38,
            iso->systracenum_11,
            iso->respcode_39,
            iso->termid_41,
            iso->field_62,
            iso->mtype,
            getCardNumber(iso),
            iso->procode_3,
            iso_tmp->retrefnum_37,
            loteid,
            codMoneda,
            iso->merchid_42
        );

        free(cNum);
    }

    printf("anula_cupon() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -3;
    }

    free(sql_ins);
    mysql_close(con);
    return 0;
}

double calcula_consumo_vivo(MYSQL *con, char* card_number, int byTerm, struct iso8583* iso)
{
    double ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_fields;
    int num_rows;
    int i, j;
    double* vector_saldos;
    double saldo_final;
    double prod_charge;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("calcula_saldo_vivo(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    if (byTerm == 0)
    {
        sprintf(sql, "SELECT importe, numero_comprobante, tipo_mensaje, procode, anula_comprobante FROM sgas_cup "
                     "WHERE nro_tarjeta='%s' AND cod_moneda='%s'", card_number, iso->currcode_49);

        prod_charge = getProdAmount(con, iso->currcode_49);

    } else {
        sprintf(sql, "SELECT importe, numero_comprobante, tipo_mensaje, procode, anula_comprobante FROM sgas_trx "
                     "WHERE nro_tarjeta='%s' AND terminal_date=curdate() AND terminalid='%s' AND lote=%d",
                card_number,
                iso->termid_41,
                atoi(iso->field_60)
        );

        prod_charge = getProdAmount(con, iso->settcurrcode_50);
    }

    printf("calcula_saldo_vivo() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("calcula_saldo_vivo() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("calcula_saldo_vivo() ERROR: store results. \n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    num_rows = mysql_num_rows(result);
    j=0;

    printf("calcula_saldo_vivo() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        vector_saldos = (double*)malloc(sizeof(double)*num_rows);
        memset(vector_saldos, '\0', sizeof(double)*num_rows);

        for (i=0; i<num_rows; i++)
        {
            row = mysql_fetch_row(result);
            if (atoi(row[2]) == 200)
            {
                if ((atoi(row[3]) == 0) || (atoi(row[3]) == 200000)  )
                {
                    vector_saldos[j] = atof(row[0]);
                    j++;
                } else if ((atoi(row[3]) == 20000) || (atoi(row[3]) == 50000)) {
                    vector_saldos[j] = (-1)*atof(row[0]);
                    j++;;
                }
            }
        }

        i=0;
        saldo_final = 0.0;

        for (i=0; i<j; i++)
        {
            saldo_final = saldo_final + vector_saldos[i];
        }

        free(vector_saldos);
        mysql_free_result(result);

        saldo_final = saldo_final * prod_charge;

        printf("calcula_saldo_vivo() LOG saldo_final = %f\n", saldo_final);
        ret = saldo_final;
    } else {
        ret = 0.0;
    }

    free(sql);
    return ret;
}

double calcula_consumo_vivo_acum(MYSQL *con, char* card_number, int byTerm, struct iso8583* iso)
{
    double ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_fields;
    int num_rows;
    int i, j;
    double* vector_saldos;
    double saldo_final;
    double prod_charge;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("calcula_saldo_vivo(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    if (byTerm == 0)
    {
        sprintf(sql, "SELECT importe, numero_comprobante, tipo_mensaje, procode, anula_comprobante FROM sgas_cup_trx "
                     "WHERE nro_tarjeta='%s' AND cod_moneda='%s'", card_number, iso->currcode_49);

        prod_charge = getProdAmount(con, iso->currcode_49);

    } else {
        sprintf(sql, "SELECT importe, numero_comprobante, tipo_mensaje, procode, anula_comprobante FROM sgas_trx "
                     "WHERE nro_tarjeta='%s' AND terminal_date=curdate() AND terminalid='%s' AND lote=%d",
                card_number,
                iso->termid_41,
                atoi(iso->field_60)
        );

        prod_charge = getProdAmount(con, iso->settcurrcode_50);
    }

    printf("calcula_saldo_vivo() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("calcula_saldo_vivo() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("calcula_saldo_vivo() ERROR: store results. \n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    num_rows = mysql_num_rows(result);
    j=0;

    printf("calcula_saldo_vivo() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        vector_saldos = (double*)malloc(sizeof(double)*num_rows);
        memset(vector_saldos, '\0', sizeof(double)*num_rows);

        for (i=0; i<num_rows; i++)
        {
            row = mysql_fetch_row(result);
            if (atoi(row[2]) == 200)
            {
                if ((atoi(row[3]) == 0) || (atoi(row[3]) == 200000)  )
                {
                    vector_saldos[j] = atof(row[0]);
                    j++;
                } else if ((atoi(row[3]) == 20000) || (atoi(row[3]) == 50000)) {
                    vector_saldos[j] = (-1)*atof(row[0]);
                    j++;;
                }
            }
        }

        i=0;
        saldo_final = 0.0;

        for (i=0; i<j; i++)
        {
            saldo_final = saldo_final + vector_saldos[i];
        }

        free(vector_saldos);
        mysql_free_result(result);

        saldo_final = saldo_final * prod_charge;

        printf("calcula_saldo_vivo() LOG saldo_final = %f\n", saldo_final);
        ret = saldo_final;
    } else {
        ret = 0.0;
    }

    free(sql);
    return ret;
}

double calcula_descubierto(MYSQL *con, char* prod_id)
{
    double ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;
    double saldo_descubierto;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("calcula_descubierto(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sprintf(sql, "SELECT kgas_carga*multi FROM sgas_productos WHERE cod_moneda='%s'", prod_id );
    if (mysql_query(con, sql))
    {
        printf("calcula_descubierto() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("calcula_descubierto() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    num_rows = mysql_num_rows(result);

    printf("calcula_descubierto() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        saldo_descubierto = atof(row[0]);

        printf("calcula_descubierto() LOG descubierto = %f\n", saldo_descubierto);

        mysql_free_result(result);
        ret = saldo_descubierto;
    } else {
        ret = -1;
    }

    free(sql);
    return ret;
}

double calcula_saldo_anterior(MYSQL *con, char* card_number, char* codMoneda)
{
    double ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;
    double saldo_anterior;

    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("calcula_saldo_anterior(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1000;
    }

    // sprintf(sql, "SELECT saldo FROM sgas_usuario_cta WHERE nro_tarjeta='%s' "
    //     "AND fecha_operacion LIKE '%d-%02d-%%' AND prod_id='%s' ORDER BY
    //     ts_operacion DESC", card_number, (z.tm_year+1900), (z.tm_mon+1),
    //     codMoneda);

    // PARA CAMBIO DE CIERRE
    sprintf(sql,
            "SELECT saldo FROM sgas_usuario_cta WHERE nro_tarjeta='%s'  "
            "AND prod_id='%s' ORDER BY ts_operacion DESC",
            card_number, codMoneda);

    printf("calcula_saldo_anterior() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("calcula_saldo_anterior() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("calcula_saldo_anterior() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3000;
    }

    num_rows = mysql_num_rows(result);

    printf("calcula_saldo_anterior() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        saldo_anterior = atof(row[0]);

        printf("calcula_saldo_anterior() LOG saldo_anterior = %f\n", saldo_anterior);

        mysql_free_result(result);
        ret = saldo_anterior;
    } else {
        ret = -1.0;
    }

    free(sql);
    return ret;
}

double saldo_anterior_comercio(MYSQL *con, char* comer_id, char* codMoneda)
{
    double ret = 0.0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;
    double saldo_anterior;

    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("saldo_anterior_comercio(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sprintf(sql, "SELECT saldo FROM sgas_comercio_cta WHERE cod_comercio='%s'  "
        "AND fecha_operacion LIKE '%d-%02d-%%' AND prod_id='%s' ORDER BY ts_operacion desc",
        comer_id, (z.tm_year+1900), (z.tm_mon+1), codMoneda);

    printf("saldo_anterior_comercio() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("saldo_anterior_comercio() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("saldo_anterior_comercio() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    num_rows = mysql_num_rows(result);

    printf("saldo_anterior_comercio() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        saldo_anterior = atof(row[0]);

        printf("saldo_anterior_comercio() LOG saldo_anterior = %f\n", saldo_anterior);

        mysql_free_result(result);
        ret = saldo_anterior;
    } else {
        ret = 0.0;
    }

    free(sql);
    return ret;
}

int consulta_saldo(struct iso8583* iso)
{
    int ret = 0;
    MYSQL *con;
    double consumo;
    double consumo_acum;
    double consumo_vivo;
    double saldo_anterior;
    double saldo_final;
    int val_usr = 0;
    char csaldo[13];
    char cbuff[13];
    double prod_charge = 0.0;

    char* cNum;

    printf("consulta_saldo(): INIT \n");

    con = mysql_init(NULL);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL)
        //mysql_real_connect(con, MYDB_HOST, MYDB_USER, MYDB_PASS, MYDB_DB, 0, NULL, 0) == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    memset(csaldo, '\0', 13);
    memset(cbuff, '\0', 13);

    val_usr = valida_usuario(con, iso);
    if (val_usr != 0)
    {
        mysql_close(con);
        memset(iso->amount_4, '\0', 13);
        sprintf(iso->amount_4, "%012u", 0); // devuelve un importe
        return val_usr;
    }

    cNum = getCardNumber(iso);

    consumo_vivo = calcula_consumo_vivo(con, cNum, 0, iso);
    printf("consulta_saldo() LOG consumo_vivo = %f\n", consumo_vivo);
    if (consumo_vivo < -1000)
    {
        free(cNum);
        mysql_close(con);
        return -1;
    }

    consumo_acum = calcula_consumo_vivo_acum(con, cNum, 0, iso);
    printf("consulta_saldo() LOG consumo_vivo_acum = %f\n", consumo);
    if (consumo < -1000)
    {
        free(cNum);
        mysql_close(con);
        return -1;
    }

    consumo = consumo_vivo + consumo_acum;

    saldo_anterior = calcula_saldo_anterior(con, cNum, iso->currcode_49);
    printf("consulta_saldo() LOG saldo_anterior = %f\n", saldo_anterior);
    if(saldo_anterior < -1000)
    {
        free(cNum);
        mysql_close(con);
        return -1;
    }

    saldo_final = saldo_anterior - consumo;

    printf("consulta_saldo() LOG saldo_final = %f\n", saldo_final);

    if (saldo_final < 0)
    {
        saldo_final = 0.0;
    } else {
        prod_charge = getProdAmount(con, iso->currcode_49);
        double pchr = saldo_final / prod_charge;
        saldo_final = pchr;
    }

    sprintf(cbuff, "%f", saldo_final);

    printf("consulta_saldo() LOG saldo_final CBUFF = %s\n", saldo_final);

    char* ptr = strchr(cbuff, '.');
    *ptr='\0';
    memcpy(csaldo, cbuff, strlen(cbuff));

    printf("consulta_saldo() LOG saldo_final csaldo = %s\n", csaldo);
    csaldo[strlen(cbuff)] = *(ptr+1);
    csaldo[strlen(cbuff)+1] = *(ptr+2);

    printf("consulta_saldo() LOG saldo_final STR = %s\n", csaldo);

    memset(iso->amount_4, '\0', 13);
    sprintf(iso->amount_4, "%012u", atoi(csaldo)); // devuelve un importe

    printf("consulta_saldo() LOG saldo_final STR envio = %s\n", iso->amount_4);

    if ((consumo < 0) || (saldo_anterior < 0))
    {
        char* prods = getUserProds(con, cNum);

        if (prods != NULL)
        {
            rw_bitmap(63, iso->bitmap_1, 1);
            memset(iso->field_63, '\0', 100);
            sprintf(iso->field_63, "%s", prods);
            iso->length_63 = strlen(iso->field_63);
        }

        free(cNum);
        free(prods);

        ret = TRANS_OK;
    } else {
        char* prods = getUserProds(con, cNum);

        if (prods != NULL)
        {
            rw_bitmap(63, iso->bitmap_1, 1);
            memset(iso->field_63, '\0', 100);
            sprintf(iso->field_63, "%s", prods);
            iso->length_63 = strlen(iso->field_63);
        }

        free(cNum);
        free(prods);
        ret = TRANS_OK;
    }

    mysql_close(con);
    return ret;
}

int devolucion(struct iso8583* iso)
{
    int tk_max = 0;
    double tk_amount = 0.0;
    int tk_int_amount = 0;
    char* cNum;

	MYSQL *con = mysql_init(NULL);
    char* sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL)
        //mysql_real_connect(con, MYDB_HOST, MYDB_USER, MYDB_PASS, MYDB_DB, 0, NULL, 0) == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    tk_amount = getAmount(iso);

    if (validaIntMoneda(con, iso->currcode_49) == VALIDA_INT_OK)
    {
        tk_int_amount = (int)tk_amount;

        printf("devolucion() validaIntMoneda -> tk_int_amount = %d, tk_amount = %f \n", tk_int_amount, tk_amount);

        if (tk_int_amount != tk_amount)
        {
            free(sql_ins);
            mysql_close(con);
            return INVALID_AMOUNT;
        }
    }

    tk_max = validaCantidadTK(con, iso->currcode_49);
    if (tk_max > 0)
    {
        printf("devolucion() validaCantidadTK = %d, tk_int_amount = %d \n", tk_max, tk_int_amount);
        tk_int_amount = (int)tk_amount;

        if (tk_int_amount > tk_max)
        {
            free(sql_ins);
            mysql_close(con);
            return INVALID_AMOUNT;
        }
    }

    cNum = getCardNumber(iso);

    sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, cod_comercio, vencimiento, importe, "
      "codigo_autorizacion, refref, id_operacion, codigo_respuesta, terminalid, "
      "numero_comprobante, tipo_mensaje, cod_moneda, nro_tarjeta, lote, procode) values("
      "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, '%s', '%s', %f, '%s', '%s', %s, '%s', '%s', '%s', '%s', '%s', '%s', %d, '%s')",
       iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
       iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
       iso->merchid_42,
       getVencimiento(iso),
       (-1)*getAmount(iso),
       iso->authid_38,
       iso->retrefnum_37,
       iso->systracenum_11,
       iso->respcode_39,
       iso->termid_41,
       iso->field_62,
       iso->mtype,
       iso->currcode_49,
       cNum,
       getLoteID(iso),
       iso->procode_3
    );

    free(cNum);

    printf("devolucion() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -3;
    }

    free(sql_ins);
    mysql_close(con);
    return 0;
}

int reverso(struct iso8583* iso)
{
	MYSQL *con = mysql_init(NULL);
    char* sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);
    int ret=0;
    char* cNum;

    printf("reverso(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, 0) == NULL)
        //mysql_real_connect(con, MYDB_HOST, MYDB_USER, MYDB_PASS, MYDB_DB, 0, NULL, 0) == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    //ret = valida_cupon(con, iso, 1);
    ret = valida_cupon_reverso(con, iso);

    if (ret > 0)
    {
        int r_cp = reversa_cupon(con, iso);
        if (r_cp < 0)
        {
            free(sql_ins);
            return -1;
        }
    } else if (ret < 0){
        free(sql_ins);
        return -1;
    }

    cNum = getCardNumber(iso);

    if (iso->flag_ingenico == 0)
    {
        sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, cod_comercio, vencimiento, importe, "
            "codigo_autorizacion, refref, id_operacion, codigo_respuesta, terminalid, "
            "numero_comprobante, tipo_mensaje, cod_moneda, nro_tarjeta, lote, procode) values("
            "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, '%s', '%s', %f, '%s', '%s', %s, '%s', '%s', '%s', '%s', '%s', '%s', %d, '%s')",
            iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
            iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
            iso->merchid_42,
            getVencimiento(iso),
            getAmount(iso),
            iso->authid_38,
            iso->retrefnum_37,
            iso->systracenum_11,
            iso->respcode_39,
            iso->termid_41,
            iso->field_62,
            iso->mtype,
            iso->currcode_49,
            cNum,
            getLoteID(iso),
            iso->procode_3
        );
    } else{
        sprintf(sql_ins, "INSERT INTO sgas_cup(terminal_time, terminal_date, cant_cuotas, vencimiento, importe, "
            "codigo_autorizacion, codigo_respuesta, terminalid, "
            "numero_comprobante, tipo_mensaje, nro_tarjeta, procode, cod_comercio, cod_moneda) values("
            "'%c%c:%c%c:%c%c', '2018/%c%c/%c%c', 1, '%s', %f, "
            "'%s', '%s', '%s',"
            "%s, '%s', '%s', '%s', '%s', '%s')",
            iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
            iso->datetrx_13[0], iso->datetrx_13[1], iso->datetrx_13[2], iso->datetrx_13[3],
            getVencimiento(iso),
            getAmount(iso),
            iso->authid_38,
            iso->respcode_39,
            iso->termid_41,
            iso->systracenum_11,
            iso->mtype,
            cNum,
            iso->procode_3,
            iso->merchid_42,
            iso->currcode_49
        );
    }

    free(cNum);

    printf("reverso() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        free(sql_ins);
        mysql_close(con);
        return -3;
    }

    free(sql_ins);
    mysql_close(con);
    return 0;
}

char* getComercioByTerminalID(MYSQL* con, struct iso8583* iso)
{
    char* ret = NULL;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("getComercioByTerminalID(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return NULL;
    }

    sprintf(sql, "SELECT cod_comercio FROM terminales WHERE codigo_terminales='%s'", iso->termid_41 );
    if (mysql_query(con, sql))
    {
        printf("getComercioByTerminalID() ERROR: buscando comercio.");
        free(sql);
        return NULL;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getComercioByTerminalID() ERROR: buscando comercio.");
        free(sql);
        return NULL;
    }

    num_rows = mysql_num_rows(result);
    printf("getComercioByTerminalID() NUM_ROWS: %d\n", num_rows);
    if (num_rows != 0)
    {
        row = mysql_fetch_row(result);
        free(sql);
        return row[0];
    } else{
        ret = NULL;
    }

    mysql_free_result(result);
    free(sql);
    return ret;
}

int cierra_lote_efectivo(MYSQL *con, struct iso8583* iso, int cV, double tV, int cA, double tA, int cD, double tD)
{
    int ret = 0;
    int num_rows = 0;
    char  cod_comer[11];
    char* cod_com;
    char  n_envio[16];

    MYSQL_ROW row;
    MYSQL_RES *result;
    char* sql_aux;

    char* sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    printf("cierra_lote_efectivo() - INIT\n");

    printf("Comercio1: %s \n ", iso->merchid_42);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    printf("Comercio2: %s \n ", iso->merchid_42);

    sprintf(sql_ins, "INSERT INTO sgas_trx (cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,"
            "cant_cuotas,importe,codigo_autorizacion,refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,"
            "importe_resp,lote,numero_comprobante,anula_comprobante,comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion)"
            "( SELECT cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,cant_cuotas,importe,codigo_autorizacion,"
            "refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,importe_resp,lote,numero_comprobante,anula_comprobante,"
            "comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND cod_moneda='%s' AND cod_comercio='%s' "
            "ORDER BY ts_operacion ASC)",
            iso->termid_41,
            atoi(iso->field_60),
            iso->settcurrcode_50,
            iso->merchid_42
    );

    printf("cierra_lote_efectivo() - CUP -> TRX SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        printf("%s\n", mysql_error(con));
        return CIERRE_DIFF;
    }

    if(mysql_affected_rows(con) == 0)
    {
        return CIERRE_DIFF;
    }

    //Borro los cupones vivos para la terminalid, cod_moneda y lote.
    //memset(sql_ins, '\0', 1024);

    //sprintf(sql_ins, "DELETE FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND cod_moneda='%s' AND cod_comercio='%s'",
    //         iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

    //printf("cierra_lote_efectivo() - delete CUP SQL: %s\n", sql_ins);

    //if (mysql_query(con, sql_ins))
    //{
    //    fprintf(stderr, "%s\n", mysql_error(con));
    //    return -3;
    //}

    //if(mysql_affected_rows(con) == 0)
    //{
    //    return -3;
    //}

    //printf("Comercio4: %s \n ", iso->merchid_42);
    ///////////////////////////////////////////////////////////////////

    memset(sql_ins, '\0', 1024);

    sprintf(sql_ins, "INSERT INTO sgas_trx (terminal_time, terminal_date, "
        "terminalid, lote, marca_cierre,"
        "cant_ventas, total_ventas, cant_anul,"
        "total_anul, cant_devol, total_devol, tipo_mensaje, cod_moneda, cod_comercio) VALUES("
        " '%c%c:%c%c:%c%c', CURRENT_DATE() ,"
        " '%s', %d, 'Y', "
        " %d, %f, %d, "
        " %f, %d, %f , '0500', '%s', '%s')",
        iso->timetrx_12[0], iso->timetrx_12[1], iso->timetrx_12[2], iso->timetrx_12[3], iso->timetrx_12[4], iso->timetrx_12[5],
        iso->termid_41, atoi(iso->field_60),
        cV, tV, cA,
        tA, cD, tD,
        iso->settcurrcode_50,
        iso->merchid_42
    );

    printf("cierra_lote_efectivo() - INS TRX SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3;
    }

    memset(sql_ins, '\0', 1024);

    sprintf(sql_ins, "SELECT id, cod_comercio, cod_moneda, terminalid, lote, terminal_date, terminal_time, DATE_FORMAT(ts_operacion, '%%H:%%i:%%s') ttime FROM sgas_trx WHERE terminalid='%s' AND "
            "lote=%d AND terminal_date=CURRENT_DATE() AND cod_moneda='%s' AND tipo_mensaje='0500' AND cod_comercio='%s' order by id desc",
            iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42 );

    printf("cierra_lote_efectivo() - SEL TRX cierre_id SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        printf("cierra_lote_efectivo() ERROR: exec query.\n");
        free(sql_ins);
        return -3;
    }


    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("cierra_lote_efectivo() ERROR: store results.\n");
        free(sql_ins);
        return -3;
    } else {
        num_rows = mysql_num_rows(result);
        memset(n_envio, '\0', 16);

        row = mysql_fetch_row(result);
        memset(sql_ins, '\0', 1024);

        sprintf(n_envio, "%s", row[0]);

        sprintf(sql_ins, "UPDATE sgas_trx SET id_envio=%s WHERE "
                         "cod_comercio='%s' AND cod_moneda='%s' AND terminalid='%s' AND lote=%s AND "
                         "terminal_date='%s' AND DATE_FORMAT(ts_operacion, '%%H:%%i:%%s') <= '%s'",
        row[0], row[1], row[2], row[3], row[4], row[5], row[7]);

        if (num_rows > 1)
        {
            row = mysql_fetch_row(result);

            sql_aux = (char*)malloc(sizeof(char)*128);
            memset(sql_aux, '\0', 128);

            sprintf(sql_aux, " AND id>%s", row[0]);
            strcat(sql_ins, sql_aux);
        }

        printf("cierra_lote_efectivo() - TRX id_envio SQL: %s\n", sql_ins);

        if (mysql_query(con, sql_ins))
        {
            fprintf(stderr, "%s\n", mysql_error(con));
            return -3;
        }

        mysql_free_result(result);
    }

    memset(sql_ins, '\0', 1024);

    printf("Comercio3: %s \n ", iso->merchid_42);

    //sprintf(sql_ins, "INSERT INTO sgas_cup_trx (id, cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,"
    //        "cant_cuotas,importe,codigo_autorizacion,refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,"
    //        "importe_resp,lote,numero_comprobante,anula_comprobante,comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion)"
    //        "( SELECT id, cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,cant_cuotas,importe,codigo_autorizacion,"
    //        "refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,importe_resp,lote,numero_comprobante,anula_comprobante,"
    //        "comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion FROM sgas_trx WHERE terminalid='%s' AND lote=%d AND cod_moneda='%s' "
    //        "AND cod_comercio='%s' AND id_envio=%s "
    //        "AND terminal_date=CURRENT_DATE() AND id > (select if(max(id), max(id), 0) from sgas_cup_trx) "
    //        "ORDER BY ts_operacion ASC) ",
    //        iso->termid_41,
    //        atoi(iso->field_60),
    //        iso->settcurrcode_50,
    //        iso->merchid_42,
    //        n_envio
    //);

    //printf("cierra_lote_efectivo() Entro a SLEEP(40)... \n");
    //sleep(10);
    //printf("cierra_lote_efectivo() Salgo de SLEEP(40)... \n");

    sprintf(sql_ins, "INSERT INTO sgas_cup_trx (id, cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,"
            "cant_cuotas,importe,codigo_autorizacion,refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,"
            "importe_resp,lote,numero_comprobante,anula_comprobante,comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion)"
            "( SELECT id, cod_comercio,cod_moneda,terminal_time,terminal_date,vencimiento,cant_cuotas,importe,codigo_autorizacion,"
            "refref,id_operacion,procode,codigo_respuesta,terminalid,tipo_plan,importe_resp,lote,numero_comprobante,anula_comprobante,"
            "comentario_autorizacion,tipo_mensaje,nro_tarjeta, ts_operacion FROM sgas_trx WHERE tipo_mensaje!='0500' AND id_envio=%s "
            "AND id > (select if(max(id), max(id), 0) from sgas_cup_trx) "
            "ORDER BY ts_operacion ASC) ",
            n_envio
    );

    printf("cierra_lote_efectivo() - CUP -> CUP_TRX SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        printf("%s\n", mysql_error(con));
        return CIERRE_DIFF;
    }

    if(mysql_affected_rows(con) == 0)
    {
        return CIERRE_DIFF;
    }

    // Borro los cupones vivos para la terminalid, cod_moneda y lote.
    memset(sql_ins, '\0', 1024);

    sprintf(sql_ins, "DELETE FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND cod_moneda='%s' AND cod_comercio='%s'",
             iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

    printf("cierra_lote_efectivo() - delete CUP SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3;
    }

    if(mysql_affected_rows(con) == 0)
    {
        return -3;
    }

    printf("Comercio4: %s \n ", iso->merchid_42);
    ///////////////////////////////////////////////////////////////////

    free(sql_ins);
    return 0;
}

int getCierreVentas(MYSQL *con, struct iso8583* iso, int* cV, double* tV, int* cA, double* tA, int* cD, double* tD)
{
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;
    int cantVentas, cantDevol, cantAnul;
    double totVentas, totDevol, totAnul;

    char* sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    printf("getCierreVentas(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    // Total Ventas
    sprintf(sql, "SELECT count(*) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='000000' AND cod_moneda='%s' "
        "AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

    if (mysql_query(con, sql))
    {
        printf("getCierreVentas() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getCierreVentas() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    row = mysql_fetch_row(result);
    cantVentas = atoi(row[0]);
    printf("getCierreVentas() LOG cantVentas = %d\n", cantVentas);
    if(cantVentas == 0)
    {
        totVentas = 0.0;
    } else{
        mysql_free_result(result);

        sprintf(sql, "SELECT sum(importe) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='000000' AND cod_moneda='%s'"
            " AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

        if (mysql_query(con, sql))
        {
            printf("getCierreVentas() ERROR: exec query.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        result = mysql_store_result(con);
        if (result == NULL)
        {
            printf("getCierreVentas() ERROR: store results.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        row = mysql_fetch_row(result);
        totVentas = atof(row[0]);
    }

    printf("getCierreVentas() LOG totVentas = %f\n", totVentas);

    // Total Anulaciones
    mysql_free_result(result);

    sprintf(sql, "SELECT count(*) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='020000' AND cod_moneda='%s'"
        " AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

    if (mysql_query(con, sql))
    {
        printf("getCierreVentas() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getCierreVentas() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    row = mysql_fetch_row(result);
    cantAnul = atoi(row[0]);
    printf("getCierreVentas() LOG cantAnul = %d\n", cantAnul);
    if(cantAnul == 0)
    {
        totAnul = 0.0;
    } else{
        mysql_free_result(result);

        sprintf(sql, "SELECT sum(importe) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='020000' AND cod_moneda='%s'"
            " AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

        if (mysql_query(con, sql))
        {
            printf("getCierreVentas() ERROR: exec query.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        result = mysql_store_result(con);
        if (result == NULL)
        {
            printf("getCierreVentas() ERROR: store results.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        row = mysql_fetch_row(result);
        totAnul = atof(row[0]);
    }

    printf("getCierreVentas() LOG totAnul = %f\n", totAnul);

    // Total Devoluciones
    mysql_free_result(result);

    sprintf(sql, "SELECT count(*) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='200000' AND cod_moneda='%s'"
        " AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

    if (mysql_query(con, sql))
    {
        printf("getCierreVentas() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("getCierreVentas() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    row = mysql_fetch_row(result);
    cantDevol = atoi(row[0]);
    printf("getCierreVentas() LOG cantDevol = %d\n", cantDevol);
    if(cantDevol == 0)
    {
        totDevol = 0.0;
    } else{
        mysql_free_result(result);

        sprintf(sql, "SELECT sum(importe) FROM sgas_cup WHERE terminalid='%s' AND lote=%d AND tipo_mensaje='0200' AND procode='200000' AND cod_moneda='%s'"
            " AND cod_comercio='%s'",
        iso->termid_41, atoi(iso->field_60), iso->settcurrcode_50, iso->merchid_42);

        if (mysql_query(con, sql))
        {
            printf("getCierreVentas() ERROR: exec query.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        result = mysql_store_result(con);
        if (result == NULL)
        {
            printf("getCierreVentas() ERROR: store results.\n");
            free(sql);
            mysql_close(con);
            return -3;
        }

        row = mysql_fetch_row(result);
        totDevol = atof(row[0]);
    }

    printf("getCierreVentas() LOG totDevol = %f\n", totDevol);

    if (iso->flag_ingenico == 1)
    {
        printf("getCierreVentas() LOG es Ingenico = %d\n", iso->flag_ingenico);

        cantVentas = cantVentas - cantAnul;
        printf("getCierreVentas() LOG cantVentas = %d\n", cantVentas);

        totVentas = totVentas - totAnul;
        printf("getCierreVentas() LOG totVentas = %f\n", totVentas);

        cantAnul = 0;
        totAnul = 0.0;
    }

    *cV = cantVentas;
    *tV = totVentas;

    *cA = cantAnul;
    *tA = totAnul;

    *cD = cantDevol;
    *tD = totDevol;

    mysql_free_result(result);
    free(sql);
    return ret;
}

int cierre_lote(struct iso8583* iso)
{
    char* buff;
    int numLote;
    MYSQL *con;
    int ret = 0;
    int cantVentas, cantDevol, cantAnul;
    double totVentas, totDevol, totAnul;
    int cVentas, cDevol, cAnul;
    double tVentas, tDevol, tAnul;
    int flagVenta=-1, flagDevol=-1, flagAnul=-1;

    numLote = atoi(iso->field_60);

    printf("cierre_lote() LOG DATA_63 = %s\n", iso->field_63);
    printf("Comercio3: %s \n ", iso->merchid_42);


    buff = (char*)malloc(sizeof(char)*14);

    // VENTAS
    memset(buff, '\0', 14);
    memcpy(buff, iso->field_63, 3);
    cantVentas = atoi(buff);

    memset(buff, '\0', 14);
    memcpy(buff, &iso->field_63[3], 10);
    buff[10] = '.';
    memcpy(&buff[11], &iso->field_63[13], 2);
    totVentas = atof(buff);

    // DEVOLUCIONES
    memset(buff, '\0', 14);
    memcpy(buff, &iso->field_63[15], 3);
    cantDevol = atoi(buff);

    memset(buff, '\0', 14);
    memcpy(buff, &iso->field_63[18], 10);
    buff[10] = '.';
    memcpy(&buff[11], &iso->field_63[28], 2);
    totDevol = atof(buff);

    // ANULACIONES
    memset(buff, '\0', 14);
    memcpy(buff, &iso->field_63[30], 3);
    cantAnul = atoi(buff);

    memset(buff, '\0', 14);
    memcpy(buff, &iso->field_63[33], 10);
    buff[10] = '.';
    memcpy(&buff[11], &iso->field_63[43], 2);
    totAnul = atof(buff);

    printf("cierre_lote() LOG cantVentas = %d \n", cantVentas);
    printf("cierre_lote() LOG totVentas = %f \n", totVentas);

    printf("cierre_lote() LOG cantDevol = %d \n", cantDevol);
    printf("cierre_lote() LOG totDevol = %f \n", totDevol);

    printf("cierre_lote() LOG cantAnul = %d \n", cantAnul);
    printf("cierre_lote() LOG totAnul = %f \n", totAnul);

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

    ret = getCierreVentas(con, iso, &cVentas, &tVentas, &cAnul, &tAnul, &cDevol, &tDevol);
    if (ret < 0)
    {
        free(buff);
        mysql_close(con);
        return WRITE_ERROR;
    }

    printf("Comercio3 antes lote efectivo: %s \n ", iso->merchid_42);

    ret = cierra_lote_efectivo(con, iso, cVentas, tVentas, cAnul, tAnul, cDevol, tDevol);
    printf("cierre_lote() cierra_lote_efectivo ret = %d\n", ret);
    if (ret < 0)
    {
        free(buff);
        mysql_close(con);
        if (iso->flag_ingenico == 1)
        {
            return 0;
        }

        return CIERRE_DIFF;
    }

    if (ret > 0)
    {
        printf("cierre_lote() ERROR!!! LOTE CERRADO ret = %d\n", ret);
        free(buff);
        mysql_close(con);

        if (iso->flag_ingenico == 1)
        {
            return 0;
        }

        //return CIERRE_DIFF;
        return 0;
    }

    printf("\nTOTALES: \n----------------------------------------------------------------- \n");

    printf("cierre_lote() LOG cantVentas = %d \n", cantVentas);
    printf("cierre_lote() LOG totVentas = %f \n", totVentas);
    printf("cierre_lote() LOG cantDevol = %d \n", cantDevol);
    printf("cierre_lote() LOG totDevol = %f \n", totDevol);
    printf("cierre_lote() LOG cantAnul = %d \n", cantAnul);
    printf("cierre_lote() LOG totAnul = %f \n", totAnul);

    printf("cierre_lote() LOG cantVentas = %d \n", cVentas);
    printf("cierre_lote() LOG totVentas = %f \n", tVentas);
    printf("cierre_lote() LOG cantDevol = %d \n", cDevol);
    printf("cierre_lote() LOG totDevol = %f \n", tDevol);
    printf("cierre_lote() LOG cantAnul = %d \n", cAnul);
    printf("cierre_lote() LOG totAnul = %f \n", tAnul);

    printf("\n----------------------------------------------------------------- \n");
    // compara totales
    if ((cantVentas == cVentas) && (totVentas == tVentas))
    {
        flagVenta = 1;
    }

    if ((cantDevol == cDevol) && (totDevol == (tDevol*(-1)) ) )
    {
        flagDevol = 1;
    }

    if ((cantAnul == cAnul) && (totAnul == tAnul))
    {
        flagAnul = 1;
    }

    if ((flagAnul == 1) && (flagDevol == 1) && (flagVenta == 1))
    {
        printf("cierre_lote() flag CMP ret = %d\n", ret);

        if (ret == 0)
        {
            ret = TRANS_OK;
        }
    } else {
        if (iso->flag_ingenico == 1)
        {
            if (ret == 0)
            {
                ret = TRANS_OK;
            }
        } else {
            ret = CIERRE_DIFF;
        }

        if(!rw_bitmap(63,iso->bitmap_1,0))
        {
            rw_bitmap(63, iso->bitmap_1, 1);  // devuelvo msg error.
            memset(iso->field_63, '\0', 100);
            sprintf(iso->field_63, "Diferencias en Cierre Llame a Araucaria");
            iso->length_63 = strlen(iso->field_63);
        }
    }

    printf("cierre_lote() END ret = %d\n", ret);

    mysql_close(con);
    free(buff);
	return ret;
}

char* auth_genera_cvv(int ndoc)
{
	char* ret;
        char* lelong;
	int rnd;
        int stLen;
        int seed=ndoc+time(NULL);

	ret = (char*)malloc(sizeof(char)*4);
	memset(ret, '\0', 4);

        lelong = (char*)malloc(sizeof(char)*16);
        memset(lelong, '\0', 16);

        rnd = rand_r(&seed);

	printf("RAND = %d\n", rnd);
        printf("RAND 3 = %03d\n", rnd);

        sprintf(lelong, "%d", rnd);

        stLen = strlen(lelong);

        ret[0] = lelong[stLen-1];
        ret[1] = lelong[stLen-2];
        ret[2] = lelong[stLen-3];

	return ret;
}

int auth_write_cvv(MYSQL *con, char* cvv, char* ndoc)
{
	int ret = 0;
	char* sql;
	int num_rows;

       sql = (char*)malloc(sizeof(char)*1024);
       memset(sql, '\0', 1024);

	sprintf(sql, "UPDATE sgas_usuario SET cvv_actual='%s', cvv_renovacion='%s' WHERE nro_doc='%s' ", cvv, cvv, ndoc);

        printf("write_cvv() -> SQL = %s\n", sql);

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

int denuncia_perdida(struct iso8583* iso)
{
    MYSQL *con;
    char* sql_ins;
    int affec_rows;
    int num_rows;
    int ret = 0;
    MYSQL_ROW row;
    MYSQL_RES *result;

    char nombre[256];
    char cuenta[16];
    char call_sys[512];

    int rcvv;
    char* elrand;

    printf("denuncia_perdida(): INIT \n");

    con = mysql_init(NULL);

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (mysql_real_connect(con, aconf->dbHost, aconf->dbUser, aconf->dbPass, aconf->dbName, 0, NULL, CLIENT_MULTI_STATEMENTS) == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        mysql_close(con);
        return -2;
    }

    printf("denuncia_perdida(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sql_ins = (char*)malloc(sizeof(char)*1024);
    memset(sql_ins, '\0', 1024);

    sprintf(sql_ins, "UPDATE sgas_usuario SET marca_baja=1, fecha_situacion=CURRENT_DATE() WHERE nro_doc='%s' AND situacion!='P'", iso->field_61);

    printf("denuncia_perdida() - SQL: %s\n", sql_ins);

    if (mysql_query(con, sql_ins))
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -3;
    }

    affec_rows = mysql_affected_rows(con);
    if (affec_rows <= 0)
    {
        ret = TIT_DES_SUP;
        free(sql_ins);
        printf("denuncia_perdida() - ERROR en marca_baja -> 1...\n");
        return ret;

    } else{
        memset(sql_ins, '\0', 1024);
        sprintf(sql_ins, "SELECT nro_tarjeta, cast(concat(sucursal, num_cta) as unsigned) cuenta, apellido_nombre "
                         "FROM sgas_usuario WHERE nro_doc='%s'", iso->field_61);

        if (mysql_query(con, sql_ins))
        {
            printf("denuncia_perdida() ERROR: exec SQL. \n");
            free(sql_ins);
            return -3;
        }

        printf("denuncia_perdida() - SQL . \n");

        result = mysql_store_result(con);
        if (result == NULL)
        {
            printf("denuncia_perdida() ERROR: store results. \n");
            free(sql_ins);
            return -3;
        }

        num_rows = mysql_num_rows(result);
        if (num_rows > 0)
        {
            row = mysql_fetch_row(result);

            memset(nombre, '\0', 256);
            memset(cuenta, '\0', 16);

            sprintf(nombre, "%s", row[2]);
            sprintf(cuenta, "%s", row[1]);

            mysql_free_result(result);

            memset(sql_ins, '\0', 1024);
            sprintf(sql_ins, "UPDATE sgas_usuario SET vigencia_desde=DATE_FORMAT(CURRENT_DATE(), '%%Y-%%m-01'), "
                             "vigencia_hasta=DATE_ADD(DATE_FORMAT(CURRENT_DATE(), '%%Y-%%m-01'), INTERVAL 2 YEAR) WHERE nro_doc='%s'"
            , iso->field_61);

            printf("denuncia_perdida() - SQL: %s\n", sql_ins);

            if (mysql_query(con, sql_ins))
            {
                fprintf(stderr, "%s\n", mysql_error(con));
                return -3;
            }

            affec_rows = mysql_affected_rows(con);
            if (affec_rows < 0)
            {
                ret = TIT_DES_SUP;
                free(sql_ins);
                printf("denuncia_perdida() - ERROR en vigencia_hasta...\n");
                return ret;
            }

            memset(sql_ins, '\0', 1024);
            sprintf(sql_ins, "UPDATE sgas_usuario SET marca_baja=0 WHERE nro_doc='%s'", iso->field_61);

            printf("denuncia_perdida() - SQL: %s\n", sql_ins);

            if (mysql_query(con, sql_ins))
            {
                fprintf(stderr, "%s\n", mysql_error(con));
                return -3;
            }

            affec_rows = mysql_affected_rows(con);
            if (affec_rows < 0)
            {
                ret = TIT_DES_SUP;
                free(sql_ins);
                printf("denuncia_perdida() - ERROR en marca_baja -> 0...\n");
                return ret;
            }

	    // CAMBIO DE CVV
            printf("denuncia_perdida() -> llamando a genera_cvv() DNI = %s\n", iso->field_61);
            elrand = auth_genera_cvv(atoi(iso->field_61));
            printf("denuncia_perdida() -> llamando a write_cvv() random = %s\n", elrand);
            rcvv = auth_write_cvv(con, elrand, iso->field_61);
            printf("denuncia_perdida() -> llamando a write_cvv() ret = %d\n", rcvv);
            if (rcvv != 0)
            {
               ret = TIT_DES_SUP;
               free(sql_ins);
               printf("denuncia_perdida() - ERROR en marca_baja -> 0...\n");
               return ret;
            }
	    //

            // call procedure
            memset(sql_ins, '\0', 1024);
            //sprintf(sql_ins, "call gen_mod2(%s)", cuenta);
            sprintf(sql_ins, "call gen_mod2_cvv(%s)", cuenta);

            mysql_set_server_option(con, MYSQL_OPTION_MULTI_STATEMENTS_ON);

            printf("denuncia_perdida() - SQL: %s\n", sql_ins);

            if (mysql_query(con, sql_ins))
            {
                fprintf(stderr, "%s\n", mysql_error(con));
                return -3;
            }

            affec_rows = mysql_affected_rows(con);
            if (affec_rows < 0)
            {
                ret = TIT_DES_SUP;
                free(sql_ins);
                printf("denuncia_perdida() - ERROR en marca_baja -> 0...\n");
                return ret;
            }

            mysql_set_server_option(con, MYSQL_OPTION_MULTI_STATEMENTS_OFF);

            memset(call_sys, '\0', 512);
            sprintf(call_sys, "./sender %s \"%s\"", cuenta, nombre);

            system(call_sys);

        } else {
            ret = TIT_DES_SUP;
            free(sql_ins);
            printf("denuncia_perdida() - ERROR en BBDD...\n");
            return ret;
        }
    }

    printf("denuncia_perdida() - END\n");
    return ret;
}

// COMMON

int getLoteID(struct iso8583* iso)
{
    int loteId = -1;

    if (iso->flag_ingenico == 1)
    {
        printf("FIELD_63 LOTE: %s, %d\n", &iso->field_63[11], atoi(&iso->field_63[11]) );
        loteId = atoi(&iso->field_63[4]);
    } else {
        printf("FIELD_63 LOTE: %s, %d\n", &iso->field_63[11], atoi(&iso->field_63[11]) );
        loteId = atoi(&iso->field_63[11]);
    }
    return loteId;
}

//char getProduct(struct iso8583* iso)
char* getProduct(struct iso8583* iso)
{
    printf("FIELD_49 PRODUCT (cod moneda): %s\n", iso->currcode_49);
    return iso->currcode_49;
}

char* getVencimiento(struct iso8583* iso)
{
    char* vto;

    if (atoi(iso->posentrymode_22) == 12)
    {
        // set manual
        vto = iso->dateexpire_14;
    }

    if (atoi(iso->posentrymode_22) == 22)
    {
        //vto = (char*)malloc(sizeof(char)*5);
        //memcpy(vto, &iso->track2_35[17], 4);
        //vto[4] = '\0';
        vto = &iso->track2_35[17];
    }

    return vto;
}

char* getCardNumber(struct iso8583* iso)
{
    char* cnum;

    if (atoi(iso->posentrymode_22) == 12)
    {
        printf("PosEntryMode = %d\n", atoi(iso->posentrymode_22));
        printf("PAN_2 = %s\n", iso->pan_2);

        cnum = (char*) malloc(sizeof(char)*21);
        memset(cnum, '\0', 21);
        memcpy(cnum, iso->pan_2, 16);
    }

    if (atoi(iso->posentrymode_22) == 22)
    {
        printf("PosEntryMode = %d\n", atoi(iso->posentrymode_22));
        cnum = (char*)malloc(sizeof(char)*21);
        memset(cnum, '\0', 21);
        memcpy(cnum, iso->track2_35, 16);
    }

    return cnum;
}

double getAmount(struct iso8583* iso)
{
    double amount;
    char camount[14];

    memset(camount, '\0', 14);

    //if( ( ( atoi(iso->procode_3) == 20000) && (strcmp(iso->mtype,"0200") == 0) ) || (iso->flag_ingenico == 1))
    if ( atoi(iso->procode_3) == 20000)
    {
        memcpy(camount, iso->field_60, 10);
        camount[10] = '.';
        memcpy(&camount[11], &iso->field_60[10], 2);
        amount = atof(camount);
    } else if(atoi(iso->procode_3) == 50000 ){
        memcpy(camount, iso->field_60, 10);
        camount[10] = '.';
        memcpy(&camount[11], &iso->field_60[10], 2);
        amount = atof(camount);
    } else {
        memcpy(camount, iso->amount_4, 10);
        camount[10] = '.';
        memcpy(&camount[11], &iso->amount_4[10], 3);
        amount = atof(camount);
    }
    return amount;
}

char* retcode_to_str(int err_code)
{
    char* ec = (char*)malloc(sizeof(char)*3);

    memset(ec, '\0', 3);
    sprintf(ec, "%02u", err_code);

    return ec;
}

int informa_subsidio(MYSQL* con, struct iso8583* iso) {
    double precio_kg_gas = 0.0, coef_benef, monto_benef, coef_prov, monto_prov, coef_nac, monto_nac;
    char* cNum;
    char* sql;
    double amount;
    MYSQL_ROW row;
    MYSQL_RES *result;
    int num_rows;


    cNum = getCardNumber(iso);
    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);

    sprintf(sql, "SELECT sc.precio_kg_gas, sc.coef_benef, sc.monto_benef, sc.coef_prov, sc.monto_prov, sc.coef_nac, sc.monto_nac FROM soli_categories sc JOIN sgas_usuario_expansion sue ON sue.categoria_id = sc.id WHERE sue.nro_tarjeta = '%s'", cNum );
    if (mysql_query(con, sql))
    {
        free(sql);
        return -1;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        free(sql);
        return -1;
    }

    num_rows = mysql_num_rows(result);
    if (!num_rows) {
        mysql_free_result(result);
        free(sql);
        return 0;
    }

    row = mysql_fetch_row(result);
    precio_kg_gas = strtod(row[0], NULL);
    coef_benef = strtod(row[1], NULL);
    monto_benef = strtod(row[2], NULL);
    coef_prov = strtod(row[3], NULL);
    monto_prov = strtod(row[4], NULL);
    coef_nac = strtod(row[5], NULL);
    monto_nac = strtod(row[6], NULL);

    mysql_free_result(result);
    free(sql);

    amount = getAmount(iso);

    rw_bitmap(63,iso->bitmap_1,1);
    memset(iso->field_63, '\0', 100);
    sprintf(iso->field_63, "MONTO A PAGAR BENEFICIARIO %10.2lf   Subsidio Prov. %5.1lf%%. Nacion %5.1lf%%", monto_benef*amount, coef_prov*100, coef_nac*100);
    iso->length_63=strlen(iso->field_63);
    return 0;
}

int obtieneUltimaRecarga(MYSQL* con, char* card_number, char* codMoneda, double* montoUltimaRecarga) {
    char* sql;
    MYSQL_ROW row;
    MYSQL_RES *result;

    printf("obtieneUltimaRecarga(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);
    sprintf(sql, "select importe*(-1) from sgas_usuario_cta suc "
                 "where suc.nro_tarjeta = '%s' "
                 "and suc.prod_id = %s "
                 "and suc.importe < 0 "
                 "order by suc.ts_operacion desc "
                 "limit 1",
            card_number, codMoneda);

    printf("obtieneUltimaRecarga() - SQL: %s\n", sql);

    if (mysql_query(con, sql))
    {
        printf("obtieneUltimaRecarga() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }
    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("obtieneUltimaRecarga() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }
    if (mysql_num_rows(result) != 1) {
        mysql_free_result(result);
        free(sql);
        mysql_close(con);
        return -5;
    }
    row = mysql_fetch_row(result);
    *montoUltimaRecarga = strtod(row[0], NULL);

    printf("obtieneUltimaRecarga() - UltimaRecarga: %s\n", row[0]);
    mysql_free_result(result);
    free(sql);

    return 0;
}

int validaTiempoUltimaVenta(MYSQL* con, char* card_number, char* codMoneda) {
    char* sql;
    MYSQL_RES *result;
    int num_rows;
    int horas_min;

    printf("validaTiempoUltimaVenta(): INIT \n");

    if (con == NULL)
    {
        fprintf(stderr, "%s\n", mysql_error(con));
        return -1;
    }

    if (obtieneConfiguracion(con, "venta_min_horas_ultima_venta", NULL, &horas_min)) {
        return -1;
    }

    sql = (char*)malloc(sizeof(char)*1024);
    memset(sql, '\0', 1024);
    sprintf(sql, "select 1 from ( "
                 "select sc.ts_operacion from sgas_cup sc "
                 "where sc.nro_tarjeta = '%s' "
                 "and sc.cod_moneda = %s "
                 "and sc.tipo_mensaje = '0200' "
                 "and sc.procode = '000000' "
                 "and sc.ts_operacion > DATE_SUB(NOW(), INTERVAL %d HOUR) "
                 "and not exists ( "
                     "select 1 from sgas_cup sc2 "
                     "where sc.numero_comprobante = sc2.anula_comprobante "
                     "and sc.nro_tarjeta = sc2.nro_tarjeta "
                     "and sc.tipo_mensaje = sc2.tipo_mensaje "
                     "and sc.cod_moneda = sc2.cod_moneda "
                     "and sc2.procode in ('020000', '050000') "
                 ") "
                 "union all "
                 "select sct.ts_operacion from sgas_cup_trx sct "
                 "where sct.nro_tarjeta = '%s' "
                 "and sct.cod_moneda = %s "
                 "and sct.tipo_mensaje = '0200' "
                 "and sct.procode = '000000' "
                 "and sct.ts_operacion > DATE_SUB(NOW(), INTERVAL %d HOUR) "
                 "and not exists ( "
                     "select 1 from sgas_cup_trx sct2 "
                     "where sct.numero_comprobante = sct2.anula_comprobante "
                     "and sct.nro_tarjeta = sct2.nro_tarjeta "
                     "and sct.tipo_mensaje = sct2.tipo_mensaje "
                     "and sct.cod_moneda = sct2.cod_moneda "
                     "and sct2.procode in ('020000', '050000') "
                 ") "
                 ") as cups",
            card_number, codMoneda, horas_min, card_number, codMoneda, horas_min);

    printf("validaTiempoUltimaVenta() - SQL: %s\n", sql);
    if (mysql_query(con, sql))
    {
        printf("validaTiempoUltimaVenta() ERROR: exec query.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL)
    {
        printf("validaTiempoUltimaVenta() ERROR: store results.\n");
        free(sql);
        mysql_close(con);
        return -3;
    }
    num_rows = mysql_num_rows(result);
    printf("validaTiempoUltimaVenta() - NumRows: %d\n", num_rows);
    mysql_free_result(result);
    free(sql);

    return num_rows;
}

/**
 * Obtiene la configuración por nombre y retorna los valores char e int.
 * @param con: Puntero a la conexión activa de MySQL.
 * @param name: Nombre de la configuración a buscar.
 * @param out_val_char: Puntero a buffer donde se copiará el string (debe estar
 * pre-asignado).
 * @param out_val_int: Puntero a entero donde se guardará el valor numérico.
 * @return 0 si es exitoso, negativo en caso de error.
 */
int obtieneConfiguracion(MYSQL *con, const char *name, char *out_val_char, int *out_val_int) {
    char sql[1024]; 
    MYSQL_ROW row;
    MYSQL_RES *result;

    printf("obtieneConfiguracion(): INIT para '%s'\n", name);

    if (con == NULL) {
      fprintf(stderr, "%s\n", mysql_error(con));
      return -1;
    }

    // Limpiamos los buffers de salida por seguridad
    if (out_val_char)
        out_val_char[0] = '\0';
    if (out_val_int)
        *out_val_int = 0;

    // Construcción segura de la query
    snprintf(
        sql, sizeof(sql),
        "SELECT val_char, val_int FROM soli_config WHERE name = '%s'",
        name);

    printf("obtieneConfiguracion() - SQL: %s\n", sql);

    if (mysql_query(con, sql)) {
        fprintf(stderr, "obtieneConfiguracion() ERROR: %s\n", mysql_error(con));
        return -3;
    }

    result = mysql_store_result(con);
    if (result == NULL) {
      printf("obtieneConfiguracion() ERROR: store results.\n");
      return -3;
    }

    // Verificamos si existe el registro
    if (mysql_num_rows(result) != 1) {
      mysql_free_result(result);
      return -5;
    }

    row = mysql_fetch_row(result);

    // Mapeo a los punteros de salida
    if (row[0] != NULL && out_val_char != NULL) {
        // Usamos strncpy para no desbordar el buffer de destino (asumimos 255 por
        // tu tabla)
        strncpy(out_val_char, row[0], 255);
        out_val_char[255] = '\0'; // Asegurar terminador nulo
    }

    if (row[1] != NULL && out_val_int != NULL) {
        *out_val_int = atoi(row[1]);
    }

    printf("obtieneConfiguracion(): EXIT SUCCESS [%s, %d]\n",
            row[0] ? row[0] : "NULL", row[1] ? atoi(row[1]) : 0);

    mysql_free_result(result);
    return 0;
}
