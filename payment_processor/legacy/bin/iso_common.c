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

#include "auth_kig.h"

/*
Nombre: tlog
Descripción: Concatena las cadena referenciadas junto al timestamp y agrega una linea en el archivo de texto ARCHIVO_LOGS, si no existe el archivo lo crea,
y si no logra abriril o crearlo sale del programa.
Parametros: Se le pasan los punteros a las cadena que conformaran la linea.
Devolución: Devuelve un entero de resultado 0 o -1 si no pudo abrir el archivo de logs.
*/
int tlog(char *str1,char *str2,char *str3)
{
    char linea[1862],fecha_hora[22];
    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);
    sprintf(fecha_hora,"[%02d-%02d-%04d %02d:%02d:%02d]",z.tm_mday,z.tm_mon+1,z.tm_year+1900,z.tm_hour,z.tm_min,z.tm_sec);
    sprintf(linea,"%s %s %s %s",fecha_hora,str1,str2,str3);

    FILE *fp;
    fp=fopen(ARCHIVO_LOGS,"a+");
    if(fp==0)
    {
        fprintf(stderr,"Error al abrir el archivo %s \n",ARCHIVO_LOGS);
        return -1;
    }
    fprintf(fp,"%s\n",linea);
    fclose(fp);
    return 0;
}
/*
Nombre:
packunpack_iso
Descripción: Descompone o compone la cadena pasada como argumento segun en la estructura de campos de la norma iso8583, con longitud total en hexa.
Paramtros: Se le pasa el puntero a la cadena que contiene el mensaje, el puntero a la estructura donde se almacenan los campos, un entero igual a 0 para hacer
el empaquetado de la trama o igual a 1 para hacer el desempaquetado de la trama, y por ultimo un entero igual a 1 si se quiere volcar el contenido de los campos al log.
Devolución: En la funcion de empaquetar devuelve la longitud de la trama armada incluyendo en esta los dos bytes de longitud. En la funcion desempaquetar devuelve un
-1 si no logro desarmar con exito el mensaje o 0 si se desempaqueto correctamente.
*/
int packunpack_iso(char *msg, struct iso8583 *iso,int packunpack,int debug)
{
    int i,j,k,l;
    char a,b,aux[20],inout[]="(out)";//longitud igual a la mayor de los campos en bcd, en este caso es el campo 35 con 19 bytes + \0
    if(packunpack) strcpy(inout,"(in)");//si esta haceindo el unpack pone in en el log
    /*
    El indice j representa la posición absoluta en la trama ISO, por ende apunta siempre al primer elemento que se va a leer.
    El indice k representa la longitud del campo a leer.
    */
    j=2;//apunta al primer elemento despues de la longitud de la trama ISO
    if(packunpack)
    {
	k=5;//el tpdu tiene una longitud de 5 bytes
	for(i=j;i<j+k;i++) aux[i-j]=msg[i];//copia los k bytes del tpdu despues de la longitud
	bcd_to_asc(2*k,aux,iso->tpdu);//convierte a string ascii
    }
    else
    {
	k=asc_to_bcd(iso->tpdu,aux);//convierte a bcd y guarda la longitud a copiar
	for(i=j;i<j+k;i++) msg[i]=aux[i-j];//copia los k bytes
    }
    j=i;//guarda la posicion absoluta en la trama
    if(debug) tlog("Debug: iso TPDU:",iso->tpdu,inout);
    if(packunpack)
    {
	k=2;//el mtype tiene una longitud de 2 bytes
	for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	bcd_to_asc(2*k,aux,iso->mtype);
    }
    else
    {
	k=asc_to_bcd(iso->mtype,aux);
	for(i=j;i<j+k;i++) msg[i]=aux[i-j];
    }
    j=i;
    if(debug) tlog("Debug: iso MESSAGE TYPE:",iso->mtype,inout);
    if(packunpack)
    {
	k=8;//el bitmap tiene una longitud de 8 bytes
	for(i=j;i<j+k;i++) iso->bitmap_1[i-j]=msg[i];
    }
    else
    {
	k=8;//el bitmap siempre es binario y tiene longitud fija
	for(i=j;i<j+k;i++) msg[i]=iso->bitmap_1[i-j];
    }
    j=i;
    /*aqui comienza la composicion/ descomposicion campo a campo segun atributos y longitudes de cada campo*/
    if(rw_bitmap(2,iso->bitmap_1,0))//pregunta si esta presente el PAN
    {
	if(packunpack)
	{
	    l=longitude_to_int('b',0x00,msg[j]);//obtengo longitud del campo como entero, ya que es bcd
	    if(l>19) l=19;//longitud maxima por corrimientos de parseo
	    j++;//adelanta j al primer elemento del campo
	    k=(l/2)+(l%2);//obtengo la longitud en bytes a leer, como la suma de la division entera mas el resto (ej l=13, a=7) y le sumo el valor de donde quedo i
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];//copia los k bytes
	    bcd_to_asc(l,aux,iso->pan_2);
	}
	else
	{
	    int_to_longitude('b',strlen(iso->pan_2),&a,&b);//convierte la longitud de entero a bcd, parte alta en a y parte baja en b
	    msg[j]=b;//copia la longitud antes del campo
	    k=asc_to_bcd(iso->pan_2,aux);//convierte a bcd y guarda la longitud a copiar
	    j++;//apunta al primer element del campo
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];//copia los k bytes
	}
	j=i;
	if(debug) tlog("Debug: iso PRIMARY ACCOUNT NUMBER:",iso->pan_2,inout);
    }
    if(rw_bitmap(3,iso->bitmap_1,0))//pregunta si esta presente el procesing code
    {
	if(packunpack)
	{
	    k=3;//tiene una longitud de 3 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->procode_3);
	}
	else
	{
	    k=asc_to_bcd(iso->procode_3,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso POROCESSING CODE:",iso->procode_3,inout);
    }
    if(rw_bitmap(4,iso->bitmap_1,0))//pregunta si esta presente el amount of transaction
    {
	if(packunpack)
	{
	    k=6;//tiene una longitud de 6 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->amount_4);
	}
	else
	{
	    k=asc_to_bcd(iso->amount_4,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso AMOUNT OF TRANSACTION:",iso->amount_4,inout);
    }
    if(rw_bitmap(11,iso->bitmap_1,0))//pregunta si esta presente el system trace number
    {
	if(packunpack)
	{
	    k=3;//tiene una longitud de 3 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->systracenum_11);
	}
	else
	{
	    k=asc_to_bcd(iso->systracenum_11,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso SYSTEM TRACE NUMBER:",iso->systracenum_11,inout);
    }
    if(rw_bitmap(12,iso->bitmap_1,0))//pregunta si esta presente el time of transaction
    {
	if(packunpack)
	{
	    k=3;//tiene una longitud de 3 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->timetrx_12);
	}
	else
	{
	    k=asc_to_bcd(iso->timetrx_12,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso TIME OF TRANSACITION:",iso->timetrx_12,inout);
    }
    if(rw_bitmap(13,iso->bitmap_1,0))//pregunta si esta presente el date of transaction
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
    	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
    	    bcd_to_asc(2*k,aux,iso->datetrx_13);
	}
	else
	{
	    k=asc_to_bcd(iso->datetrx_13,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}

	j=i;
	if(debug) tlog("Debug: iso DATE OF TRANSACTION:",iso->datetrx_13,inout);
    }
    if(rw_bitmap(14,iso->bitmap_1,0))//pregunta si esta presente el date expiration
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->dateexpire_14);
	}
	else
	{
	    k=asc_to_bcd(iso->dateexpire_14,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso EXPIRATION DATE:",iso->dateexpire_14,inout);
    }
    if(rw_bitmap(15,iso->bitmap_1,0))//pregunta si esta presente el settlement date
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->datesettle_15);
	}
	else
	{
	    k=asc_to_bcd(iso->datesettle_15,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso SETTLEMENT DATE:",iso->datesettle_15,inout);
    }
    if(rw_bitmap(22,iso->bitmap_1,0))//pregunta si esta presente el pos entry mode
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->posentrymode_22);
	}
	else
	{
	    k=asc_to_bcd(iso->posentrymode_22,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso POS ENTRY MODE:",iso->posentrymode_22,inout);
    }
    if(rw_bitmap(24,iso->bitmap_1,0))//pregunta si esta presente el NII
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->nii_24);
	}
	else
	{
	    k=asc_to_bcd(iso->nii_24,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso NETWORK INTERNATIONAL IDENTIFIER:",iso->nii_24,inout);
    }
    if(rw_bitmap(25,iso->bitmap_1,0))//pregunta si esta presente el pos condition code
    {
	if(packunpack)
	{
	    k=1;//tiene una longitud de 1 byte
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(2*k,aux,iso->poscondcode_25);
	}
	else
	{
	    k=asc_to_bcd(iso->poscondcode_25,aux);
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso POS CONDITION CODE:",iso->poscondcode_25,inout);
    }
    if(rw_bitmap(35,iso->bitmap_1,0))//pregunta si esta presente el track 2
    {
	if(packunpack)
	{
	    l=longitude_to_int('b',0x00,msg[j]);
	    if(l>37) l=37;//longitud maxima por corrimientos de parseo
	    j++;
	    k=(l/2)+(l%2);
	    for(i=j;i<j+k;i++) aux[i-j]=msg[i];
	    bcd_to_asc(l,aux,iso->track2_35);
	}
	else
	{
	    int_to_longitude('b',strlen(iso->track2_35),&a,&b);
	    msg[j]=b;
	    k=asc_to_bcd(iso->track2_35,aux);
	    j++;
	    for(i=j;i<j+k;i++) msg[i]=aux[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso TRACK II DATA:",iso->track2_35,inout);
    }
    if(rw_bitmap(37,iso->bitmap_1,0))//pregunta si esta presente el retrieval reference number que es ascii
    {
	if(packunpack)
	{
	    k=12;//tiene una longitud de 12 bytes
	    for(i=j;i<j+k;i++) iso->retrefnum_37[i-j]=msg[i];
	    iso->retrefnum_37[k]='\0';
	}
	else
	{
	    k=strlen(iso->retrefnum_37);
	    for(i=j;i<j+k;i++) msg[i]=iso->retrefnum_37[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso RETRIEVAL REFERENCE NUMBER:",iso->retrefnum_37,inout);
    }
    if(rw_bitmap(38,iso->bitmap_1,0))//pregunta si esta presente el authorization id que es ascii
    {
	if(packunpack)
	{
	    k=6;//tiene una longitud de 6 bytes
	    for(i=j;i<j+k;i++) iso->authid_38[i-j]=msg[i];
	    iso->authid_38[k]='\0';
	}
	else
	{
	    k=strlen(iso->authid_38);
	    for(i=j;i<j+k;i++) msg[i]=iso->authid_38[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso AUTHORIZATION ID:",iso->authid_38,inout);
    }
    if(rw_bitmap(39,iso->bitmap_1,0))//pregunta si esta presente el response code que es ascii
    {
	if(packunpack)
	{
	    k=2;//tiene una longitud de 2 bytes
	    for(i=j;i<j+k;i++) iso->respcode_39[i-j]=msg[i];
	    iso->respcode_39[k]='\0';
	}
	else
	{
	    k=strlen(iso->respcode_39);
	    for(i=j;i<j+k;i++) msg[i]=iso->respcode_39[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso RESPONSE CODE:",iso->respcode_39,inout);
    }
    if(rw_bitmap(41,iso->bitmap_1,0))//pregunta si esta presente el terminal id que es ascii
    {
	if(packunpack)
	{
	    k=8;//tiene una longitud de 2 bytes
    	    for(i=j;i<j+k;i++) iso->termid_41[i-j]=msg[i];
	    iso->termid_41[k]='\0';
	}
	else
	{
	    k=strlen(iso->termid_41);
    	    for(i=j;i<j+k;i++) msg[i]=iso->termid_41[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso TERMINAL ID:",iso->termid_41,inout);
    }
    if(rw_bitmap(42,iso->bitmap_1,0))//pregunta si esta presente el merchant id que es ascii
    {
	if(packunpack)
	{
	    k=15;//tiene una longitud de 15 bytes
	    for(i=j;i<j+k;i++) iso->merchid_42[i-j]=msg[i];
	    iso->merchid_42[k]='\0';
	}
	else
	{
	    k=strlen(iso->merchid_42);
	    for(i=j;i<j+k;i++) msg[i]=iso->merchid_42[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso MERCHANT ID:",iso->merchid_42,inout);
    }
    if(rw_bitmap(45,iso->bitmap_1,0))//pregunta si esta presente el track 1 que es ascii
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',0x00,msg[j]);
	    if(k>76) k=76;//longitud maxima por corrimientos de parseo
	    j++;
	    for(i=j;i<j+k;i++) iso->track1_45[i-j]=msg[i];
	    iso->track1_45[k]='\0';
	}
	else
	{
	    k=strlen(iso->track1_45);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=b;
	    j++;
	    for(i=j;i<j+k;i++) msg[i]=iso->track1_45[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso TRACK I DATA:",iso->track1_45,inout);
    }
    if(rw_bitmap(49,iso->bitmap_1,0))//pregunta si esta presente el currency code que es ascii
    {
	if(packunpack)
	{
	    k=3;//tiene una longitud de 3 bytes
	    for(i=j;i<j+k;i++) iso->currcode_49[i-j]=msg[i];
	    iso->currcode_49[k]='\0';
	}
	else
	{
	    k=strlen(iso->currcode_49);
	    for(i=j;i<j+k;i++) msg[i]=iso->currcode_49[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso CURRENCY CODE:",iso->currcode_49,inout);
    }
    if(rw_bitmap(50,iso->bitmap_1,0))//pregunta si esta presente el settlement currency code que es ascii
    {
	if(packunpack)
	{
	    k=3;//tiene una longitud de 3 bytes
	    for(i=j;i<j+k;i++) iso->settcurrcode_50[i-j]=msg[i];
	    iso->settcurrcode_50[k]='\0';
	}
	else
	{
	    k=strlen(iso->settcurrcode_50);
	    for(i=j;i<j+k;i++) msg[i]=iso->settcurrcode_50[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso SETTLEMENT CURRENCY CODE:",iso->settcurrcode_50,inout);
    }
    if(rw_bitmap(54,iso->bitmap_1,0))//pregunta si esta presente el adicional amounts que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);
	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;
	    for(i=j;i<j+k;i++) iso->addamount_54[i-j]=msg[i];
	    iso->addamount_54[k]='\0';
	}
	else
	{
	    k=strlen(iso->addamount_54);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
    	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->addamount_54[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso ADDITIONAL AMOUNTS:",iso->addamount_54,inout);
    }

    if(rw_bitmap(55,iso->bitmap_1,0)) // pregunta si esta presente el campo 55 (CVV)
    {
                                      // que es ascii precedido de dos bytes con la longitud neta en bcd
    if(packunpack)
    {
      k=longitude_to_int('b',msg[j],msg[j+1]);
      if(k>99) k=99;//longitud maxima por corrimientos de parseo
      j=j+2;
      for(i=j;i<j+k;i++) iso->cvv_55[i-j]=msg[i];
      iso->cvv_55[k]='\0';
    } else {
      k=strlen(iso->cvv_55);
      int_to_longitude('b',k,&a,&b);
      msg[j]=a;
      msg[j+1]=b;
      j=j+2;
      for(i=j;i<j+k;i++) msg[i]=iso->cvv_55[i-j];
    }
      j=i;
      if(debug) tlog("Debug: ISO CVV 55 DATA:", iso->cvv_55, inout);
    }

    if(rw_bitmap(59,iso->bitmap_1,0))//pregunta si esta presente el campo 59 que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);
	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;
	    for(i=j;i<j+k;i++) iso->field_59[i-j]=msg[i];
	    iso->field_59[k]='\0';
	}
	else
	{
	    k=strlen(iso->field_59);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
    	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->field_59[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso FIELD 59 DATA:",iso->field_59,inout);
    }




    if(rw_bitmap(60,iso->bitmap_1,0))//pregunta si esta presente el campo 60 que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);
	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;
	    for(i=j;i<j+k;i++) iso->field_60[i-j]=msg[i];
	    iso->field_60[k]='\0';
	}
	else
	{
	    k=strlen(iso->field_60);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
    	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->field_60[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso FIELD 60 DATA:",iso->field_60,inout);
    }
    if(rw_bitmap(61,iso->bitmap_1,0))//pregunta si esta presente el campo 61 que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);
	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;
	    for(i=j;i<j+k;i++) iso->field_61[i-j]=msg[i];
	    iso->field_61[k]='\0';
	}
	else
	{
	    k=strlen(iso->field_61);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->field_61[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso FIELD 61 DATA:",iso->field_61,inout);
    }
    if(rw_bitmap(62,iso->bitmap_1,0))//pregunta si esta presente el campo 62 que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);
	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;
	    for(i=j;i<j+k;i++) iso->field_62[i-j]=msg[i];
	    iso->field_62[k]='\0';
	}
	else
	{
	    k=strlen(iso->field_62);
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
    	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->field_62[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso FIELD 62 DATA:",iso->field_62,inout);
    }

    if(rw_bitmap(63,iso->bitmap_1,0))//pregunta si esta presente el campo 63 que es ascii precedido de dos bytes con la longitud neta en bcd
    {
	if(packunpack)
	{
	    k=longitude_to_int('b',msg[j],msg[j+1]);

	    printf("packunpack - LOG longitud: %d\n", k);

	    if(k>99) k=99;//longitud maxima por corrimientos de parseo
	    j=j+2;

	    printf("packunpack - LOG HEX: ");

	    //for(i=(j+2);i<j+k;i++)
	    for(i=j;i<j+k;i++)
	    {
	    	iso->field_63[i-j]=msg[i];
	    	printf("%x ", iso->field_63[i-j]);
	    }

	    iso->length_63=k; //guarda la longitud del campo por si contiene elementos en bcd,no ascii(modificado para tdf)
	    iso->field_63[k]='\0';
	}
	else
	{
	    k=strlen(iso->field_63);
	    if(iso->length_63>0) k=iso->length_63;//utiliza la longitud informada en length_63 si el campo contiene elementos en bcd, no ascii(modificado para tdf)
	    int_to_longitude('b',k,&a,&b);
	    msg[j]=a;
	    msg[j+1]=b;
	    j=j+2;
	    for(i=j;i<j+k;i++) msg[i]=iso->field_63[i-j];
	}
	j=i;
	if(debug) tlog("Debug: iso FIELD 63 DATA:",iso->field_63,inout);
    }
    /* finalizo el proceso de composicion/descomposicion de campos */
    if(packunpack)
    {
	if(longitude_to_int('h',msg[0],msg[1])!=j-2)//chequea si hubo algún campo desconocido dentro del mensaje,comparando la longitud total sin contar los dos bytes de longitud de trama
	{
	    tlog("Error: existen campos no soportados en la respuesta del host.","","");
	    return -1;
	}
	return 0;
    }
    else
    {
	int_to_longitude('h',j-2,&msg[0],&msg[1]);//guarda la longitud total de la trama en hexa sin incluir los dos bytes de longitud.
	return j;//devuelve la longitud de la trama como entero incluidos los dos bytes de longitud
    }
}

/*
Nombre: bcd_to asc
Descripción: Convierte una cadena bcd en una cadena ascii. Si la cadena en bdc tiene longitud impar elimina el relleno 0xf.
Parametros: Se le pasa la longitud de nibbles, el puntero de la cadena a convertir, y el puntero a la cadena convertida.
Devolución: No retorna valores.
*/
void bcd_to_asc(int l,char *bcd,char *asc)
{
    int i=0,j=0,k;
    k=(l/2)+(l%2);//convierte la longitud en bytes.
    for(i=0;i<k;i++)
    {
	asc[j]=((bcd[i]&0xf0)/16);//convierte nibble alto en ascii
	if(asc[j]<0x0a) asc[j]=asc[j]+0x30;//numeros
	else asc[j]=asc[j]+0x37;//letras de A a F
	asc[j+1]=(bcd[i]&0x0f);//convierte nibble bajo en ascii
	if(asc[j+1]<0x0a) asc[j+1]=asc[j+1]+0x30;//numeros
	else asc[j+1]=asc[j+1]+0x37;//letras de A a F
	j=j+2;
    }
    asc[l]='\0';//finaliza la cadena ascii segun la longirud de la bcd
}

/*
Nombre: asc_to_bcd
Descripción: Convierte una cadena de ascii en una cadena bdc. Si la longitud es impar rellena el nibble restante con 0xf.
Parametros: Se le pasa el puntero a la cadena a convertir y el puntero a la cadena cnvertida.
Devolción: Retorna la longitud de bytes de la cadena resulante.
*/
int asc_to_bcd(char *asc,char *bcd)
{
    int i=0,j=0,l,k;
    l=strlen(asc);
    k=(l/2)+(l%2);//convierte la longitud en bytes.
    for(i=0;i<k;i++)
    {
	//convierte nibble alto en ascii
	//if(asc[j+1]<0x3a) bcd[i]=16*(asc[j]-0x30);//numeros   // patch TPDU Eze.
    if(asc[j]<0x3a) bcd[i]=16*(asc[j]-0x30);//numeros
	else bcd[i]=16*(asc[j]-0x37);//letras de A a F
	if(j+1<l)//convierte nibble bajo en ascii menos el ultimo si l es impar
	{
	    if(asc[j+1]<0x3a) bcd[i]=bcd[i]|(asc[j+1]-0x30);//numeros
	    else bcd[i]=bcd[i]|(asc[j+1]-0x37);//letras de A a F
	}
	j=j+2;
    }
    if(l%2>0) bcd[i-1]=bcd[i-1]|0x0f;//pregunta si la longitud es impar para poner el relleno.
    return k;
}


/*
Nombre: rw_bitmap
Descripción: Lee o escribe el bit indicado dentro de la cadena que contiene el mapa de bits.
Parametros: Se le pasa  el numero de bit (del 1 al 64) al cual se quiere manipular, el puntero a la cadena que contiene los 8 bytes del bitmap, y un
entero igual a 0 para lectura e igual a 1 para escritura.
Devolución: Devuelve un int con el valor del bit en cuestion.
*/
int rw_bitmap(int bit, char *bitmap,int rw)
{
    int nbit,nbyte,mask=0x80;
    bit--;//numero de bit de 0 a 63
    nbyte=bit/8;//obtengo el numero de byte dentro del bitmap al cual hay que enmascarar, bits1-8 byte 0
    nbit=bit-(nbyte*8);//obtengo el numero de bit dentro del byte a enmascarar, el mas significativo es el bit 0
    mask=mask>>nbit;//desplazo a derecha el uno nbit veces para obtener las mascara
    if(rw) bitmap[nbyte]=bitmap[nbyte]|mask;//enciedo el bit enmascarado si es escritura
    return bitmap[nbyte]&mask;//retorno el valor del bit tanto para lectura como escritura
}


/*
Nombre:
get_time
Descripción: Adquiere la fecha y hora del sistema en formato MM/DD HH/MM/SS y la almacena en las cadenas.
Parametros: Se le pasan los punteros a las cadenas donde se guardan las respuestas.
Devolcución: Sin valor.
*/
void get_time(char *datetrx,char *timetrx)
{
    struct tm z;
    time_t now;
    time (&now);
    z=*localtime(&now);
    sprintf(datetrx,"%02d%02d",z.tm_mon+1,z.tm_mday);
    sprintf(timetrx,"%02d%02d%02d",z.tm_hour,z.tm_min,z.tm_sec);
}

/*
Nombre: longitude_to_int
Descripción: Traduce la longitud en formato LLLL hexadecimal o bcd a entero.
Parametros: Se le pasa un caracter con el tipo 'b' o 'h', y los bytes parte alta y parte baja respectivamente .
Devolución: Devuelve un entero con la longitud traducida.
*/
int longitude_to_int(char type, char a, char b)
{
    int l;
    if(type=='h')
    {
	l=(unsigned char)b+256*(unsigned char)a;//se castean como unsigned sino se interpretan como negativos cuando el bit 7 esta encendido
	return l;
    }
    l=100*((10*(((unsigned char)a&0xf0)/16))+((unsigned char)a&0x0f));
    l=l+((10*(((unsigned char)b&0xf0)/16))+((unsigned char)b&0x0f));
    return l;
}

/*
Nombre: int_to_longitude
Descripción: Traduce la longitud de entero a el formato LLLL hexadecimal o bcd.
Parametros: Se le pasa un caracter con el tipo 'b' o 'h', la longitud en un entero, y punteros a los bytes parte alta y parte baja respectivamente.
Devolución: No retorna valores.
*/
void int_to_longitude (char type, int l, char *a, char *b)
{
    int x=1000,y=100,z=10;
    if(type=='h')
    {
	x=4096;
	y=256;
	z=16;
    }
    *a=16*(l/x)|(l%x)/y;
    *b=16*(((l%x)%y)/z)|(((l%x)%y)%z);
}

/*
Nombre: check_vd
Descripción: Comprueba si el numero de cuenta/comercio tiene en la ultima posicion el digito verificador calculado segun el algoritmo MOD10 o el propio de TDF.
Parametros: Se le pasa el puntero la cadena que contiene el numero a analizar, un entero con el desplazamiento desde el cual se empieza a calcular y
un entero el algoritmo a utilizar: 0-Ninguno retorna 1, 1-MOD10, 2-TDF, cualquier otro retorna 0.
Devolución: Retorna 1 si es correcto o 0 si no lo es.
*/
int genVd (char *str,int offset,int alg)
{
    int a=0,i,j,cte[]={9,7,5,3}; //arrai con la contante para el calculo del algoritmo TDF

    //i=strlen(str)-2;//apunta al anteultimo elemento del str (evita el dv)
    i=strlen(str)-1;

    switch (alg)
    {
    case 0:
        return 1;

    case 1:
	while(1)//calcula el producto acumulativo de deracha a izquierda hasta el digito anterior al bin (offset)
	{
	    a=a+2*(str[i]-0x30)/10+2*(str[i]-0x30)-(10*(2*(str[i]-0x30)/10));//acumula la suma de las decenas y unidades del producto x 2 de los digitos pares
	    if(i==offset) break;
	    i--;
	    a=a+(str[i]-0x30);//acumula la suma de los digitos impares
	    if(i==offset) break;
	    i--;
	}
	a=9*a;//multiplica x9
	a=a-10*(a/10);//saca unidades
	//i=strlen(str)-1;//apunta al dv
	break;

    case 2:
	j=(sizeof(cte)/4)-1;//apunta al ultimo elemento de la constante
	while(i>=offset)//calcula el producto acumulativo de deracha a izquierda hasta el digito anterior al bin (offset)
	{
	    a=a+cte[j]*(str[i]-0x30);//multiplica digito a digito la constante con el numero de cuenta/comercio como entero y acumula
	    if(j==0) j=(sizeof(cte)/4);//si recorrio todos lo elementos de la cte vuelve al ultimo
	    i--;
	    j--;

	}
	  a=a%11;//calcula el resto de la division por 11
 	  if(a>0)a=11-a;//calcula la diferencia al 11 del resto
	  if(a==10) a=0;//si la diferencia es igual a 10 el dv es 0
	//i=strlen(str)-1;//apunta al dv
	break;

    default:
	return 0;
    }

    //if((str[i]-0x30)==a) return 1;
    return a;
}
