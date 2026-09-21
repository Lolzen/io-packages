#!/bin/sh
# publish.sh - publish Io's packages to the GitHub release that serves as
# Io's xbps repository.
#
# What it does:
#   1. copies the newest build of each Io package from xbps-src's binpkgs
#   2. keeps exactly one version per package in the publish dir; removes
#      superseded versions and packages that are no longer in io-packages
#   3. indexes and signs (only what is new)
#   4. uploads only files the release does not have yet, then the index
#   5. deletes release assets that are no longer part of the repository
#
# The package list is taken from ~/io-packages/srcpkgs, so a new package is
# published automatically and a removed one disappears from the release.
# Unrelated packages that xbps-src rebuilt (openssl, pipewire, ...) stay out.
#
# Usage:
#   ./publish.sh              collect all Io packages
#   ./publish.sh io-base ...  collect only these (index and release are
#                             still brought fully up to date)
#   ./publish.sh --full       re-index and re-upload everything
#
# gh output goes to a log file instead of the terminal: when gh writes to a
# terminal it queries the background colour, and the late reply shows up as
# stray characters on the command line.

set -eu

BINPKGS="${BINPKGS:-$HOME/void-packages/hostdir/binpkgs}"
PUBDIR="${PUBDIR:-$HOME/io-repo-pub}"
SRCPKGS="${SRCPKGS:-$HOME/io-packages/srcpkgs}"
PRIVKEY="${PRIVKEY:-$HOME/io-packages/privkey.pem}"
SIGNEDBY="${SIGNEDBY:-Io}"
GHREPO="${GHREPO:-Lolzen/io-repo}"
GHTAG="${GHTAG:-current}"
ARCH=x86_64

export NO_COLOR=1 GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1

TMP=$(mktemp -d /tmp/io-publish.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
GHLOG="$TMP/gh.log"

[ -f "$PRIVKEY" ] || { echo "publish: no private key at $PRIVKEY" >&2; exit 1; }
[ -d "$BINPKGS" ] || { echo "publish: no binpkgs at $BINPKGS" >&2; exit 1; }
[ -d "$SRCPKGS" ] || { echo "publish: no srcpkgs at $SRCPKGS" >&2; exit 1; }
mkdir -p "$PUBDIR"

gh_run() {
    if ! gh "$@" > "$GHLOG" 2>&1; then
        echo "publish: gh $1 $2 failed:" >&2
        cat "$GHLOG" >&2
        exit 1
    fi
}

# "io-base-0.3.0_1.x86_64.xbps" -> "io-base"
pkgname_of() {
    b=${1##*/}
    b=${b%.xbps}
    xbps-uhelper getpkgname "${b%.*}" 2> /dev/null || true
}

# newest file of package $2 in directory $1 (x86_64 or noarch)
newest_in() {
    for f in "$1/$2"-[0-9]*.xbps; do
        [ -f "$f" ] || continue
        [ "$(pkgname_of "$f")" = "$2" ] && echo "$f"
    done | sort -V | tail -1
}

FULL=0
if [ "${1:-}" = "--full" ]; then
    FULL=1
    shift
fi

ALL=$(ls "$SRCPKGS")
if [ $# -gt 0 ]; then
    COLLECT="$*"
else
    COLLECT=$ALL
fi

# ------------------------------------------------------------- collect
echo "== collecting"
: > "$TMP/new.txt"
for pkg in $COLLECT; do
    src=$(newest_in "$BINPKGS" "$pkg")
    if [ -z "$src" ]; then
        echo "  $pkg: not built, skipping"
        continue
    fi
    base=${src##*/}
    if [ -f "$PUBDIR/$base" ]; then
        echo "  $base: already present"
    else
        cp "$src" "$PUBDIR/"
        echo "$PUBDIR/$base" >> "$TMP/new.txt"
        echo "  $base: copied"
    fi
done

# ------------------------------------------ one version per package only
echo "== pruning"
: > "$TMP/keep.txt"
for pkg in $ALL; do
    f=$(newest_in "$PUBDIR" "$pkg")
    [ -n "$f" ] && echo "${f##*/}" >> "$TMP/keep.txt"
done
for f in "$PUBDIR"/*.xbps; do
    [ -f "$f" ] || continue
    if ! grep -qxF "${f##*/}" "$TMP/keep.txt"; then
        rm -f "$f" "$f.sig2"
        echo "  ${f##*/}: removed"
    fi
done

# ------------------------------------------------------ index and sign
echo "== indexing"
if [ "$FULL" = 1 ]; then
    xbps-rindex -a "$PUBDIR"/*.xbps
elif [ -s "$TMP/new.txt" ]; then
    xargs xbps-rindex -a < "$TMP/new.txt"
fi
xbps-rindex -c "$PUBDIR"

echo "== signing"
xbps-rindex --sign --signedby "$SIGNEDBY" --privkey "$PRIVKEY" "$PUBDIR" > /dev/null 2>&1 || true
: > "$TMP/unsigned.txt"
for f in "$PUBDIR"/*.xbps; do
    if [ "$FULL" = 1 ] || [ ! -f "$f.sig2" ]; then
        echo "$f" >> "$TMP/unsigned.txt"
    fi
done
if [ -s "$TMP/unsigned.txt" ]; then
    xargs xbps-rindex --sign-pkg --privkey "$PRIVKEY" < "$TMP/unsigned.txt"
fi

# --------------------------------------------------------------- upload
echo "== comparing with release"
gh_run release view "$GHTAG" --repo "$GHREPO" --json assets --jq '.assets[].name'
sort "$GHLOG" > "$TMP/remote.txt"

(cd "$PUBDIR" && ls *.xbps *.xbps.sig2 "$ARCH-repodata") | sort > "$TMP/local.txt"

if [ "$FULL" = 1 ]; then
    grep -vx "$ARCH-repodata" "$TMP/local.txt" > "$TMP/upload.txt" || true
else
    comm -23 "$TMP/local.txt" "$TMP/remote.txt" | grep -vx "$ARCH-repodata" > "$TMP/upload.txt" || true
fi

# packages first, index last: clients never see an index entry whose file
# is not downloadable yet
if [ -s "$TMP/upload.txt" ]; then
    echo "== uploading $(wc -l < "$TMP/upload.txt") file(s)"
    sed 's/^/  /' "$TMP/upload.txt"
    set --
    while read -r f; do
        set -- "$@" "$PUBDIR/$f"
    done < "$TMP/upload.txt"
    gh_run release upload "$GHTAG" "$@" --repo "$GHREPO" --clobber
else
    echo "== no new packages to upload"
fi

echo "== uploading index"
gh_run release upload "$GHTAG" "$PUBDIR/$ARCH-repodata" --repo "$GHREPO" --clobber

# ---------------------------------------------------------------- clean
comm -23 "$TMP/remote.txt" "$TMP/local.txt" > "$TMP/stale.txt"
if [ -s "$TMP/stale.txt" ]; then
    echo "== removing stale release assets"
    while read -r f; do
        gh_run release delete-asset "$GHTAG" "$f" --repo "$GHREPO" --yes
        echo "  $f"
    done < "$TMP/stale.txt"
fi

echo
echo "published to https://github.com/$GHREPO/releases/tag/$GHTAG"