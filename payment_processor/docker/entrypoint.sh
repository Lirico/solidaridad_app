#!/bin/sh
set -eu
cd /app
export LD_LIBRARY_PATH="/app${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec ./authkig-bin3 authkig.conf
