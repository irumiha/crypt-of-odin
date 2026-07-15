#!/bin/bash -eu
# Desktop build. Extra args pass through, e.g.:
#   ./build_desktop.sh -o:speed
#   ./build_desktop.sh -define:AUTOSTART=true
odin build src/main_desktop -out:crypt -vet "$@"
echo "Built ./crypt"
