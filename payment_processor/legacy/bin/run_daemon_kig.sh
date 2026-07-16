#!/bin/bash

TO_DAY=$(date +%Y%m%d_%H%M%S)

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/solidaria_card/V3/bin/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/mysql57/lib/

screen -dmS AUTHKIG_DAEMON -L ./auto_start.sh

sleep 1

screen -ls


