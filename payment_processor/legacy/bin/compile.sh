#!/bin/bash

mysql_include="${MYSQL_INCLUDE:-/usr/local/mysql57/include/}"
mysql_lib="${MYSQL_LIB:-/usr/local/mysql57/lib/}"

# PARA DESARROLLO
gcc iso_common.c -c -fPIC -o iso_common.o -I"$mysql_include"
gcc iso_common.o -shared -o libiso_common.so
gcc  auth_mycli.c -c -o auth_mycli.o -I"$mysql_include"
gcc -c -o auth_thread.o auth_thread.c -I"$mysql_include"
gcc -c -o auth_conf.o auth_conf.c -I"$mysql_include"
gcc -c -o sock_cli_iso.o sock_cli_iso.c -I"$mysql_include"

gcc -c -o auth_kig.o auth_kig.c -I"$mysql_include"

gcc -g -o authkig-bin3 auth_kig.o auth_thread.o sock_cli_iso.o auth_conf.o auth_mycli.o -L. -liso_common -L"$mysql_lib" -lmysqlclient -lpthread

# procesa cargas mensuales batch
gcc -c -o procesa_carga.o procesa_carga.c -I"$mysql_include" -I.
gcc -g -o procesa_carga procesa_carga.o auth_conf.o auth_mycli.o -L. -liso_common -L"$mysql_lib" -lmysqlclient

gcc -c -o procesa_notas.o procesa_descarga.c -I"$mysql_include" -I.
gcc -g -o procesa_notas procesa_notas.o auth_conf.o auth_mycli.o -L. -liso_common -L"$mysql_lib" -lmysqlclient

