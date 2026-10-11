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
# The package list is taken from ~/io-packages/srcpkgs and the overlays
# (overlay/), so a new package is published automatically and a removed one
# disappears from the release.
# Unrelated packages that xbps-src rebuilt (openssl, pipewire, ...) stay out.
#
# Usage:
#   ./publish.sh              collect all Io packages
#   ./publish.sh io-base ...  collect only these (index and release are
#                             still brought fully up to date)
#   ./publish.sh --full       re-index and re-upload everything
#   ./publish.sh --replace io-base ...
#                             publish the latest *built* file of these
#                             packages even if a higher or the same version
#                             is already published (test builds): every other
#                             version of them is removed from the publish dir
#                             and from binpkgs, the index entry is replaced
#                             and the file is uploaded again. xbps-install
#                             -u neither downgrades nor reinstalls the same
#                             version; on the Deck: xbps-install -S, then
#                             xbps-remove -O (drops a cached file of the same
#                             name, which -f would install again), then
#                             xbps-install -f <pkg> (also downgrades)
#   ./publish.sh --testing io-base ...
#                             publish to the testing channel instead (release
#                             "testing", publish dir ~/io-repo-test, created
#                             on first use). Only the named packages go
#                             there; packages that the main repository has
#                             in the same or a higher version are dropped
#                             from it on every --testing run. A Deck uses it
#                             with /etc/xbps.d/10-io-testing.conf containing
#                             repository=https://github.com/Lolzen/io-repo/releases/download/testing
#                             (sorted before Io's 20-io.conf, so a test build
#                             wins over the same version in the main repo)
#   Options can be combined: --testing --replace io-base
#
# gh output goes to a log file instead of the terminal: when gh writes to a
# terminal it queries the background colour, and the late reply shows up as
# stray characters on the command line.

set -eu

BINPKGS="${BINPKGS:-$HOME/void-packages/hostdir/binpkgs}"
MAIN_PUBDIR="${PUBDIR:-$HOME/io-repo-pub}"
SRCPKGS="${SRCPKGS:-$HOME/io-packages/srcpkgs}"
PRIVKEY="${PRIVKEY:-$HOME/io-packages/privkey.pem}"
SIGNEDBY="${SIGNEDBY:-Io}"
GHREPO="${GHREPO:-Lolzen/io-repo}"
GHTAG="${GHTAG:-current}"
ARCH=x86_64

FULL=0
REPLACE=0
TESTING=0
while [ $# -gt 0 ]; do
    case "$1" in
        --full) FULL=1 ;;
        --replace) REPLACE=1 ;;
        --testing) TESTING=1 ;;
        -*) echo "publish: unknown option $1" >&2; exit 1 ;;
        *) break ;;
    esac
    shift
done
if [ "$TESTING" = 1 ]; then
    PUBDIR="${TEST_PUBDIR:-$HOME/io-repo-test}"
    GHTAG="${TEST_GHTAG:-testing}"
else
    PUBDIR=$MAIN_PUBDIR
