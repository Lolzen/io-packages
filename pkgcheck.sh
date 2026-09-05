#!/bin/sh
# Holt die Paketlisten von Valves Quellmirror und meldet Aenderungen
# gegenueber dem letzten Lauf.
set -eu

BASE=https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources
DOCS="${DOCS:-$HOME/io-packages/docs}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DOCS"

for branch in jupiter-main holo-main; do
    curl -sf "$BASE/$branch/" > "$TMP/$branch.html" || {
        echo "pkgcheck: $branch nicht erreichbar" >&2
        continue
    }

    grep -o '"[a-z0-9][a-z0-9._+%-]*\.src\.tar\.gz"' "$TMP/$branch.html" \
      | tr -d '"' \
      | sed 's/\.src\.tar\.gz$//' \
      | sort -V \
      | awk -F'-' '{
          name = ""
          for (i = 1; i <= NF - 2; i++) name = name (i > 1 ? "-" : "") $i
          latest[name] = $0
        }
        END { for (n in latest) print latest[n] }' \
      | sort > "$TMP/$branch-latest.txt"

    old="$DOCS/$branch-latest.txt"
    new="$TMP/$branch-latest.txt"

    if [ -f "$old" ]; then
        if diff -q "$old" "$new" > /dev/null; then
            echo "== $branch: keine Aenderungen"
        else
            echo "== $branch: Aenderungen"
            diff "$old" "$new" | grep '^[<>]'
        fi
    else
        echo "== $branch: erste Aufnahme, $(wc -l < "$new") Pakete"
    fi

    cp "$new" "$old"
done