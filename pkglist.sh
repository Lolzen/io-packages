#!/bin/sh
# Extrahiert die jeweils neueste Version jedes Pakets aus einer Verzeichnisliste
set -eu
IN="${1:?usage: pkglist.sh <html-datei>}"

grep -o '"[a-z0-9][a-z0-9._+-]*\.src\.tar\.gz"' "$IN" \
  | tr -d '"' \
  | sed 's/\.src\.tar\.gz$//' \
  | sort -V \
  | awk -F'-' '{
      name = ""
      for (i = 1; i <= NF - 2; i++) name = name (i > 1 ? "-" : "") $i
      latest[name] = $0
    }
    END { for (n in latest) print latest[n] }' \
  | sort