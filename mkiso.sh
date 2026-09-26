#!/bin/sh
set -eu

IO=https://github.com/Lolzen/io-repo/releases/download/current
VOID=https://repo-default.voidlinux.org/current
MKLIVE=/home/gee/src/void-mklive
OUT=/home/gee/io-alpha.iso

cd "$MKLIVE"

exec ./mklive.sh \
    -r "$IO" \
    -r "$VOID/nonfree" \
    -r "$VOID/multilib" \
    -r "$VOID/multilib/nonfree" \
    -p io-desktop \
    -b base-system \
    -v linux-neptune \
    -C "rd.live.overlay=1 rd.retry=30" \
    -T "Io" \
    -o "$OUT"