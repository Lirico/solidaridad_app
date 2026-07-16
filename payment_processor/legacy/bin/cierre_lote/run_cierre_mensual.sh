#!/bin/bash

cd /home/solidaria_card/V3/bin/cierre_lote

TO_DAY=$(date +%Y%m%d_%H%M%S)

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/solidaria_card/V3/bin/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/mysql57/lib


mv screenlog.0 screenlog.0-$TO_DAY

screen -dmS AUTHKIG_CIERRE_MENSUAL -L ./cierre_mensual_v2 ../authkig.conf

