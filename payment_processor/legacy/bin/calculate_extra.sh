#!/bin/bash

#echo $1

CANT_SALDO=$(cat $1 | grep -v '^\[0[1-8]' | grep 'MESSAGE TYPE: 0100' | wc -l)
CANT_REVE=$(cat $1 | grep -v '^\[0[1-8]' | grep 'MESSAGE TYPE: 0400' | wc -l)
CANT_DENE=$(cat $1 | grep -v '^\[0[1-8]' | grep 'RESPONSE CODE: '| grep -v 'RESPONSE CODE: 00' | wc -l)

echo "Cantidad CON.SALDO = "$CANT_SALDO
echo "Cantidad REVERSO = "$CANT_REVE
echo "Cantidad DENEGADA = "$CANT_DENE
echo ""
echo "Editar archivo de fechas y ejecutar: "
echo "./trx_con_saldo.php $CANT_SALDO >/dev/null; ./trx_denegada.php $CANT_DENE >/dev/null; ./trx_reverso.php $CANT_REVE >/dev/null"

