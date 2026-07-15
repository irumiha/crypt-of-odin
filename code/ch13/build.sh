#!/bin/sh
cd "$(dirname "$0")"
odin build src -out:crypt "$@"
