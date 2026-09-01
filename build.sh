#!/bin/sh
set -eu
IO_DIR="${IO_DIR:-$HOME/io-packages}"
VP_DIR="${VP_DIR:-$HOME/void-packages}"

if [ $# -eq 0 ]; then
    echo "usage: build.sh <pkgname> [weitere]" >&2
    exit 1
fi

"$IO_DIR/link.sh"
cd "$VP_DIR"
./xbps-src pkg "$@"