#!/bin/bash

cd /home/solidaria_card/V3/reportes

P_HOUR=$1

while true; do
     S_HOUR=$(date +%H)

     if [ $P_HOUR -eq $S_HOUR ]; then
        break
     fi

     sleep 60
done

echo "Iniciando proceso:"$(date)

F_FECHA=$(date +%Y%m%d)

mkdir "GEN_"$F_FECHA

cd "GEN_"$F_FECHA

echo "INIT Generador GOB..."
/usr/bin/php ../reportes_generador_gob.php
echo "END Generador GOB..."

sleep 320

echo "INIT Generador PROV..."
/usr/bin/php ../reportes_generador_prov.php
echo "END Generador PROV..."

sleep 1000

# Reporte a Gobernacion
/usr/bin/php ../reportes_gob.php


# Reportes a los proveedores
F_AYER=$(date -d "-1 days" +"%Y%m%d")

## GAS AUSTRAL SECTION
/usr/bin/php ../reportes_proveedores.php 30630106628 GASAUSTRAL
mv "GASAUSTRAL-"$(date +%Y%m)".csv" "GASAUSTRAL-"$F_AYER".csv"

REMOTE_GA="/var/www/htdocs/solidaridad/DOWNREPO/30630106628"

#tdfscp64 PUT 192.168.1.99 computos RQcWClZKWg== $PWD"/GASAUSTRAL-"$F_AYER".csv" $REMOTE_GA


## SARTINI SECTION
/usr/bin/php ../reportes_proveedores.php 30597489974 SARTINI
mv "SARTINI-"$(date +%Y%m)".csv" "SARTINI-"$F_AYER".csv"

REMOTE_SA="/var/www/htdocs/solidaridad/DOWNREPO/30597489974"

#tdfscp64 PUT 192.168.1.99 computos RQcWClZKWg== $PWD"/SARTINI-"$F_AYER".csv" $REMOTE_SA


## Envia mails gobierno.

/usr/bin/php ../mailer_gob.php "REP-DIA"$F_AYER".csv"

## Sartini Gas
 
echo "INIT Mailer SARTINI GAS..."

## No se envia mas a PROV por orden de GOBIERNO
#/usr/bin/php ../mailer_sartini.php "SARTINI-"$(date +%Y%m)".csv"

/usr/bin/php ../mailer_prov.php "SARTINI-"$F_AYER".csv" "SARTINI GAS"

echo "END Mailer SARTINI GAST."

## Gas Austral
 
echo "INIT Mailer GAS AUSTRAL..."

## No se envia mas a PROV por orden de GOBIERNO
#/usr/bin/php ../mailer_gasaustral.php "GASAUSTRAL-"$(date +%Y%m)".csv"

/usr/bin/php ../mailer_prov.php "GASAUSTRAL-"$F_AYER".csv" "GAS AUSTRAL"

echo "END Mailer GAS AUSTRAL..."
