#!/bin/bash -eu
# Desktop build. Extra args pass through, e.g.:
#   ./build_desktop.sh -o:speed
#   ./build_desktop.sh -define:AUTOSTART=true
# Windows Odin insists the output end in .exe; elsewhere it must not.
out=crypt
[[ "${OS:-}" == "Windows_NT" ]] && out=crypt.exe
odin build src/main_desktop -out:"$out" -vet "$@"
echo "Built ./$out"
