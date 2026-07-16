#!/bin/bash

cd /home/solidaria_card/V3/reportes/GEN_20180307

../check_repos_sum.php REP-DIA20180306.csv

if [ $? -eq 0 ]; then

echo "DEBE CORRER!!!"
fi
