#!/bin/bash

cd /home/solidaria_card/V3/reportes

TO_DAY=$(date +%Y%m%d_%H%M%S)

mv screenlog.0 screenlog.0-$TO_DAY

screen -dmS SOLIDARIA_REPO -L ./solidaria_repos.sh 1

sleep 1

cd /home/solidaria_card/V3/bin

screen -dmS SOLI_VACCINE -L ./patch_death.sh 1

sleep

screen -ls