fi
if [ "$REPLACE" = 1 ] && [ $# -eq 0 ]; then
    echo "publish: --replace needs package names" >&2
    exit 1
fi

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

# Packages built for i686 only (archs="i686") are published as their
# -32bit package from the multilib directory, never as the i686 package.
is_lib32() { grep -q '^archs="i686"' "$SRCPKGS/$1/template" 2> /dev/null; }
pubname() { if is_lib32 "$1"; then echo "$1-32bit"; else echo "$1"; fi; }
bindir() { if is_lib32 "$1"; then echo "$BINPKGS/multilib"; else echo "$BINPKGS"; fi; }

# newest file of package $2 in directory $1 (x86_64 or noarch)
newest_in() {
    for f in "$1/$2"-[0-9]*.xbps; do
        [ -f "$f" ] || continue
        [ "$(pkgname_of "$f")" = "$2" ] && echo "$f"
    done | sort -V | tail -1
}

# most recently built file of package $2 in directory $1 (for --replace)
latest_built_in() {
    best=""
    for f in "$1/$2"-[0-9]*.xbps; do
        [ -f "$f" ] || continue
        [ "$(pkgname_of "$f")" = "$2" ] || continue
        if [ -z "$best" ] || [ "$f" -nt "$best" ]; then
            best=$f
        fi
    done
    echo "$best"
}

# remove every file of package $2 in directory $1 except $3 (a file name)
drop_others() {
    for f in "$1/$2"-[0-9]*.xbps; do
        [ -f "$f" ] || continue
        [ "$(pkgname_of "$f")" = "$2" ] || continue
        [ "${f##*/}" = "$3" ] && continue
        rm -f "$f" "$f.sig2"
        echo "  $f: removed (replaced)"
    done
}

# "io-base-0.3.0_1.x86_64.xbps" -> "io-base-0.3.0_1"
pkgver_of() {
    b=${1##*/}
    b=${b%.xbps}
    echo "${b%.*}"
}

# Overlay packages (overlay/holo.sh: MangoHud-holo, MangoHud-mangoapp-holo,
# ...) belong to Io as well. Their names come from Void's templates, so a
# failure here stops the run: a short list would prune them from the release.
HOLO="${SRCPKGS%/srcpkgs}/overlay/holo.sh"
HOLONAMES=""
if [ -f "$HOLO" ]; then
    HOLONAMES=$(IO_DIR="${SRCPKGS%/srcpkgs}" sh "$HOLO" names) || {
        echo "publish: overlay/holo.sh names failed - not publishing" >&2
        exit 1
    }
fi
ALL="$(ls "$SRCPKGS") $HOLONAMES"
if [ $# -gt 0 ]; then
    COLLECT="$*"
elif [ "$TESTING" = 1 ]; then
    COLLECT=""    # the testing channel only gets what is named
else
    COLLECT=$ALL
fi

# ------------------------------------------------------------- collect
echo "== collecting"
: > "$TMP/new.txt"
: > "$TMP/forced.txt"
CLEANBIN=""
for pkg in $COLLECT; do
    name=$(pubname "$pkg")
    dir=$(bindir "$pkg")
    if [ "$REPLACE" = 1 ]; then
        src=$(latest_built_in "$dir" "$name")
    else
        src=$(newest_in "$dir" "$name")
    fi
    if [ -z "$src" ]; then
        echo "  $pkg: not built, skipping"
        continue
    fi
    base=${src##*/}
    if [ "$REPLACE" = 1 ]; then
        # Other builds of it go from binpkgs too, or a later run without
        # --replace would pick a higher test build again.
        drop_others "$PUBDIR" "$name" "$base"
        drop_others "$dir" "$name" "$base"
        case " $CLEANBIN " in *" $dir "*) ;; *) CLEANBIN="$CLEANBIN $dir" ;; esac
        cp -f "$src" "$PUBDIR/"
        rm -f "$PUBDIR/$base.sig2"
        echo "$PUBDIR/$base" >> "$TMP/new.txt"
        echo "$base" >> "$TMP/forced.txt"
        echo "$base.sig2" >> "$TMP/forced.txt"
        echo "  $base: copied (replace)"
    elif [ -f "$PUBDIR/$base" ]; then
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
    f=$(newest_in "$PUBDIR" "$(pubname "$pkg")")
    [ -n "$f" ] && echo "${f##*/}" >> "$TMP/keep.txt"
done
for f in "$PUBDIR"/*.xbps; do
    [ -f "$f" ] || continue
    if ! grep -qxF "${f##*/}" "$TMP/keep.txt"; then
        rm -f "$f" "$f.sig2"
        echo "  ${f##*/}: removed"
    fi
done
# The testing channel drops what the main repository has caught up with
# (merged and published there), except what is named in this run.
if [ "$TESTING" = 1 ]; then
    for f in "$PUBDIR"/*.xbps; do
        [ -f "$f" ] || continue
        name=$(pkgname_of "$f")
        named=0
        for pkg in $COLLECT; do
            [ "$(pubname "$pkg")" = "$name" ] && named=1
        done
        [ "$named" = 1 ] && continue
        m=$(newest_in "$MAIN_PUBDIR" "$name")
        [ -n "$m" ] || continue
        rc=0
        xbps-uhelper cmpver "$(pkgver_of "$m")" "$(pkgver_of "$f")" || rc=$?
        if [ "$rc" != 255 ]; then
            rm -f "$f" "$f.sig2"
            echo "  ${f##*/}: removed (main has $(pkgver_of "$m"))"
        fi
    done
