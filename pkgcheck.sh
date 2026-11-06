#!/bin/sh
# pkgcheck.sh - fetch the package lists from Valve's source mirror (the
# development branches jupiter-main, holo-main and the branches of the
# SteamOS releases in RELEASES, jupiter-<release>, holo-<release>), keep the
# newest version of each package in docs/, and report what changed since the
# last run. The release branches matter on their own: a package can reach
# them before main (xdg-desktop-portal-kde 6.7.3-1.2 did). RELEASES holds the
# stable release (point releases still come) and the next one once Valve
# branches it; drop the old one when SteamOS has moved on.
set -eu

BASE=https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources
DOCS="${DOCS:-$HOME/io-packages/docs}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DOCS"

RELEASES=${RELEASES:-"3.9 3.10"}

branches="jupiter-main holo-main"
for release in $RELEASES; do
    branches="$branches jupiter-$release holo-$release"
done

for branch in $branches; do
    curl -sf "$BASE/$branch/" > "$TMP/$branch.html" || {
        echo "pkgcheck: $branch unreachable" >&2
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
            echo "== $branch: no changes"
        else
            echo "== $branch: changes"
            diff "$old" "$new" | grep '^[<>]'
        fi
    else
        echo "== $branch: first run, $(wc -l < "$new") packages"
    fi

    cp "$new" "$old"
done