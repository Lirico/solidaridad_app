#!/bin/bash

cd /home/solidaria_card/V3/bin

while true; do

  ps fax | grep -v tailf | grep authkig-bin | grep -v grep

  if [ $? -ne 0 ]; then
     ./run_kig.sh
  fi

  sleep 30

done