fi
# binpkgs is xbps-src's local repository: drop the index entries of the
# builds --replace removed.
for dir in $CLEANBIN; do
    xbps-rindex -c "$dir" > /dev/null
done

# ------------------------------------------------------ index and sign
echo "== indexing"
if [ "$FULL" = 1 ]; then
    xbps-rindex -a "$PUBDIR"/*.xbps
elif [ -s "$TMP/new.txt" ]; then
    if [ "$REPLACE" = 1 ]; then
        # -f: replace the entry of an already registered (same or higher) version
        xargs xbps-rindex -f -a < "$TMP/new.txt"
    else
        xargs xbps-rindex -a < "$TMP/new.txt"
    fi
fi
xbps-rindex -c "$PUBDIR"
if [ ! -f "$PUBDIR/$ARCH-repodata" ]; then
    echo "publish: nothing in $PUBDIR to publish" >&2
    exit 1
fi

echo "== signing"
# Returns 0 when the repodata already carries this key; anything else is a
# real error (wrong key file, broken repodata) and stops the upload.
# xbps-rindex refuses an index without packages (an emptied testing
# channel); that index keeps the key from before, so clients accept it.
if ls "$PUBDIR"/*.xbps > /dev/null 2>&1; then
    xbps-rindex --sign --signedby "$SIGNEDBY" --privkey "$PRIVKEY" "$PUBDIR" > /dev/null
fi
: > "$TMP/unsigned.txt"
for f in "$PUBDIR"/*.xbps; do
    [ -f "$f" ] || continue
    if [ "$FULL" = 1 ] || [ ! -f "$f.sig2" ]; then
        echo "$f" >> "$TMP/unsigned.txt"
    fi
done
if [ -s "$TMP/unsigned.txt" ]; then
    xargs xbps-rindex --sign-pkg --privkey "$PRIVKEY" < "$TMP/unsigned.txt"
fi

# --------------------------------------------------------------- upload
if [ "$TESTING" = 1 ] && ! gh release view "$GHTAG" --repo "$GHREPO" > "$GHLOG" 2>&1; then
    echo "== creating release $GHTAG"
    gh_run release create "$GHTAG" --repo "$GHREPO" --prerelease --title "Io testing" --notes "Test builds that are not merged yet, for testing on a Deck only."
fi

echo "== comparing with release"
gh_run release view "$GHTAG" --repo "$GHREPO" --json assets --jq '.assets[].name'
sort "$GHLOG" > "$TMP/remote.txt"

(cd "$PUBDIR" && ls *.xbps *.xbps.sig2 "$ARCH-repodata" 2> /dev/null) | sort > "$TMP/local.txt"

if [ "$FULL" = 1 ]; then
    grep -vx "$ARCH-repodata" "$TMP/local.txt" > "$TMP/upload.txt" || true
else
    # new names, plus what --replace changed under an existing name
    { comm -23 "$TMP/local.txt" "$TMP/remote.txt"; cat "$TMP/forced.txt"; } |
        grep -vx "$ARCH-repodata" | sort -u > "$TMP/upload.txt" || true
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
if [ "$TESTING" = 1 ]; then
    echo "Deck: /etc/xbps.d/10-io-testing.conf with"
    echo "  repository=https://github.com/$GHREPO/releases/download/$GHTAG"
fi
