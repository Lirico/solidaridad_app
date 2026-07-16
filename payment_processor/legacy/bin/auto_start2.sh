#!/bin/bash

DAYKILL=28
POSTKILL=29

TKILL=23
TLIVE=10

TNO_START="Y"

cd /home/solidaria_card/V3/bin

while true; do

  ps fax | grep -v tailf | grep authkig-bin | grep -v grep

  if [ $? -ne 0 ]; then
     if [ $TNO_START = "Y" ]; then
        ./run_kig.sh
     else 
        ecoho ">>>> El proceso establoqueado por CIERRE_MENSUAL!"
     fi
  else
    ## Check killer
    daym=$(date +%d)
    dayh=$(date +%H)

    if [ $daym -eq $DAYKILL ]; then
       if [ $dayh -eq $TKILL ]; then
          echo ">>>> ES HORA DE PARAR EL PROCESO! CIERRE_MENSUAL!"
          echo ">>>> Establece TNO_START=N"
          TNO_START="N"
       else
          echo ">>>> AUN NO ES HORA!"
       fi
    fi

    if [ $daym -eq $POSTKILL ]; then
       echo "Reestablece: TNO_START = Y "
       TNO_START = "Y"
    fi

  fi

  sleep 30

done
